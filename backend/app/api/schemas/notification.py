from datetime import datetime, time
from enum import Enum
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DevicePlatform(str, Enum):
    IOS = "ios"
    ANDROID = "android"


class DeviceTokenCreate(BaseModel):
    token: str = Field(..., min_length=1, max_length=512)
    platform: DevicePlatform


class DeviceTokenResponse(BaseModel):
    id: UUID
    token: str
    platform: DevicePlatform
    last_used_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


class DoseReminderSettingPayload(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    compound_id: UUID
    local_time: time
    enabled: bool = True


class NotificationPreferenceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    insights_enabled: bool
    alert_severity_only: bool
    dose_reminders_enabled: bool
    daily_checkin_reminders_enabled: bool
    daily_checkin_time: time | None
    detailed_previews_enabled: bool
    quiet_hours_start: time | None
    quiet_hours_end: time | None
    dose_reminders: list[DoseReminderSettingPayload]


class NotificationPreferenceUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    insights_enabled: bool | None = None
    alert_severity_only: bool | None = None
    dose_reminders_enabled: bool | None = None
    daily_checkin_reminders_enabled: bool | None = None
    daily_checkin_time: time | None = None
    detailed_previews_enabled: bool | None = None
    quiet_hours_start: time | None = None
    quiet_hours_end: time | None = None
    dose_reminders: list[DoseReminderSettingPayload] | None = None
