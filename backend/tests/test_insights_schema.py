import json
from datetime import date

import pytest
from sqlalchemy.exc import IntegrityError

from app.models.insight import Insight, InsightSeverity, InsightType
from app.models.user import User
from app.models.weekly_summary import WeeklySummary


async def _make_user(db_session) -> User:
    user = User(email="schema@test.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.mark.asyncio
async def test_insight_new_columns_round_trip(db_session):
    user = await _make_user(db_session)
    insight = Insight(
        user_id=user.id,
        type=InsightType.TREND,
        severity=InsightSeverity.INFO,
        title="t",
        description="d",
        explanation="e",
        confidence=0.5,
        supporting_data=json.dumps(
            [
                {
                    "icon_key": "weight",
                    "label": "Weight trend",
                    "sublabel": "vs prior 2 weeks",
                    "value": "0.4 kg / week",
                }
            ]
        ),
    )
    db_session.add(insight)
    await db_session.commit()
    await db_session.refresh(insight)

    assert insight.snoozed_until is None
    assert json.loads(insight.supporting_data)[0]["icon_key"] == "weight"


@pytest.mark.asyncio
async def test_user_last_insight_run_at_defaults_null(db_session):
    user = await _make_user(db_session)

    assert user.last_insight_run_at is None


@pytest.mark.asyncio
async def test_weekly_summary_unique_per_user_week(db_session):
    user = await _make_user(db_session)
    row = WeeklySummary(
        user_id=user.id,
        week_start=date(2026, 7, 6),
        payload=json.dumps({"narrative": "hi"}),
        model_used="claude-sonnet-5",
    )
    db_session.add(row)
    await db_session.commit()

    dupe = WeeklySummary(
        user_id=user.id,
        week_start=date(2026, 7, 6),
        payload="{}",
    )
    db_session.add(dupe)
    with pytest.raises(IntegrityError):
        await db_session.commit()
