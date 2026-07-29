import asyncio
import json
from datetime import date, datetime, time, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.api.routes import insights as insights_routes
from app.config import Settings
from app.ml.narrator import Narrator
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.protocol import Compound, Protocol
from app.models.user import User
from app.models.weekly_summary import WeeklySummary
from app.services.weekly_summary import completed_week_bounds, get_or_create_weekly_summary
from conftest import grant_premium

TODAY = date(2026, 7, 15)
WEEK_START = date(2026, 7, 6)
WEEK_END = date(2026, 7, 12)


async def _make_user(db_session, email: str = "weekly-summary@example.com") -> User:
    user = User(email=email, hashed_password="x")
    db_session.add(user)
    await db_session.flush()
    return user


def _add_checkins(
    db_session,
    user: User,
    week_start: date,
    rows: list[tuple[int, float | None, int | None, int | None]],
) -> None:
    for day_offset, weight_kg, sleep_quality, energy_level in rows:
        db_session.add(
            Checkin(
                user_id=user.id,
                date=week_start + timedelta(days=day_offset),
                weight_kg=weight_kg,
                sleep_quality=sleep_quality,
                energy_level=energy_level,
            )
        )


async def _seed_two_week_summary_data(db_session) -> User:
    user = await _make_user(db_session)
    prior_week_start = WEEK_START - timedelta(days=7)
    _add_checkins(
        db_session,
        user,
        prior_week_start,
        [
            (0, 82.0, 6, 5),
            (2, 81.0, 6, 5),
            (4, 80.0, 6, 5),
        ],
    )
    _add_checkins(
        db_session,
        user,
        WEEK_START,
        [
            (0, 80.0, 7, 6),
            (2, 79.0, 7, 6),
            (4, 78.0, 7, 6),
            (6, 77.0, 7, 6),
        ],
    )

    protocol = Protocol(
        user_id=user.id,
        name="Weekly protocol",
        start_date=prior_week_start,
        is_active=True,
    )
    db_session.add(protocol)
    await db_session.flush()
    compound = Compound(
        protocol_id=protocol.id,
        name="Retatrutide",
        dose_mg=2.0,
        dose_unit="mg",
        frequency="weekly",
        administration_route="subcutaneous",
    )
    db_session.add(compound)
    await db_session.flush()
    db_session.add(
        DoseLog(
            user_id=user.id,
            protocol_id=protocol.id,
            compound_id=compound.id,
            dose=2.0,
            unit="mg",
            administered_at=datetime.combine(
                WEEK_START + timedelta(days=1),
                time(hour=9),
                tzinfo=timezone.utc,
            ),
            route="subcutaneous",
        )
    )
    await db_session.commit()
    return user


def _summary_narrator(payload: dict):
    block = SimpleNamespace(type="text", text=json.dumps(payload))
    response = SimpleNamespace(content=[block], stop_reason="end_turn")
    client = SimpleNamespace(messages=SimpleNamespace(create=AsyncMock(return_value=response)))
    narrator = Narrator(
        settings=Settings(anthropic_api_key="test-key", debug=True),
        client=client,
    )
    return narrator, client


async def _summary_count(db_session, user_id) -> int:
    return (
        await db_session.scalar(
            select(func.count(WeeklySummary.id)).where(WeeklySummary.user_id == user_id)
        )
        or 0
    )


async def _auth_headers(client, email: str) -> dict[str, str]:
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "password123"},
    )
    assert response.status_code == 201
    headers = {"Authorization": f"Bearer {response.json()['access_token']}"}
    # The weekly summary is premium-gated; these tests exercise the feature itself.
    return await grant_premium(client, headers)


@pytest.mark.parametrize(
    ("today", "expected"),
    [
        (date(2026, 7, 15), (date(2026, 7, 6), date(2026, 7, 12))),
        (date(2026, 7, 13), (date(2026, 7, 6), date(2026, 7, 12))),
    ],
)
def test_completed_week_bounds_returns_most_recent_full_monday_to_sunday_week(
    today,
    expected,
):
    assert completed_week_bounds(today) == expected


@pytest.mark.asyncio
async def test_no_qualifying_completed_week_returns_none(db_session):
    user = await _make_user(db_session)
    _add_checkins(db_session, user, WEEK_START, [(0, None, 7, 7), (2, None, 7, 7)])
    _add_checkins(
        db_session,
        user,
        WEEK_START - timedelta(days=7),
        [(0, None, 6, 6), (2, None, 6, 6)],
    )
    await db_session.commit()

    payload = await get_or_create_weekly_summary(
        db_session,
        user.id,
        narrator=Narrator(settings=Settings(anthropic_api_key="", debug=True)),
        today=TODAY,
    )

    assert payload is None


