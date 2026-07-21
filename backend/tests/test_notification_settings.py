from dataclasses import dataclass
from datetime import date, datetime, time, timezone
from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import pytest_asyncio

from app.integrations.push import MockPushAdapter
from app.models.insight import InsightSeverity
from app.models.notification import (
    DevicePlatform,
    DeviceToken,
    NotificationPreference,
)
from app.models.protocol import Compound, Protocol
from app.models.user import User
from app.services.auth import decode_token
from app.services.notification import NotificationService


@dataclass
class AccountWithProtocol:
    headers: dict[str, str]
    user_id: UUID
    compound: Compound
    second_compound: Compound
    inactive_compound: Compound
    foreign_compound: Compound


@pytest_asyncio.fixture
async def account_with_protocol(client, db_session):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "notification-settings@example.com", "password": "password123"},
    )
    assert registered.status_code == 201
    tokens = registered.json()
    user_id = UUID(decode_token(tokens["access_token"])["sub"])

    foreign_user = User(
        email="foreign-notification-settings@example.com",
        hashed_password="unused",
    )
    owned_protocol = Protocol(
        user_id=user_id,
        name="Active reminder protocol",
        start_date=date(2026, 7, 1),
        is_active=True,
    )
    db_session.add_all([foreign_user, owned_protocol])
    await db_session.flush()
    foreign_protocol = Protocol(
        user_id=foreign_user.id,
        name="Foreign active protocol",
        start_date=date(2026, 7, 1),
        is_active=True,
    )
    inactive_protocol = Protocol(
        user_id=user_id,
        name="Inactive reminder protocol",
        start_date=date(2026, 6, 1),
        is_active=False,
    )
    db_session.add_all([foreign_protocol, inactive_protocol])
    await db_session.flush()

    compound = Compound(
        protocol_id=owned_protocol.id,
        name="First Compound",
        dose_mg=1.0,
        frequency="weekly",
    )
    second_compound = Compound(
        protocol_id=owned_protocol.id,
        name="Second Compound",
        dose_mg=2.0,
        frequency="daily",
    )
    foreign_compound = Compound(
        protocol_id=foreign_protocol.id,
        name="Foreign Compound",
        dose_mg=3.0,
        frequency="weekly",
    )
    inactive_compound = Compound(
        protocol_id=inactive_protocol.id,
        name="Inactive Compound",
        dose_mg=4.0,
        frequency="weekly",
    )
    db_session.add_all([compound, second_compound, inactive_compound, foreign_compound])
    await db_session.commit()

    return AccountWithProtocol(
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
        user_id=user_id,
        compound=compound,
        second_compound=second_compound,
        inactive_compound=inactive_compound,
        foreign_compound=foreign_compound,
    )


def reminder_payload(compound: Compound, local_time: str, enabled: bool = True) -> dict:
    return {
        "compound_id": str(compound.id),
        "local_time": local_time,
        "enabled": enabled,
    }


async def test_patch_preferences_replaces_owned_dose_schedules(client, account_with_protocol):
    first = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={
            "dose_reminders_enabled": True,
            "daily_checkin_reminders_enabled": True,
            "daily_checkin_time": "09:00:00",
            "detailed_previews_enabled": False,
            "quiet_hours_start": "22:00:00",
            "quiet_hours_end": "07:00:00",
            "dose_reminders": [reminder_payload(account_with_protocol.compound, "08:30:00")],
        },
    )

    assert first.status_code == 200
    assert first.json()["dose_reminders"] == [
        reminder_payload(account_with_protocol.compound, "08:30:00")
    ]

    replacement = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={
            "dose_reminders": [
                reminder_payload(account_with_protocol.second_compound, "19:15:00", False)
            ]
        },
    )

    assert replacement.status_code == 200
    payload = replacement.json()
    assert payload["dose_reminders"] == [
        reminder_payload(account_with_protocol.second_compound, "19:15:00", False)
    ]
    assert payload["dose_reminders_enabled"] is True
    assert payload["daily_checkin_time"] == "09:00:00"


