import asyncio
import json
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock
from uuid import uuid4

import pytest
from fastapi import Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.api.routes import insights as insights_routes
from app.config import Settings
from app.ml.insights_engine import GeneratedInsight, InsightsEngine
from app.ml.narrator import Narrator
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import Insight, InsightSeverity, InsightType
from app.models.protocol import Compound, Protocol
from app.models.user import User
from app.services import insight_generation as generation_service
from app.services.insight import InsightService
from app.services.insight_generation import is_stale, run_generation
from app.services.notification import NotificationService

START = date(2026, 6, 1)
END = date(2026, 6, 30)


async def _seed_symptom_pattern(db):
    user = User(email="generation-runner@example.com", hashed_password="x")
    db.add(user)
    await db.flush()

    protocol = Protocol(
        user_id=user.id,
        name="Test protocol",
        start_date=date(2026, 5, 1),
        is_active=True,
    )
    db.add(protocol)
    await db.flush()
    compound = Compound(
        protocol_id=protocol.id,
        name="Retatrutide",
        dose_mg=4,
        dose_unit="mg",
        frequency="weekly",
        administration_route="subcutaneous",
    )
    db.add(compound)
    await db.flush()

    for dose_date in (
        date(2026, 6, 1),
        date(2026, 6, 8),
        date(2026, 6, 15),
        date(2026, 6, 22),
        date(2026, 6, 29),
    ):
        db.add(
            DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=4,
                unit="mg",
                route="subcutaneous",
                administered_at=datetime.combine(
                    dose_date,
                    datetime.min.time(),
                    tzinfo=timezone.utc,
                ),
            )
        )

    for checkin_date, nausea in (
        (date(2026, 6, 5), 0),
        (date(2026, 6, 9), 4),
        (date(2026, 6, 12), 0),
        (date(2026, 6, 15), 6),
        (date(2026, 6, 19), 0),
        (date(2026, 6, 23), 5),
        (date(2026, 6, 30), 0),
    ):
        db.add(Checkin(user_id=user.id, date=checkin_date, nausea=nausea))

    await db.commit()
    await db.refresh(user)
    return user


def _narrator_with_descriptions(*descriptions):
    payload = {
        "descriptions": [
            {"candidate_index": index, "description": description}
            for index, description in enumerate(descriptions)
        ]
    }
    block = SimpleNamespace(
        type="text",
        text=json.dumps(payload),
        citations=None,
    )
    response = SimpleNamespace(
        id="msg_generation_test",
        type="message",
        role="assistant",
        model="claude-haiku-4-5",
        content=[block],
        stop_reason="end_turn",
        stop_sequence=None,
        usage=SimpleNamespace(input_tokens=10, output_tokens=10),
    )
    client = SimpleNamespace(messages=SimpleNamespace(create=AsyncMock(return_value=response)))
    narrator = Narrator(
        settings=Settings(anthropic_api_key="test-key", debug=True),
        client=client,
    )
    return narrator, client


async def _auth_headers(client, email):
    await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "password123"},
    )
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "password123"},
    )
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


@pytest.mark.parametrize(
    ("last_run", "expected"),
    [
        (None, True),
        (datetime.now(timezone.utc) - timedelta(hours=7), True),
        (datetime.now(timezone.utc) - timedelta(hours=1), False),
    ],
)
def test_is_stale_uses_six_hour_window(last_run, expected):
    user = SimpleNamespace(last_insight_run_at=last_run)

    assert is_stale(user) is expected


@pytest.mark.asyncio
async def test_run_generation_persists_template_then_deduplicates(db_session):
    user = await _seed_symptom_pattern(db_session)
    narrator = Narrator(
        settings=Settings(anthropic_api_key="", debug=True),
    )

    first = await run_generation(
        db_session,
        user.id,
        start_date=START,
        end_date=END,
        narrator=narrator,
    )

    assert first == {"insights_generated": 1, "types_breakdown": {"anomaly": 1}}
    persisted = await InsightService(db_session).list_for_user(user.id)
    assert len(persisted) == 1
    assert persisted[0].description.startswith("You've logged nausea within 24 hours")
    assert persisted[0].supporting_data is not None
    await db_session.refresh(user)
    assert user.last_insight_run_at is not None

    second = await run_generation(
        db_session,
        user.id,
        start_date=START,
        end_date=END,
        narrator=narrator,
    )

    assert second == {"insights_generated": 0, "types_breakdown": {}}
    assert len(await InsightService(db_session).list_for_user(user.id)) == 1


