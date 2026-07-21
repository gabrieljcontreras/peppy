from dataclasses import dataclass
from unittest.mock import AsyncMock, Mock

import pytest

from app.config import Settings
from app.integrations import push as push_module
from app.integrations.push import APNsAdapter, MockPushAdapter, PushDeliveryResult
from app.models.notification import DevicePlatform, DeviceToken
from app.models.user import User
from app.services.notification import NotificationService


@dataclass
class FakeAPNsResponse:
    is_successful: bool
    description: str | None = None


class FakeAPNsClient:
    def __init__(self, *responses: FakeAPNsResponse):
        self.responses = list(responses)
        self.requests = []

    async def send_notification(self, request):
        self.requests.append(request)
        return self.responses.pop(0)


async def test_apns_adapter_builds_alert_payload_without_logging_body(caplog):
    client = FakeAPNsClient(FakeAPNsResponse(is_successful=True))
    adapter = APNsAdapter(client)

    result = await adapter.send(
        token="abc123",
        title="Peppy",
        body="A new Peppy insight is ready.",
        data={"insight_id": "opaque-id"},
    )

    assert result == PushDeliveryResult(success=True)
    request = client.requests[0]
    assert request.device_token == "abc123"
    assert request.message == {
        "aps": {
            "alert": {
                "title": "Peppy",
                "body": "A new Peppy insight is ready.",
            }
        },
        "insight_id": "opaque-id",
    }
    assert request.push_type.value == "alert"
    assert "abc123" not in caplog.text
    assert "A new Peppy insight is ready." not in caplog.text


@pytest.mark.parametrize(
    "reason",
    ("BadDeviceToken", "DeviceTokenNotForTopic", "Unregistered"),
)
async def test_apns_adapter_marks_permanent_token_rejections_invalid(reason):
    client = FakeAPNsClient(
        FakeAPNsResponse(is_successful=False, description=reason),
    )

    result = await APNsAdapter(client).send(
        token="invalid-token",
        title="Peppy",
        body="Generic body",
    )

    assert result == PushDeliveryResult(
        success=False,
        invalid_token=True,
        reason=reason,
    )


async def test_apns_adapter_preserves_retryable_provider_failure():
    client = FakeAPNsClient(
        FakeAPNsResponse(is_successful=False, description="TooManyRequests"),
    )

    result = await APNsAdapter(client).send(
        token="valid-token",
        title="Peppy",
        body="Generic body",
    )

    assert result == PushDeliveryResult(
        success=False,
        invalid_token=False,
        reason="TooManyRequests",
    )


def test_apns_adapter_is_disabled_until_all_credentials_are_configured():
    settings = Settings(
        debug=True,
        apns_key="key-body",
        apns_key_id="key-id",
        apns_team_id="team-id",
        apns_topic="",
    )

    assert APNsAdapter.from_settings(settings) is None


def test_apns_adapter_builds_one_client_from_key_body_and_environment(monkeypatch):
    client = object()
    client_factory = Mock(return_value=client)
    monkeypatch.setattr(push_module, "APNs", client_factory, raising=False)
    settings = Settings(
        debug=True,
        apns_key="-----BEGIN PRIVATE KEY-----\nsecret\n-----END PRIVATE KEY-----",
        apns_key_id="key-id",
        apns_team_id="team-id",
        apns_topic="com.example.peppy",
        apns_use_sandbox=True,
    )

    adapter = APNsAdapter.from_settings(settings)

    assert adapter is not None
    assert adapter.client is client
    client_factory.assert_called_once_with(
        key=settings.apns_key,
        key_id="key-id",
        team_id="team-id",
        topic="com.example.peppy",
        max_connection_attempts=3,
        use_sandbox=True,
    )


async def test_invalid_apns_tokens_are_deleted_with_one_commit(db_session, monkeypatch):
    user = User(email="invalid-apns@example.com", hashed_password="unused")
    db_session.add(user)
    await db_session.flush()
    db_session.add_all(
        [
            DeviceToken(user_id=user.id, token="invalid-one", platform=DevicePlatform.IOS),
            DeviceToken(user_id=user.id, token="invalid-two", platform=DevicePlatform.IOS),
        ]
    )
    await db_session.commit()
    commit = AsyncMock(wraps=db_session.commit)
    monkeypatch.setattr(db_session, "commit", commit)
    adapter = MockPushAdapter(
        result=PushDeliveryResult(
            success=False,
            invalid_token=True,
            reason="Unregistered",
        )
    )
    service = NotificationService(db_session)

    result = await service.send_push(
        user.id,
        "Peppy",
        "A new Peppy insight is ready.",
        ios_adapter=adapter,
    )

    assert result == {"sent": 0, "failed": 2}
    assert await service.list_devices(user.id) == []
    commit.assert_awaited_once_with()


async def test_retryable_apns_failure_preserves_device_token(db_session, monkeypatch):
    user = User(email="retryable-apns@example.com", hashed_password="unused")
    db_session.add(user)
    await db_session.flush()
    device = DeviceToken(
        user_id=user.id,
        token="still-valid",
        platform=DevicePlatform.IOS,
    )
    db_session.add(device)
    await db_session.commit()
    commit = AsyncMock(wraps=db_session.commit)
    monkeypatch.setattr(db_session, "commit", commit)
    adapter = MockPushAdapter(
        result=PushDeliveryResult(
            success=False,
            invalid_token=False,
            reason="TooManyRequests",
        )
    )
    service = NotificationService(db_session)

    result = await service.send_push(
        user.id,
        "Peppy",
        "A new Peppy insight is ready.",
        ios_adapter=adapter,
    )

    assert result == {"sent": 0, "failed": 1}
    assert [stored.id for stored in await service.list_devices(user.id)] == [device.id]
    commit.assert_not_awaited()
