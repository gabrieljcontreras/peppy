from abc import ABC, abstractmethod
from typing import Any


class PushAdapter(ABC):
    """Base class for push notification adapters."""

    @abstractmethod
    async def send(self, token: str, title: str, body: str, data: dict[str, Any] | None = None) -> bool:
        """Send a push notification to a device token.

        Returns True if sent successfully, False otherwise.
        """
        pass


class FCMAdapter(PushAdapter):
    """Firebase Cloud Messaging adapter for Android."""

    def __init__(self, credentials_path: str | None = None):
        self.credentials_path = credentials_path

    async def send(self, token: str, title: str, body: str, data: dict[str, Any] | None = None) -> bool:
        # TODO: Implement actual FCM sending via firebase-admin SDK
        # For now, this is a placeholder that will be wired up in production
        raise NotImplementedError("FCM sending not yet implemented")


class APNsAdapter(PushAdapter):
    """Apple Push Notification service adapter for iOS."""

    def __init__(self, key_path: str | None = None, key_id: str | None = None, team_id: str | None = None):
        self.key_path = key_path
        self.key_id = key_id
        self.team_id = team_id

    async def send(self, token: str, title: str, body: str, data: dict[str, Any] | None = None) -> bool:
        # TODO: Implement actual APNs sending
        # For now, this is a placeholder that will be wired up in production
        raise NotImplementedError("APNs sending not yet implemented")


class MockPushAdapter(PushAdapter):
    """Mock adapter for testing."""

    def __init__(self):
        self.sent: list[dict] = []

    async def send(self, token: str, title: str, body: str, data: dict[str, Any] | None = None) -> bool:
        self.sent.append({
            "token": token,
            "title": title,
            "body": body,
            "data": data,
        })
        return True
