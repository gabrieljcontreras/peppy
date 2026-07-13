import json
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.api.schemas.insight import InsightResponse
from app.ml.insights_engine import GeneratedInsight
from app.models.insight import InsightSeverity, InsightType
from app.models.user import User
from app.services.insight import InsightService


async def _user(db_session) -> User:
    user = User(email="svc@test.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


async def _insight(db_session, user, **overrides):
    service = InsightService(db_session)
    kwargs = {
        "user_id": user.id,
        "type": InsightType.TREND,
        "severity": InsightSeverity.INFO,
        "title": "t",
        "description": "d",
        "explanation": "e",
        "confidence": 0.6,
    }
    kwargs.update(overrides)
    return await service.create(**kwargs)


@pytest.mark.asyncio
async def test_create_persists_supporting_data(db_session):
    user = await _user(db_session)
    rows = json.dumps(
        [
            {
                "icon_key": "calendar",
                "label": "Dose timing",
                "sublabel": None,
                "value": "100% on time",
            }
        ]
    )

    insight = await _insight(db_session, user, supporting_data=rows)

    assert json.loads(insight.supporting_data)[0]["label"] == "Dose timing"


@pytest.mark.asyncio
async def test_snooze_sets_snoozed_until_and_clears_read(db_session):
    user = await _user(db_session)
    service = InsightService(db_session)
    insight = await _insight(db_session, user)
    await service.mark_read(insight)

    updated = await service.record_action(insight, action="snooze")

    assert updated.read_at is None
    assert updated.snoozed_until is not None
    snoozed_until = updated.snoozed_until.replace(tzinfo=timezone.utc)
    delta = snoozed_until - datetime.now(timezone.utc)
    assert timedelta(days=6, hours=23) < delta < timedelta(days=7, hours=1)


@pytest.mark.asyncio
async def test_list_excludes_actively_snoozed_and_includes_expired(db_session):
    user = await _user(db_session)
    service = InsightService(db_session)
    await _insight(db_session, user, title="active")
    snoozed = await _insight(db_session, user, title="snoozed")
    expired = await _insight(db_session, user, title="expired")
    await service.record_action(snoozed, action="snooze")
    expired.snoozed_until = datetime.now(timezone.utc) - timedelta(days=1)
    await db_session.commit()

    titles = {
        insight.title
        for insight in await service.list_for_user(user_id=user.id)
    }

    assert titles == {"active", "expired"}


@pytest.mark.asyncio
async def test_mark_read_clears_snooze(db_session):
    user = await _user(db_session)
    service = InsightService(db_session)
    insight = await _insight(db_session, user)
    insight.snoozed_until = datetime.now(timezone.utc) + timedelta(days=7)
    await db_session.commit()

    updated = await service.mark_read(insight)

    assert updated.snoozed_until is None
    assert updated.read_at is not None


def test_generated_insight_accepts_supporting_data():
    supporting_data = json.dumps(
        [
            {
                "icon_key": "weight",
                "label": "Weight trend",
                "sublabel": None,
                "value": "0.4 kg / week",
            }
        ]
    )

    insight = GeneratedInsight(
        type=InsightType.TREND,
        severity=InsightSeverity.INFO,
        title="t",
        description="d",
        explanation="e",
        confidence=0.6,
        supporting_data=supporting_data,
    )

    assert insight.supporting_data == supporting_data


def test_insight_response_parses_supporting_data_json():
    now = datetime.now(timezone.utc)
    response = InsightResponse.model_validate(
        {
            "id": uuid4(),
            "type": "trend",
            "severity": "info",
            "title": "t",
            "description": "d",
            "explanation": "e",
            "confidence": 0.6,
            "created_at": now,
            "snoozed_until": now,
            "supporting_data": json.dumps(
                [
                    {
                        "icon_key": "calendar",
                        "label": "Dose timing",
                        "sublabel": None,
                        "value": "100% on time",
                    }
                ]
            ),
        }
    )

    assert response.snoozed_until == now
    assert response.supporting_data is not None
    assert response.supporting_data[0].label == "Dose timing"
