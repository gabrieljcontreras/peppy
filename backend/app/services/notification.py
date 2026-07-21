from datetime import datetime, timezone
from typing import Any
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.integrations.push import PushAdapter
from app.models.insight import InsightSeverity
from app.models.notification import (
    DevicePlatform,
    DeviceToken,
    DoseReminderSetting,
    NotificationPreference,
)
from app.models.protocol import Compound, Protocol
from app.models.user import User

PREFERENCE_FIELDS = (
    "insights_enabled",
    "alert_severity_only",
    "dose_reminders_enabled",
    "daily_checkin_reminders_enabled",
    "daily_checkin_time",
    "detailed_previews_enabled",
    "quiet_hours_start",
    "quiet_hours_end",
)
CLEARABLE_PREFERENCE_FIELDS = {
    "daily_checkin_time",
    "quiet_hours_start",
    "quiet_hours_end",
}


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

    async def _get_preferences(self, user_id: UUID) -> NotificationPreference | None:
        result = await self.db.execute(
            select(NotificationPreference).where(NotificationPreference.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def _attach_dose_reminders(
        self,
        pref: NotificationPreference,
    ) -> NotificationPreference:
        result = await self.db.execute(
            select(DoseReminderSetting)
            .where(DoseReminderSetting.user_id == pref.user_id)
            .order_by(DoseReminderSetting.local_time, DoseReminderSetting.compound_id)
        )
        pref.dose_reminders = list(result.scalars().all())
        return pref

    async def get_or_create_preferences(self, user_id: UUID) -> NotificationPreference:
        pref = await self._get_preferences(user_id)
        if pref is not None:
            return await self._attach_dose_reminders(pref)

        pref = NotificationPreference(user_id=user_id)
        self.db.add(pref)
        await self.db.commit()
        await self.db.refresh(pref)
        return await self._attach_dose_reminders(pref)

    async def update_preferences(
        self,
        user: User,
        changes: dict[str, Any],
    ) -> NotificationPreference:
        schedules_marker = object()
        schedules = changes.get("dose_reminders", schedules_marker)
        if schedules is not schedules_marker:
            schedules = schedules or []
            compound_ids = [schedule["compound_id"] for schedule in schedules]
            if len(compound_ids) != len(set(compound_ids)):
                raise ValueError("Dose reminder compounds must be unique")

            if compound_ids:
                result = await self.db.execute(
                    select(Compound.id)
                    .join(Protocol, Compound.protocol_id == Protocol.id)
                    .where(
                        Protocol.user_id == user.id,
                        Protocol.is_active.is_(True),
                        Compound.id.in_(compound_ids),
                    )
                )
                owned_compound_ids = set(result.scalars().all())
                if owned_compound_ids != set(compound_ids):
                    raise ValueError(
                        "Dose reminders must reference compounds in the active protocol"
                    )

        pref = await self._get_preferences(user.id)
        if pref is None:
            pref = NotificationPreference(user_id=user.id)
            self.db.add(pref)

        for field in PREFERENCE_FIELDS:
            if field in changes and (
                changes[field] is not None or field in CLEARABLE_PREFERENCE_FIELDS
            ):
                setattr(pref, field, changes[field])

        if schedules is not schedules_marker:
            await self.db.execute(
                delete(DoseReminderSetting).where(DoseReminderSetting.user_id == user.id)
            )
            for schedule in schedules:
                self.db.add(
                    DoseReminderSetting(
                        user_id=user.id,
                        compound_id=schedule["compound_id"],
                        local_time=schedule["local_time"],
                        enabled=schedule["enabled"],
                    )
                )

        await self.db.commit()
        await self.db.refresh(pref)
        return await self._attach_dose_reminders(pref)

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
        invalid_devices = []

        for device in devices:
            adapter = None
            if device.platform == DevicePlatform.IOS and ios_adapter:
                adapter = ios_adapter
            elif device.platform == DevicePlatform.ANDROID and android_adapter:
                adapter = android_adapter

            if adapter:
                try:
                    result = await adapter.send(device.token, title, body, data)
                    if result.success:
                        sent += 1
                    else:
                        failed += 1
                        if result.invalid_token:
                            invalid_devices.append(device)
                except Exception:
                    failed += 1

        if invalid_devices:
            for device in invalid_devices:
                await self.db.delete(device)
            await self.db.commit()

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
        now: datetime | None = None,
    ) -> dict[str, Any]:
        """Send push notification for an insight, respecting user preferences.

        Returns dict with 'sent', 'failed', and 'skipped_reason' (if skipped).
        """
        user = await self.db.get(User, user_id)
        if user is None:
            raise ValueError("User not found")
        pref = await self.get_or_create_preferences(user_id)

        if not pref.insights_enabled:
            return {"sent": 0, "failed": 0, "skipped_reason": "insights_disabled"}

        if pref.alert_severity_only and severity != InsightSeverity.ALERT:
            return {"sent": 0, "failed": 0, "skipped_reason": "alert_only"}

        if severity != InsightSeverity.ALERT and self._is_quiet_hours(
            pref,
            user.timezone,
            now,
        ):
            return {"sent": 0, "failed": 0, "skipped_reason": "quiet_hours"}

        title_to_send = title if pref.detailed_previews_enabled else "Peppy"
        body_to_send = (
            body
            if pref.detailed_previews_enabled
            else (
                "A Peppy alert needs your attention."
                if severity == InsightSeverity.ALERT
                else "A new Peppy insight is ready."
            )
        )

        result = await self.send_push(
            user_id=user_id,
            title=title_to_send,
            body=body_to_send,
            data={"insight_id": str(insight_id)},
            ios_adapter=ios_adapter,
            android_adapter=android_adapter,
        )
        return {**result, "skipped_reason": None}

    def _is_quiet_hours(
        self,
        pref: NotificationPreference,
        user_timezone: str,
        now: datetime | None = None,
    ) -> bool:
        """Check if current time falls within user's quiet hours."""
        if not pref.quiet_hours_start or not pref.quiet_hours_end:
            return False

        instant = now or datetime.now(timezone.utc)
        local_time = instant.astimezone(ZoneInfo(user_timezone)).time()
        start = pref.quiet_hours_start
        end = pref.quiet_hours_end

        if start <= end:
            return start <= local_time <= end
        return local_time >= start or local_time <= end
