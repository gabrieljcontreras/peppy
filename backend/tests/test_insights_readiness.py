import json
from datetime import date, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config import Settings
from app.ml.insights_engine import GeneratedInsight, InsightsEngine
from app.ml.narrator import Narrator
from app.models.checkin import Checkin
from app.models.insight import Insight, InsightSeverity, InsightType
from app.models.user import User
from app.services.insight import InsightService
from app.services.insight_generation import run_generation


async def _auth_headers(client, email: str) -> dict[str, str]:
    await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "password123"},
    )
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "password123"},
    )
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


@pytest.mark.asyncio
async def test_insights_collection_path_does_not_redirect_authenticated_request(client):
    headers = await _auth_headers(client, "insights-canonical@example.com")

    response = await client.get("/api/v1/insights", headers=headers)

    assert response.status_code == 200
    assert response.history == []


async def _create_user(db: AsyncSession, email: str) -> User:
    user = User(email=email, hashed_password="x")
    db.add(user)
    await db.flush()
    return user


async def _seed_baseline_checkins(db: AsyncSession, user_id, count: int = 3) -> None:
    values = [
        (date(2026, 7, 1), 80.0, 5, 7, 6),
        (date(2026, 7, 2), 80.5, 7, 8, 7),
        (date(2026, 7, 3), 81.0, 6, 9, 8),
    ]
    for checkin_date, weight, energy, mood, sleep in values[:count]:
        db.add(
            Checkin(
                user_id=user_id,
                date=checkin_date,
                weight_kg=weight,
                energy_level=energy,
                mood=mood,
                sleep_quality=sleep,
            )
        )
    await db.commit()


@pytest.mark.asyncio
async def test_engine_returns_baseline_from_latest_three_when_stronger_rules_are_silent(
    db_session,
):
    user = await _create_user(db_session, "baseline-three@example.com")
    await _seed_baseline_checkins(db_session, user.id)
    engine = InsightsEngine(db_session, rules=[])

    results = await engine.analyze_user_data(
        user.id,
        date(2026, 7, 1),
        date(2026, 7, 31),
    )

    assert len(results) == 1
    candidate = results[0]
    assert candidate.type == InsightType.TREND
    assert candidate.severity == InsightSeverity.INFO
    assert candidate.title == "Your recent check-in pattern"
    assert candidate.description == (
        "Your weight moved from 80.0 kg to 81.0 kg. "
        "Energy averaged 6.0/10."
    )
    assert candidate.confidence == 0.6
    assert json.loads(candidate.source_data_refs) == {
        "rule": "checkin_baseline_v1"
    }
    assert json.loads(candidate.supporting_data) == [
        {
            "icon_key": "weight",
            "label": "Weight",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "80.0 → 81.0 kg",
        },
        {
            "icon_key": "chart",
            "label": "Average energy",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "6.0 / 10",
        },
        {
            "icon_key": "chart",
            "label": "Average mood",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "8.0 / 10",
        },
        {
            "icon_key": "sleep",
            "label": "Average sleep quality",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "7.0 / 10",
        },
        {
            "icon_key": "calendar",
            "label": "Check-ins analyzed",
            "sublabel": "2026-07-01 – 2026-07-03",
            "value": "3",
        },
    ]


@pytest.mark.asyncio
async def test_engine_does_not_return_baseline_before_three_checkins(db_session):
    user = await _create_user(db_session, "baseline-two@example.com")
    await _seed_baseline_checkins(db_session, user.id, count=2)
    engine = InsightsEngine(db_session, rules=[])

    results = await engine.analyze_user_data(
        user.id,
        date(2026, 7, 1),
        date(2026, 7, 31),
    )

    assert results == []


@pytest.mark.asyncio
async def test_engine_does_not_invent_baseline_for_date_only_checkins(db_session):
    user = await _create_user(db_session, "baseline-empty@example.com")
    for offset in range(3):
        db_session.add(
            Checkin(
                user_id=user.id,
                date=date(2026, 7, 1) + timedelta(days=offset),
            )
        )
    await db_session.commit()
    engine = InsightsEngine(db_session, rules=[])

    results = await engine.analyze_user_data(
        user.id,
        date(2026, 7, 1),
        date(2026, 7, 31),
    )

    assert results == []


@pytest.mark.asyncio
async def test_engine_prefers_stronger_candidate_over_baseline(db_session):
    user = await _create_user(db_session, "baseline-stronger@example.com")
    await _seed_baseline_checkins(db_session, user.id)
    stronger = GeneratedInsight(
        type=InsightType.ANOMALY,
        severity=InsightSeverity.WARNING,
        title="Stronger finding",
        description="A threshold-backed finding.",
        explanation="Computed by the configured strong rule.",
        confidence=0.8,
        source_data_refs='{"rule":"stronger"}',
    )

    async def strong_rule(db, user_id, start_date, end_date):
        return [stronger]

    engine = InsightsEngine(db_session, rules=[strong_rule])

    results = await engine.analyze_user_data(
        user.id,
        date(2026, 7, 1),
        date(2026, 7, 31),
    )

    assert results == [stronger]


@pytest.mark.asyncio
async def test_generation_persists_deterministic_baseline_only_once(db_session):
    user = await _create_user(db_session, "baseline-persistence@example.com")
    await _seed_baseline_checkins(db_session, user.id)
    narrator = Narrator(settings=Settings(anthropic_api_key="", debug=True))

    first = await run_generation(
        db_session,
        user.id,
        start_date=date(2026, 7, 1),
        end_date=date(2026, 7, 31),
        narrator=narrator,
    )
    second = await run_generation(
        db_session,
        user.id,
        start_date=date(2026, 7, 1),
        end_date=date(2026, 7, 31),
        narrator=narrator,
    )

    assert first == {"insights_generated": 1, "types_breakdown": {"trend": 1}}
    assert second == {"insights_generated": 0, "types_breakdown": {}}
    persisted = await InsightService(db_session).list_for_user(user.id)
    assert len(persisted) == 1
    assert persisted[0].title == "Your recent check-in pattern"
    assert persisted[0].description == (
        "Your weight moved from 80.0 kg to 81.0 kg. "
        "Energy averaged 6.0/10."
    )


@pytest.mark.asyncio
async def test_list_returns_baseline_in_same_response_for_existing_checkins(
    client,
    engine,
):
    email = "baseline-route-recovery@example.com"
    headers = await _auth_headers(client, email)
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as db:
        user = (
            await db.execute(select(User).where(User.email == email))
        ).scalar_one()
        await _seed_baseline_checkins(db, user.id)

    response = await client.get("/api/v1/insights", headers=headers)

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 1
    assert payload[0]["title"] == "Your recent check-in pattern"
    assert payload[0]["description"] == (
        "Your weight moved from 80.0 kg to 81.0 kg. "
        "Energy averaged 6.0/10."
    )