@pytest.mark.asyncio
async def test_run_generation_enriches_only_new_candidates(db_session):
    user = await _seed_symptom_pattern(db_session)
    narrator, client = _narrator_with_descriptions("Polished one")

    first = await run_generation(
        db_session,
        user.id,
        start_date=START,
        end_date=END,
        narrator=narrator,
    )
    second = await run_generation(
        db_session,
        user.id,
        start_date=START,
        end_date=END,
        narrator=narrator,
    )

    assert first["insights_generated"] == 1
    assert second["insights_generated"] == 0
    persisted = await InsightService(db_session).list_for_user(user.id)
    assert persisted[0].description == "Polished one"
    client.messages.create.assert_awaited_once()


@pytest.mark.asyncio
async def test_run_generation_sends_alert_notification_for_persisted_description(
    db_session,
    monkeypatch,
):
    user = User(email="generation-alert@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    candidate = GeneratedInsight(
        type=InsightType.ANOMALY,
        severity=InsightSeverity.ALERT,
        title="Alert title",
        description="Template alert body",
        explanation="Deterministic explanation",
        confidence=0.9,
        source_data_refs='{"rule":"alert-test"}',
    )

    analyze = AsyncMock(return_value=[candidate])
    send_notification = AsyncMock(return_value={"sent": 0, "failed": 0, "skipped_reason": None})
    monkeypatch.setattr(InsightsEngine, "analyze_user_data", analyze)
    monkeypatch.setattr(
        NotificationService,
        "send_insight_notification",
        send_notification,
    )

    result = await run_generation(
        db_session,
        user.id,
        start_date=START,
        end_date=END,
        narrator=Narrator(settings=Settings(anthropic_api_key="", debug=True)),
    )

    assert result["insights_generated"] == 1
    persisted = (await InsightService(db_session).list_for_user(user.id))[0]
    send_notification.assert_awaited_once_with(
        user_id=user.id,
        insight_id=persisted.id,
        title="Alert title",
        body="Template alert body",
        severity=InsightSeverity.ALERT,
    )


@pytest.mark.asyncio
async def test_run_generation_builds_default_narrator_when_not_injected(
    db_session,
    monkeypatch,
):
    user = User(email="generation-default-narrator@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    candidate = GeneratedInsight(
        type=InsightType.TREND,
        severity=InsightSeverity.INFO,
        title="Trend title",
        description="Template trend body",
        explanation="Deterministic explanation",
        confidence=0.8,
        source_data_refs='{"rule":"default-narrator-test"}',
    )
    default_narrator = SimpleNamespace(
        enabled=True,
        enrich_insight_descriptions=AsyncMock(return_value=["Default narrator body"]),
    )
    narrator_factory = Mock(return_value=default_narrator)
    monkeypatch.setattr(
        InsightsEngine,
        "analyze_user_data",
        AsyncMock(return_value=[candidate]),
    )
    monkeypatch.setattr(generation_service, "Narrator", narrator_factory)

    await run_generation(
        db_session,
        user.id,
        start_date=START,
        end_date=END,
    )

    persisted = (await InsightService(db_session).list_for_user(user.id))[0]
    assert persisted.description == "Default narrator body"
    narrator_factory.assert_called_once_with()


@pytest.mark.asyncio
@pytest.mark.parametrize("failure_point", ["constructor", "snapshot"])
async def test_run_generation_falls_back_to_template_when_enrichment_setup_fails(
    db_session,
    monkeypatch,
    failure_point,
):
    user = User(email=f"generation-{failure_point}-failure@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    candidate = GeneratedInsight(
        type=InsightType.TREND,
        severity=InsightSeverity.INFO,
        title="Fallback title",
        description="Template fallback body",
        explanation="Deterministic explanation",
        confidence=0.8,
        source_data_refs=f'{{"rule":"{failure_point}-failure"}}',
    )
    monkeypatch.setattr(
        InsightsEngine,
        "analyze_user_data",
        AsyncMock(return_value=[candidate]),
    )

    narrator = None
    if failure_point == "constructor":
        monkeypatch.setattr(
            generation_service,
            "Narrator",
            Mock(side_effect=RuntimeError("narrator unavailable")),
        )
    else:
        narrator = SimpleNamespace(enabled=True)
        monkeypatch.setattr(
            generation_service,
            "build_longitudinal_snapshot",
            AsyncMock(side_effect=RuntimeError("snapshot unavailable")),
        )

    result = await run_generation(
        db_session,
        user.id,
        start_date=START,
        end_date=END,
        narrator=narrator,
    )

    assert result["insights_generated"] == 1
    persisted = (await InsightService(db_session).list_for_user(user.id))[0]
    assert persisted.description == "Template fallback body"