async def test_patch_preferences_rejects_foreign_compound_before_mutation(
    client,
    account_with_protocol,
):
    initial = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={
            "insights_enabled": True,
            "dose_reminders": [reminder_payload(account_with_protocol.compound, "08:30:00")],
        },
    )
    assert initial.status_code == 200

    rejected = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={
            "insights_enabled": False,
            "dose_reminders": [
                reminder_payload(account_with_protocol.foreign_compound, "09:30:00")
            ],
        },
    )

    assert rejected.status_code == 400
    current = await client.get(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
    )
    assert current.status_code == 200
    assert current.json()["insights_enabled"] is True
    assert current.json()["dose_reminders"] == [
        reminder_payload(account_with_protocol.compound, "08:30:00")
    ]


async def test_patch_preferences_rejects_duplicate_compound_schedules(
    client,
    account_with_protocol,
):
    response = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={
            "dose_reminders": [
                reminder_payload(account_with_protocol.compound, "08:30:00"),
                reminder_payload(account_with_protocol.compound, "18:30:00"),
            ]
        },
    )

    assert response.status_code == 400


async def test_patch_preferences_rejects_compound_from_inactive_protocol(
    client,
    account_with_protocol,
):
    response = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={
            "dose_reminders": [
                reminder_payload(account_with_protocol.inactive_compound, "08:30:00")
            ]
        },
    )

    assert response.status_code == 400


async def test_patch_preferences_omitted_schedules_preserve_existing_collection(
    client,
    account_with_protocol,
):
    expected_reminders = [reminder_payload(account_with_protocol.compound, "08:30:00")]
    initial = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={"dose_reminders": expected_reminders},
    )
    assert initial.status_code == 200

    updated = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={"insights_enabled": False},
    )

    assert updated.status_code == 200
    assert updated.json()["dose_reminders"] == expected_reminders


async def test_patch_preferences_explicitly_clears_times_and_schedules(
    client,
    account_with_protocol,
):
    initial = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={
            "insights_enabled": True,
            "dose_reminders_enabled": True,
            "daily_checkin_reminders_enabled": True,
            "daily_checkin_time": "09:00:00",
            "quiet_hours_start": "22:00:00",
            "quiet_hours_end": "07:00:00",
            "dose_reminders": [reminder_payload(account_with_protocol.compound, "08:30:00")],
        },
    )
    assert initial.status_code == 200

    cleared = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={
            "daily_checkin_time": None,
            "quiet_hours_start": None,
            "quiet_hours_end": None,
            "dose_reminders": [],
        },
    )

    assert cleared.status_code == 200
    payload = cleared.json()
    assert payload["daily_checkin_time"] is None
    assert payload["quiet_hours_start"] is None
    assert payload["quiet_hours_end"] is None
    assert payload["dose_reminders"] == []
    assert payload["insights_enabled"] is True
    assert payload["dose_reminders_enabled"] is True


async def test_patch_preferences_null_booleans_preserve_non_null_values(
    client,
    account_with_protocol,
):
    boolean_fields = (
        "insights_enabled",
        "alert_severity_only",
        "dose_reminders_enabled",
        "daily_checkin_reminders_enabled",
        "detailed_previews_enabled",
    )
    initial = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={field: True for field in boolean_fields},
    )
    assert initial.status_code == 200

    response = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={field: None for field in boolean_fields},
    )

    assert response.status_code == 200
    assert all(response.json()[field] is True for field in boolean_fields)


async def test_patch_preferences_rejects_unknown_fields(client, account_with_protocol):
    response = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={"insights_enabled": True, "marketing_enabled": True},
    )

    assert response.status_code == 422


async def test_update_preferences_commits_preference_and_schedules_once(
    db_session,
    account_with_protocol,
    monkeypatch,
):
    user = await db_session.get(User, account_with_protocol.user_id)
    commit = AsyncMock(wraps=db_session.commit)
    monkeypatch.setattr(db_session, "commit", commit)

    await NotificationService(db_session).update_preferences(
        user,
        {
            "dose_reminders_enabled": True,
            "dose_reminders": [
                {
                    "compound_id": account_with_protocol.compound.id,
                    "local_time": time(8, 30),
                    "enabled": True,
                }
            ],
        },
    )

    assert commit.await_count == 1


@dataclass
class NotificationFixture:
    service: NotificationService
    user: User
    insight_id: UUID
    adapter: MockPushAdapter
    preference: NotificationPreference


