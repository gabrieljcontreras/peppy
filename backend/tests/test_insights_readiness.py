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
