from datetime import datetime, time
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.integrations.push import PushAdapter
from app.models.insight import InsightSeverity
from app.models.notification import DevicePlatform, DeviceToken, NotificationPreference


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
        result = await self.db.execute(select(DeviceToken).where(DeviceToken.user_id == user_id))
        return list(result.scalars().all())

    async def get_device_by_token(self, user_id: UUID, token: str) -> DeviceToken | None:
        result = await self.db.execute(
            select(DeviceToken).where(
                DeviceToken.user_id == user_id,
                DeviceToken.token == token,
            )
        )
        return result.scalar_one_or_none()

    async def _get_device_by_token_globally(self, token: str) -> DeviceToken | None:
        result = await self.db.execute(select(DeviceToken).where(DeviceToken.token == token))
        return result.scalar_one_or_none()

    async def register_device(
        self,
        user_id: UUID,
        token: str,
        platform: DevicePlatform,
    ) -> DeviceToken:
        existing = await self._get_device_by_token_globally(token)
        if existing:
            existing.user_id = user_id
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
        try:
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            existing = await self._get_device_by_token_globally(token)
            if existing is None:
                raise
            existing.user_id = user_id
            existing.platform = platform
            await self.db.commit()
            await self.db.refresh(existing)
            return existing
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

    async def send_insight_notification(
        self,
        user_id: UUID,
        insight_id: UUID,
        title: str,
        body: str,
        severity: InsightSeverity,
        ios_adapter: PushAdapter | None = None,
        android_adapter: PushAdapter | None = None,
    ) -> dict[str, Any]:
        """Send push notification for an insight, respecting user preferences.

        Returns dict with 'sent', 'failed', and 'skipped_reason' (if skipped).
        """
        pref = await self.get_or_create_preferences(user_id)

        if not pref.insights_enabled:
            return {"sent": 0, "failed": 0, "skipped_reason": "insights_disabled"}

        if pref.alert_severity_only and severity != InsightSeverity.ALERT:
            return {"sent": 0, "failed": 0, "skipped_reason": "alert_only"}

        if self._is_quiet_hours(pref):
            return {"sent": 0, "failed": 0, "skipped_reason": "quiet_hours"}

        result = await self.send_push(
            user_id=user_id,
            title=title,
            body=body,
            data={"insight_id": str(insight_id)},
            ios_adapter=ios_adapter,
            android_adapter=android_adapter,
        )
        return {**result, "skipped_reason": None}

    def _is_quiet_hours(self, pref: NotificationPreference) -> bool:
        """Check if current time falls within user's quiet hours."""
        if not pref.quiet_hours_start or not pref.quiet_hours_end:
            return False

        now = datetime.now().time()
        start = pref.quiet_hours_start
        end = pref.quiet_hours_end

        if start <= end:
            return start <= now <= end
        else:
            return now >= start or now <= end