@pytest_asyncio.fixture
async def notification_fixture(db_session):
    user = User(
        email="notification-policy@example.com",
        hashed_password="unused",
        timezone="America/New_York",
    )
    db_session.add(user)
    await db_session.flush()
    preference = NotificationPreference(
        user_id=user.id,
        insights_enabled=True,
        alert_severity_only=False,
        quiet_hours_start=time(22, 0),
        quiet_hours_end=time(7, 0),
        detailed_previews_enabled=False,
    )
    device = DeviceToken(
        user_id=user.id,
        token="notification-policy-device",
        platform=DevicePlatform.IOS,
    )
    db_session.add_all([preference, device])
    await db_session.commit()

    return NotificationFixture(
        service=NotificationService(db_session),
        user=user,
        insight_id=uuid4(),
        adapter=MockPushAdapter(),
        preference=preference,
    )


async def test_routine_insight_is_suppressed_during_overnight_quiet_hours(
    notification_fixture,
):
    result = await notification_fixture.service.send_insight_notification(
        user_id=notification_fixture.user.id,
        insight_id=notification_fixture.insight_id,
        title="Sensitive detail",
        body="Sensitive body",
        severity=InsightSeverity.INFO,
        ios_adapter=notification_fixture.adapter,
        now=datetime(2026, 7, 21, 3, 0, tzinfo=timezone.utc),
    )

    assert result == {"sent": 0, "failed": 0, "skipped_reason": "quiet_hours"}
    assert notification_fixture.adapter.sent == []


async def test_alert_insight_bypasses_quiet_hours_with_generic_copy(notification_fixture):
    result = await notification_fixture.service.send_insight_notification(
        user_id=notification_fixture.user.id,
        insight_id=notification_fixture.insight_id,
        title="Sensitive detail",
        body="Sensitive body",
        severity=InsightSeverity.ALERT,
        ios_adapter=notification_fixture.adapter,
        now=datetime(2026, 7, 21, 3, 0, tzinfo=timezone.utc),
    )

    assert result == {"sent": 1, "failed": 0, "skipped_reason": None}
    assert notification_fixture.adapter.sent == [
        {
            "token": "notification-policy-device",
            "title": "Peppy",
            "body": "A Peppy alert needs your attention.",
            "data": {"insight_id": str(notification_fixture.insight_id)},
        }
    ]


async def test_routine_insight_outside_quiet_hours_uses_generic_copy(notification_fixture):
    result = await notification_fixture.service.send_insight_notification(
        user_id=notification_fixture.user.id,
        insight_id=notification_fixture.insight_id,
        title="Sensitive detail",
        body="Sensitive body",
        severity=InsightSeverity.INFO,
        ios_adapter=notification_fixture.adapter,
        now=datetime(2026, 7, 21, 12, 0, tzinfo=timezone.utc),
    )

    assert result["sent"] == 1
    assert notification_fixture.adapter.sent[0]["title"] == "Peppy"
    assert notification_fixture.adapter.sent[0]["body"] == "A new Peppy insight is ready."


async def test_detailed_previews_send_selected_insight_copy(notification_fixture, db_session):
    notification_fixture.preference.detailed_previews_enabled = True
    await db_session.commit()

    result = await notification_fixture.service.send_insight_notification(
        user_id=notification_fixture.user.id,
        insight_id=notification_fixture.insight_id,
        title="Selected title",
        body="Selected body",
        severity=InsightSeverity.INFO,
        ios_adapter=notification_fixture.adapter,
        now=datetime(2026, 7, 21, 12, 0, tzinfo=timezone.utc),
    )

    assert result["sent"] == 1
    assert notification_fixture.adapter.sent[0]["title"] == "Selected title"
    assert notification_fixture.adapter.sent[0]["body"] == "Selected body"


async def test_alert_only_preference_suppresses_routine_insight_before_delivery(
    notification_fixture,
    db_session,
):
    notification_fixture.preference.alert_severity_only = True
    await db_session.commit()

    result = await notification_fixture.service.send_insight_notification(
        user_id=notification_fixture.user.id,
        insight_id=notification_fixture.insight_id,
        title="Sensitive detail",
        body="Sensitive body",
        severity=InsightSeverity.INFO,
        ios_adapter=notification_fixture.adapter,
        now=datetime(2026, 7, 21, 12, 0, tzinfo=timezone.utc),
    )

    assert result == {"sent": 0, "failed": 0, "skipped_reason": "alert_only"}
    assert notification_fixture.adapter.sent == []
