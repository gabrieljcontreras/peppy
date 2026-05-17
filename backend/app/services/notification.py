from datetime import time
from typing import Any
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.notification import DeviceToken, DevicePlatform, NotificationPreference
from app.integrations.push import PushAdapter


class NotificationService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_device_by_id(self, device_id: UUID, user_id: UUID) -> DeviceToken | None:
        result = await self.db.execute(
            select(DeviceToken).where(
                DeviceToken.id == device_id,
                DeviceToken.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def delete_device(self, device: DeviceToken) -> None:
        await self.db.delete(device)
        await self.db.commit()

    async def list_devices(self, user_id: UUID) -> list[DeviceToken]:
        result = await self.db.execute(
            select(DeviceToken).where(DeviceToken.user_id == user_id)
        )
        return list(result.scalars().all())

    async def get_device_by_token(self, user_id: UUID, token: str) -> DeviceToken | None:
        result = await self.db.execute(
            select(DeviceToken).where(
                DeviceToken.user_id == user_id,
                DeviceToken.token == token,
            )
        )
        return result.scalar_one_or_none()

    async def register_device(
        self,
        user_id: UUID,
        token: str,
        platform: DevicePlatform,
    ) -> DeviceToken:
        existing = await self.get_device_by_token(user_id, token)
        if existing:
            existing.platform = platform
            await self.db.commit()
            await self.db.refresh(existing)
            return existing

        device = DeviceToken(
            user_id=user_id,
            token=token,
            platform=platform,
        )
        self.db.add(device)
        await self.db.commit()
        await self.db.refresh(device)
        return device

    async def get_or_create_preferences(self, user_id: UUID) -> NotificationPreference:
        result = await self.db.execute(
            select(NotificationPreference).where(NotificationPreference.user_id == user_id)
        )
        pref = result.scalar_one_or_none()
        if pref:
            return pref

        pref = NotificationPreference(user_id=user_id)
        self.db.add(pref)
        await self.db.commit()
        await self.db.refresh(pref)
        return pref

    async def update_preferences(
        self,
        user_id: UUID,
        insights_enabled: bool | None = None,
        alert_severity_only: bool | None = None,
        quiet_hours_start: time | None = None,
        quiet_hours_end: time | None = None,
    ) -> NotificationPreference:
        pref = await self.get_or_create_preferences(user_id)

        if insights_enabled is not None:
            pref.insights_enabled = insights_enabled
        if alert_severity_only is not None:
            pref.alert_severity_only = alert_severity_only
        if quiet_hours_start is not None:
            pref.quiet_hours_start = quiet_hours_start
        if quiet_hours_end is not None:
            pref.quiet_hours_end = quiet_hours_end

        await self.db.commit()
        await self.db.refresh(pref)
        return pref

    async def send_push(
        self,
        user_id: UUID,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
        ios_adapter: PushAdapter | None = None,
        android_adapter: PushAdapter | None = None,
    ) -> dict[str, int]:
        """Send push notification to all user's registered devices.

        Returns dict with 'sent' and 'failed' counts.
        """
        devices = await self.list_devices(user_id)

        sent = 0
        failed = 0

        for device in devices:
            adapter = None
            if device.platform == DevicePlatform.IOS and ios_adapter:
                adapter = ios_adapter
            elif device.platform == DevicePlatform.ANDROID and android_adapter:
                adapter = android_adapter

            if adapter:
                try:
                    success = await adapter.send(device.token, title, body, data)
                    if success:
                        sent += 1
                    else:
                        failed += 1
                except Exception:
                    failed += 1

        return {"sent": sent, "failed": failed}
