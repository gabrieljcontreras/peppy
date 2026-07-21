import enum

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, String, Time, UniqueConstraint
from sqlalchemy.orm import relationship

from app.models.base import GUID, Base, TimestampMixin, UUIDMixin


class DevicePlatform(enum.Enum):
    IOS = "ios"
    ANDROID = "android"


class NotificationPreference(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "notification_preferences"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, unique=True, index=True)
    insights_enabled = Column(Boolean, default=True, nullable=False)
    alert_severity_only = Column(Boolean, default=False, nullable=False)
    quiet_hours_start = Column(Time, nullable=True)
    quiet_hours_end = Column(Time, nullable=True)
    dose_reminders_enabled = Column(Boolean, default=False, server_default="0", nullable=False)
    daily_checkin_reminders_enabled = Column(
        Boolean, default=False, server_default="0", nullable=False
    )
    daily_checkin_time = Column(Time, nullable=True)
    detailed_previews_enabled = Column(Boolean, default=False, server_default="0", nullable=False)

    user = relationship("User", back_populates="notification_preference")


class DeviceToken(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "device_tokens"
    __table_args__ = (UniqueConstraint("token", name="uq_device_tokens_token"),)

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    token = Column(String(512), nullable=False, index=True)
    platform = Column(Enum(DevicePlatform), nullable=False)
    last_used_at = Column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="device_tokens")


class DoseReminderSetting(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "dose_reminder_settings"
    __table_args__ = (
        UniqueConstraint("user_id", "compound_id", name="uq_dose_reminder_user_compound"),
    )

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    compound_id = Column(
        GUID(), ForeignKey("compounds.id", ondelete="CASCADE"), nullable=False, index=True
    )
    local_time = Column(Time, nullable=False)
    enabled = Column(Boolean, default=True, server_default="1", nullable=False)

    user = relationship("User", back_populates="dose_reminder_settings")
    compound = relationship("Compound", back_populates="reminder_settings")
