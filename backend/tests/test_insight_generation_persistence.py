import json
from contextlib import asynccontextmanager
from datetime import date

import pytest
from fastapi import Response

from app.api.routes import insights as insights_routes
from app.ml.insights_engine import GeneratedInsight
from app.models.insight import InsightSeverity, InsightType
from app.models.user import User
from app.services.insight import InsightService
from app.services.job import JobService
from app.tasks import insights as insights_tasks


async def _user(db_session) -> User:
    user = User(email="generation@test.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


def _candidate(supporting_data: str) -> GeneratedInsight:
    return GeneratedInsight(
        type=InsightType.TREND,
        severity=InsightSeverity.INFO,
        title="Weight trend",
        description="Weight is trending down",
        explanation="Based on recent check-ins",
        confidence=0.8,
        source_data_refs='["checkin-1"]',
        supporting_data=supporting_data,
    )


@pytest.mark.asyncio
async def test_sync_generation_persists_candidate_supporting_data(
    db_session,
    monkeypatch,
):
    user = await _user(db_session)
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

    async def analyze_user_data(self, user_id, start_date, end_date):
        return [_candidate(supporting_data)]

    monkeypatch.setattr(
        insights_routes.InsightsEngine,
        "analyze_user_data",
        analyze_user_data,
    )

    await insights_routes.trigger_insight_generation(
        current_user=user,
        db=db_session,
        response=Response(),
        start_date=date(2026, 7, 1),
        end_date=date(2026, 7, 13),
        run_async=False,
    )

    persisted = await InsightService(db_session).list_for_user(user.id)
    assert persisted[0].supporting_data == supporting_data


@pytest.mark.asyncio
async def test_async_generation_persists_candidate_supporting_data(
    db_session,
    monkeypatch,
):
    user = await _user(db_session)
    job = await JobService(db_session).create(user.id, "insight_generation")
    supporting_data = json.dumps(
        [
            {
                "icon_key": "calendar",
                "label": "Dose timing",
                "sublabel": None,
                "value": "100% on time",
            }
        ]
    )

    async def analyze_user_data(self, user_id, start_date, end_date):
        return [_candidate(supporting_data)]

    @asynccontextmanager
    async def test_session():
        yield db_session

    monkeypatch.setattr(
        insights_tasks.InsightsEngine,
        "analyze_user_data",
        analyze_user_data,
    )
    monkeypatch.setattr(insights_tasks, "async_session_maker", test_session)

    await insights_tasks._run_insight_generation(
        job.id,
        user.id,
        date(2026, 7, 1),
        date(2026, 7, 13),
    )

    persisted = await InsightService(db_session).list_for_user(user.id)
    assert persisted[0].supporting_data == supporting_data