@pytest.mark.asyncio
async def test_searches_exactly_eight_completed_weeks_for_latest_qualifying_week(db_session):
    user = await _make_user(db_session)
    eighth_week_start = WEEK_START - timedelta(weeks=7)
    _add_checkins(
        db_session,
        user,
        eighth_week_start,
        [(0, None, None, None), (2, None, None, None), (4, None, None, None)],
    )
    await db_session.commit()

    payload = await get_or_create_weekly_summary(
        db_session,
        user.id,
        narrator=Narrator(settings=Settings(anthropic_api_key="", debug=True)),
        today=TODAY,
    )

    assert payload is not None
    assert payload["week_start"] == eighth_week_start.isoformat()
    assert payload["week_end"] == (eighth_week_start + timedelta(days=6)).isoformat()

    ninth_week_user = await _make_user(db_session, email="ninth-week@example.com")
    ninth_week_start = WEEK_START - timedelta(weeks=8)
    _add_checkins(
        db_session,
        ninth_week_user,
        ninth_week_start,
        [(0, None, None, None), (2, None, None, None), (4, None, None, None)],
    )
    await db_session.commit()

    assert (
        await get_or_create_weekly_summary(
            db_session,
            ninth_week_user.id,
            narrator=Narrator(settings=Settings(anthropic_api_key="", debug=True)),
            today=TODAY,
        )
        is None
    )


@pytest.mark.asyncio
async def test_qualifying_week_computes_stats_and_successful_narrative_is_cached(db_session):
    user = await _seed_two_week_summary_data(db_session)
    narrative_payload = {
        "narrative": "Your logged trend moved in a positive direction this week.",
        "what_to_watch": [
            {"title": "Energy after dose day", "detail": "Keep logging how you feel."}
        ],
        "provider_questions": ["Is this weekly pattern expected?"],
    }
    narrator, client = _summary_narrator(narrative_payload)

    first = await get_or_create_weekly_summary(
        db_session,
        user.id,
        narrator=narrator,
        today=TODAY,
    )

    assert first is not None
    assert first["week_start"] == WEEK_START.isoformat()
    assert first["week_end"] == WEEK_END.isoformat()
    assert first["hero"] == {
        "weight_delta_kg": -2.5,
        "weight_from_kg": 81.0,
        "weight_to_kg": 78.5,
    }
    assert first["weight_series"] == [
        {"date": "2026-07-06", "weight_kg": 80.0},
        {"date": "2026-07-08", "weight_kg": 79.0},
        {"date": "2026-07-10", "weight_kg": 78.0},
        {"date": "2026-07-12", "weight_kg": 77.0},
    ]
    assert [metric["key"] for metric in first["what_changed"]] == [
        "sleep_quality",
        "dose_adherence",
        "checkins",
        "energy",
    ]
    metrics = {metric["key"]: metric for metric in first["what_changed"]}
    assert metrics["sleep_quality"] == {
        "key": "sleep_quality",
        "label": "Sleep quality",
        "value": "+1.0 pts",
        "detail": "7.0 vs 6.0 prior week",
        "positive": True,
    }
    assert metrics["dose_adherence"] == {
        "key": "dose_adherence",
        "label": "Dose adherence",
        "value": "100%",
        "detail": "1 of 1 expected doses",
        "positive": True,
    }
    assert metrics["checkins"] == {
        "key": "checkins",
        "label": "Check-ins",
        "value": "4 of 7",
        "detail": None,
        "positive": True,
    }
    assert metrics["energy"] == {
        "key": "energy",
        "label": "Energy",
        "value": "+1.0 pts",
        "detail": "6.0 vs 5.0 prior week",
        "positive": True,
    }
    assert first["narrative"] == narrative_payload["narrative"]
    assert first["what_to_watch"] == narrative_payload["what_to_watch"]
    assert first["provider_questions"] == narrative_payload["provider_questions"]
    assert await _summary_count(db_session, user.id) == 1

    row = (
        await db_session.execute(
            select(WeeklySummary).where(
                WeeklySummary.user_id == user.id,
                WeeklySummary.week_start == WEEK_START,
            )
        )
    ).scalar_one()
    assert row.model_used == "claude-sonnet-5"

    second = await get_or_create_weekly_summary(
        db_session,
        user.id,
        narrator=narrator,
        today=TODAY,
    )

    assert second == first
    client.messages.create.assert_awaited_once()


