from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

from aioapns import APNs, NotificationRequest, PushType

from app.config import Settings

APNS_MAX_CONNECTION_ATTEMPTS = 3
INVALID_APNS_TOKEN_REASONS = {
    "BadDeviceToken",
    "DeviceTokenNotForTopic",
    "Unregistered",
}


@dataclass(frozen=True)
class PushDeliveryResult:
    success: bool
    invalid_token: bool = False
    reason: str | None = None


class PushAdapter(ABC):
    """Base class for push notification adapters."""

    @abstractmethod
    async def send(
        self,
        token: str,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> PushDeliveryResult:
        """Send a push notification to a device token."""
        pass


class FCMAdapter(PushAdapter):
    """Firebase Cloud Messaging adapter for Android."""

    def __init__(self, credentials_path: str | None = None):
        self.credentials_path = credentials_path

    async def send(
        self,
        token: str,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> PushDeliveryResult:
        # TODO: Implement actual FCM sending via firebase-admin SDK
        # For now, this is a placeholder that will be wired up in production
        raise NotImplementedError("FCM sending not yet implemented")


class APNsAdapter(PushAdapter):
    """Apple Push Notification service adapter for iOS."""

    def __init__(self, client: APNs):
        self.client = client

    @classmethod
    def from_settings(cls, settings: Settings) -> "APNsAdapter | None":
        if not all(
            (
                settings.apns_key,
                settings.apns_key_id,
                settings.apns_team_id,
                settings.apns_topic,
            )
        ):
            return None

        return cls(
            APNs(
                key=settings.apns_key,
                key_id=settings.apns_key_id,
                team_id=settings.apns_team_id,
                topic=settings.apns_topic,
                max_connection_attempts=APNS_MAX_CONNECTION_ATTEMPTS,
                use_sandbox=settings.apns_use_sandbox,
            )
        )

    async def send(
        self,
        token: str,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> PushDeliveryResult:
        message = {
            **(data or {}),
            "aps": {"alert": {"title": title, "body": body}},
        }
        response = await self.client.send_notification(
            NotificationRequest(
                device_token=token,
                message=message,
                push_type=PushType.ALERT,
            )
        )
        if response.is_successful:
            return PushDeliveryResult(success=True)
        return PushDeliveryResult(
            success=False,
            invalid_token=response.description in INVALID_APNS_TOKEN_REASONS,
            reason=response.description,
        )


class MockPushAdapter(PushAdapter):
    """Mock adapter for testing."""

    def __init__(self, result: PushDeliveryResult | None = None):
        self.sent: list[dict] = []
        self.result = result or PushDeliveryResult(success=True)

    async def send(
        self,
        token: str,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> PushDeliveryResult:
        self.sent.append(
            {
                "token": token,
                "title": title,
                "body": body,
                "data": data,
            }
        )
        return self.result