@pytest.mark.asyncio
async def test_run_generation_rolls_back_all_insights_when_persistence_fails(
    db_session,
    monkeypatch,
):
    user = User(email="generation-atomicity@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    user_id = user.id
    candidates = [
        GeneratedInsight(
            type=InsightType.TREND,
            severity=InsightSeverity.INFO,
            title=f"Candidate {index}",
            description=f"Template {index}",
            explanation="Deterministic explanation",
            confidence=0.8,
            source_data_refs=f'{{"rule":"atomicity-{index}"}}',
        )
        for index in range(2)
    ]
    monkeypatch.setattr(
        InsightsEngine,
        "analyze_user_data",
        AsyncMock(return_value=candidates),
    )
    original_create = InsightService.create
    create_count = 0

    async def fail_on_second_create(service, **kwargs):
        nonlocal create_count
        create_count += 1
        if create_count == 2:
            raise RuntimeError("second insert failed")
        return await original_create(service, **kwargs)

    monkeypatch.setattr(InsightService, "create", fail_on_second_create)

    with pytest.raises(RuntimeError, match="second insert failed"):
        await run_generation(
            db_session,
            user_id,
            start_date=START,
            end_date=END,
            narrator=Narrator(settings=Settings(anthropic_api_key="", debug=True)),
        )

    await db_session.rollback()
    persisted = (
        (await db_session.execute(select(Insight).where(Insight.user_id == user_id)))
        .scalars()
        .all()
    )
    assert persisted == []


@pytest.mark.asyncio
async def test_concurrent_generation_deduplicates_per_user(
    db_session,
    engine,
    monkeypatch,
):
    user = User(email="generation-concurrency@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    candidate = GeneratedInsight(
        type=InsightType.TREND,
        severity=InsightSeverity.INFO,
        title="Concurrent candidate",
        description="Concurrent template",
        explanation="Deterministic explanation",
        confidence=0.8,
        source_data_refs='{"rule":"concurrent-generation"}',
    )

    async def analyze(*_args, **_kwargs):
        await asyncio.sleep(0.01)
        return [candidate]

    monkeypatch.setattr(InsightsEngine, "analyze_user_data", analyze)
    test_session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    narrator = Narrator(settings=Settings(anthropic_api_key="", debug=True))

    async def generate_once():
        async with test_session_factory() as db:
            return await run_generation(
                db,
                user.id,
                start_date=START,
                end_date=END,
                narrator=narrator,
            )

    results = await asyncio.gather(generate_once(), generate_once())

    async with test_session_factory() as verification_db:
        persisted = (
            (await verification_db.execute(select(Insight).where(Insight.user_id == user.id)))
            .scalars()
            .all()
        )
    assert len(persisted) == 1
    assert sorted(result["insights_generated"] for result in results) == [0, 1]


@pytest.mark.asyncio
async def test_notification_failure_does_not_undo_persisted_generation(
    db_session,
    monkeypatch,
):
    user = User(email="generation-notification-failure@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    candidate = GeneratedInsight(
        type=InsightType.ANOMALY,
        severity=InsightSeverity.ALERT,
        title="Alert title",
        description="Template alert body",
        explanation="Deterministic explanation",
        confidence=0.9,
        source_data_refs='{"rule":"notification-failure"}',
    )
    monkeypatch.setattr(
        InsightsEngine,
        "analyze_user_data",
        AsyncMock(return_value=[candidate]),
    )
    monkeypatch.setattr(
        NotificationService,
        "send_insight_notification",
        AsyncMock(side_effect=RuntimeError("push unavailable")),
    )

    result = await run_generation(
        db_session,
        user.id,
        start_date=START,
        end_date=END,
        narrator=Narrator(settings=Settings(anthropic_api_key="", debug=True)),
    )

    assert result["insights_generated"] == 1
    assert len(await InsightService(db_session).list_for_user(user.id)) == 1
    await db_session.refresh(user)
    assert user.last_insight_run_at is not None


@pytest.mark.asyncio
async def test_background_generation_uses_own_session_and_default_window(
    db_session,
    engine,
    monkeypatch,
):
    user = User(email="background-generation@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    test_session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    monkeypatch.setattr(
        generation_service,
        "session_factory",
        test_session_factory,
        raising=False,
    )

    await generation_service.run_generation_in_background(user.id)

    await db_session.refresh(user)
    assert user.last_insight_run_at is not None


@pytest.mark.asyncio
async def test_run_generation_defaults_to_trailing_thirty_days(
    db_session,
    monkeypatch,
):
    user = User(email="generation-default-window@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    analyze = AsyncMock(return_value=[])
    monkeypatch.setattr(InsightsEngine, "analyze_user_data", analyze)

    await run_generation(
        db_session,
        user.id,
        narrator=Narrator(settings=Settings(anthropic_api_key="", debug=True)),
    )

    today = date.today()
    analyze.assert_awaited_once_with(
        user.id,
        today - timedelta(days=30),
        today,
    )


@pytest.mark.asyncio
async def test_background_generation_contains_failures(monkeypatch, caplog):
    def broken_session_factory():
        raise RuntimeError("database unavailable")

    monkeypatch.setattr(
        generation_service,
        "session_factory",
        broken_session_factory,
    )

    await generation_service.run_generation_in_background(uuid4())

    assert "background insight generation failed" in caplog.text


@pytest.mark.asyncio
async def test_post_checkin_runs_background_generation(
    client,
    engine,
    monkeypatch,
):
    email = "checkin-generation-trigger@example.com"
    headers = await _auth_headers(client, email)
    test_session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    monkeypatch.setattr(
        generation_service,
        "session_factory",
        test_session_factory,
    )

    response = await client.post(
        "/api/v1/checkins",
        headers=headers,
        json={
            "date": date.today().isoformat(),
            "energy_level": 7,
            "notes": "Feeling steady",
        },
    )

    assert response.status_code == 201
    async with test_session_factory() as verification_db:
        user = (await verification_db.execute(select(User).where(User.email == email))).scalar_one()
        assert user.last_insight_run_at is not None


@pytest.mark.asyncio
async def test_post_dose_log_runs_background_generation(
    client,
    engine,
    monkeypatch,
):
    email = "dose-generation-trigger@example.com"
    headers = await _auth_headers(client, email)
    protocol_response = await client.post(
        "/api/v1/protocols",
        headers=headers,
        json={
            "name": "Generation trigger protocol",
            "start_date": date.today().isoformat(),
            "compounds": [
                {
                    "name": "Retatrutide",
                    "dose_mg": 2.0,
                    "frequency": "weekly",
                }
            ],
        },
    )
    assert protocol_response.status_code == 201
    protocol = protocol_response.json()
    test_session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    monkeypatch.setattr(
        generation_service,
        "session_factory",
        test_session_factory,
    )

    response = await client.post(
        "/api/v1/dose-logs",
        headers=headers,
        json={
            "protocol_id": protocol["id"],
            "compound_id": protocol["compounds"][0]["id"],
            "dose": 2.0,
            "unit": "mg",
            "administered_at": datetime.now(timezone.utc).isoformat(),
            "route": "subcutaneous",
            "notes": None,
        },
    )

    assert response.status_code == 201
    async with test_session_factory() as verification_db:
        user = (await verification_db.execute(select(User).where(User.email == email))).scalar_one()
        assert user.last_insight_run_at is not None


@pytest.mark.asyncio
async def test_get_insights_runs_background_generation_when_stale(
    client,
    engine,
    monkeypatch,
):
    email = "stale-insights-trigger@example.com"
    headers = await _auth_headers(client, email)
    test_session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    monkeypatch.setattr(
        generation_service,
        "session_factory",
        test_session_factory,
    )

    response = await client.get("/api/v1/insights/", headers=headers)

    assert response.status_code == 200
    async with test_session_factory() as verification_db:
        user = (await verification_db.execute(select(User).where(User.email == email))).scalar_one()
        assert user.last_insight_run_at is not None


@pytest.mark.asyncio
async def test_get_insights_does_not_regenerate_when_fresh(
    client,
    engine,
    monkeypatch,
):
    email = "fresh-insights-no-trigger@example.com"
    headers = await _auth_headers(client, email)
    test_session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with test_session_factory() as setup_db:
        user = (await setup_db.execute(select(User).where(User.email == email))).scalar_one()
        user.last_insight_run_at = datetime.now(timezone.utc)
        await setup_db.commit()
    background_generation = AsyncMock()
    monkeypatch.setattr(
        insights_routes,
        "run_generation_in_background",
        background_generation,
    )

    response = await client.get("/api/v1/insights/", headers=headers)

    assert response.status_code == 200
    background_generation.assert_not_awaited()


@pytest.mark.asyncio
async def test_sync_generate_route_delegates_to_shared_runner(
    db_session,
    monkeypatch,
):
    user = User(email="shared-runner-route@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    shared_runner = AsyncMock(
        return_value={
            "insights_generated": 2,
            "types_breakdown": {"trend": 2},
        }
    )
    monkeypatch.setattr(
        insights_routes,
        "run_generation",
        shared_runner,
        raising=False,
    )

    result = await insights_routes.trigger_insight_generation(
        current_user=user,
        db=db_session,
        response=Response(),
        start_date=START,
        end_date=END,
        run_async=False,
    )

    assert result.insights_generated == 2
    assert result.types_breakdown == {"trend": 2}
    shared_runner.assert_awaited_once_with(
        db_session,
        user.id,
        start_date=START,
        end_date=END,
    )