@pytest.mark.asyncio
async def test_narrator_failure_returns_stats_without_caching_and_retries(db_session):
    user = await _seed_two_week_summary_data(db_session)
    client = SimpleNamespace(
        messages=SimpleNamespace(create=AsyncMock(side_effect=RuntimeError("provider unavailable")))
    )
    narrator = Narrator(
        settings=Settings(anthropic_api_key="test-key", debug=True),
        client=client,
    )

    first = await get_or_create_weekly_summary(
        db_session,
        user.id,
        narrator=narrator,
        today=TODAY,
    )
    second = await get_or_create_weekly_summary(
        db_session,
        user.id,
        narrator=narrator,
        today=TODAY,
    )

    assert first is not None and second is not None
    assert first["narrative"] is None
    assert first["what_to_watch"] == []
    assert first["provider_questions"] == []
    assert second == first
    assert await _summary_count(db_session, user.id) == 0
    assert client.messages.create.await_count == 2


@pytest.mark.asyncio
async def test_disabled_narrator_returns_stats_without_caching(db_session):
    user = await _seed_two_week_summary_data(db_session)

    payload = await get_or_create_weekly_summary(
        db_session,
        user.id,
        narrator=Narrator(settings=Settings(anthropic_api_key="", debug=True)),
        today=TODAY,
    )

    assert payload is not None
    assert payload["narrative"] is None
    assert payload["what_to_watch"] == []
    assert payload["provider_questions"] == []
    assert await _summary_count(db_session, user.id) == 0


@pytest.mark.asyncio
async def test_concurrent_first_requests_share_one_cached_narrative(
    db_session,
    engine,
):
    user = await _seed_two_week_summary_data(db_session)
    narrative_payload = {
        "narrative": "A single cached narrative.",
        "what_to_watch": [],
        "provider_questions": [],
    }
    narrator, client = _summary_narrator(narrative_payload)
    response = client.messages.create.return_value

    async def slow_response(**_kwargs):
        await asyncio.sleep(0.02)
        return response

    client.messages.create.side_effect = slow_response
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async def load_once():
        async with session_factory() as session:
            return await get_or_create_weekly_summary(
                session,
                user.id,
                narrator=narrator,
                today=TODAY,
            )

    first, second = await asyncio.gather(load_once(), load_once())

    assert first == second
    assert first is not None and first["narrative"] == narrative_payload["narrative"]
    client.messages.create.assert_awaited_once()
    async with session_factory() as verification_db:
        assert await _summary_count(verification_db, user.id) == 1


@pytest.mark.asyncio
async def test_weekly_summary_route_returns_snake_case_envelope(
    client,
    engine,
    monkeypatch,
):
    email = "weekly-summary-route@example.com"
    headers = await _auth_headers(client, email)
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    week_start, week_end = completed_week_bounds(date.today())
    async with session_factory() as setup_db:
        user = (await setup_db.execute(select(User).where(User.email == email))).scalar_one()
        _add_checkins(
            setup_db,
            user,
            week_start,
            [(0, 80.0, 7, 7), (2, 79.5, 7, 7), (4, 79.0, 7, 7)],
        )
        await setup_db.commit()

    monkeypatch.setattr(
        insights_routes,
        "Narrator",
        lambda: Narrator(settings=Settings(anthropic_api_key="", debug=True)),
        raising=False,
    )

    response = await client.get("/api/v1/insights/summary/weekly", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["available"] is True
    assert body["summary"]["week_start"] == week_start.isoformat()
    assert body["summary"]["week_end"] == week_end.isoformat()
    assert body["summary"]["hero"] == {
        "weight_delta_kg": None,
        "weight_from_kg": None,
        "weight_to_kg": 79.5,
    }
    assert "what_changed" in body["summary"]
    assert "whatChanged" not in body["summary"]


@pytest.mark.asyncio
async def test_weekly_summary_route_returns_unavailable_envelope(client):
    headers = await _auth_headers(client, "weekly-summary-empty-route@example.com")

    response = await client.get("/api/v1/insights/summary/weekly", headers=headers)

    assert response.status_code == 200
    assert response.json() == {"available": False, "summary": None}
