from dataclasses import dataclass
from datetime import date, datetime, time, timezone
from unittest.mock import AsyncMock
from uuid import UUID

import pytest
import pytest_asyncio
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.base import Base
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import Insight, InsightSeverity, InsightType
from app.models.job import Job, JobStatus
from app.models.lab import LabMarker, LabResult
from app.models.notification import (
    DevicePlatform,
    DeviceToken,
    DoseReminderSetting,
    NotificationPreference,
)
from app.models.profile import OnboardingProfile
from app.models.protocol import Compound, Protocol
from app.models.user import User
from app.models.wearable import WearableConnection, WearableData, WearableProvider
from app.models.weekly_summary import WeeklySummary
from app.services.auth import decode_token

USER_OWNED_MODELS = (
    User,
    OnboardingProfile,
    Protocol,
    Compound,
    DoseLog,
    Checkin,
    LabResult,
    LabMarker,
    Insight,
    WeeklySummary,
    WearableConnection,
    WearableData,
    Job,
    NotificationPreference,
    DeviceToken,
    DoseReminderSetting,
)


def test_deletion_inventory_enumerates_every_user_owned_model():
    owned_tables = {User.__tablename__}
    discovered_models = {User}

    while True:
        newly_discovered = {
            mapper.class_
            for mapper in Base.registry.mappers
            if mapper.class_ not in discovered_models
            and any(
                foreign_key.column.table.name in owned_tables
                for column in mapper.local_table.columns
                for foreign_key in column.foreign_keys
            )
        }
        if not newly_discovered:
            break
        discovered_models.update(newly_discovered)
        owned_tables.update(model.__tablename__ for model in newly_discovered)

    assert set(USER_OWNED_MODELS) == discovered_models


@dataclass
class PopulatedAccount:
    headers: dict[str, str]
    user_id: UUID
    session_factory: async_sessionmaker[AsyncSession]
    user_owned_models: tuple[type, ...] = USER_OWNED_MODELS

    async def count(self, model: type) -> int:
        async with self.session_factory() as session:
            return await session.scalar(select(func.count()).select_from(model)) or 0

    async def counts(self) -> dict[str, int]:
        return {model.__tablename__: await self.count(model) for model in self.user_owned_models}


@pytest_asyncio.fixture
async def populated_account(client, db_session, engine):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "delete-account@example.com", "password": "password123"},
    )
    assert registered.status_code == 201
    tokens = registered.json()
    user_id = UUID(decode_token(tokens["access_token"])["sub"])

    profile = OnboardingProfile(user_id=user_id)
    protocol = Protocol(
        user_id=user_id,
        name="Deletion inventory protocol",
        start_date=date(2026, 7, 1),
    )
    lab_result = LabResult(
        user_id=user_id,
        date=date(2026, 7, 10),
        panel_type="metabolic",
    )
    db_session.add_all([profile, protocol, lab_result])
    await db_session.flush()

    compound = Compound(
        protocol_id=protocol.id,
        name="Test Compound",
        dose_mg=1.0,
        dose_unit="mg",
        frequency="weekly",
        administration_route="subcutaneous",
    )
    db_session.add(compound)
    await db_session.flush()

    db_session.add_all(
        [
            DoseLog(
                user_id=user_id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=1.0,
                unit="mg",
                administered_at=datetime(2026, 7, 15, 14, 0, tzinfo=timezone.utc),
                route="subcutaneous",
            ),
            Checkin(user_id=user_id, date=date(2026, 7, 16), energy_level=8),
            LabMarker(
                lab_result_id=lab_result.id,
                name="HbA1c",
                value=5.2,
                unit="%",
            ),
            Insight(
                user_id=user_id,
                type=InsightType.TREND,
                severity=InsightSeverity.INFO,
                title="Test insight",
                description="Inventory coverage",
                explanation="Created for account deletion testing",
                confidence=0.9,
            ),
            WeeklySummary(
                user_id=user_id,
                week_start=date(2026, 7, 13),
                payload="{}",
                model_used="test-model",
            ),
            WearableConnection(
                user_id=user_id,
                provider=WearableProvider.OURA,
                access_token="encrypted-test-token",
            ),
            WearableData(
                user_id=user_id,
                provider=WearableProvider.OURA,
                date=date(2026, 7, 16),
                sleep_hours=8.0,
            ),
            Job(
                user_id=user_id,
                job_type="insight_generation",
                status=JobStatus.COMPLETED,
            ),
            NotificationPreference(
                user_id=user_id,
                insights_enabled=True,
            ),
            DeviceToken(
                user_id=user_id,
                token="delete-account-device-token",
                platform=DevicePlatform.IOS,
            ),
            DoseReminderSetting(
                user_id=user_id,
                compound_id=compound.id,
                local_time=time(9, 0),
            ),
        ]
    )
    await db_session.commit()

    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    return PopulatedAccount(
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
        user_id=user_id,
        session_factory=session_factory,
    )


async def test_delete_account_removes_complete_user_inventory(client, populated_account):
    before = await populated_account.counts()
    assert set(before.values()) == {1}

    response = await client.request(
        "DELETE",
        "/api/v1/auth/account",
        headers=populated_account.headers,
        json={"current_password": "password123"},
    )

    assert response.status_code == 204
    assert response.content == b""
    for model in populated_account.user_owned_models:
        assert await populated_account.count(model) == 0
    assert (
        await client.get(
            "/api/v1/auth/me",
            headers=populated_account.headers,
        )
    ).status_code == 401


async def test_delete_account_wrong_password_preserves_every_record(client, populated_account):
    before = await populated_account.counts()

    response = await client.request(
        "DELETE",
        "/api/v1/auth/account",
        headers=populated_account.headers,
        json={"current_password": "wrong-value"},
    )

    assert response.status_code == 400
    assert await populated_account.counts() == before


async def test_delete_account_rejects_extra_request_fields(client, populated_account):
    before = await populated_account.counts()

    response = await client.request(
        "DELETE",
        "/api/v1/auth/account",
        headers=populated_account.headers,
        json={"current_password": "password123", "keep_exports": True},
    )

    assert response.status_code == 422
    assert await populated_account.counts() == before


async def test_delete_account_rolls_back_complete_inventory_on_commit_failure(
    populated_account,
    monkeypatch,
):
    from app.services.account import AccountService

    before = await populated_account.counts()
    async with populated_account.session_factory() as session:
        user = await session.get(User, populated_account.user_id)
        rollback = AsyncMock(wraps=session.rollback)
        monkeypatch.setattr(session, "commit", AsyncMock(side_effect=RuntimeError("commit failed")))
        monkeypatch.setattr(session, "rollback", rollback)

        with pytest.raises(RuntimeError, match="commit failed"):
            await AccountService(session).delete_account(user, "password123")

        rollback.assert_awaited_once()

    assert await populated_account.counts() == before
