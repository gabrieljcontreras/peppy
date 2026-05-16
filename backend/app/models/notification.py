from sqlalchemy import Column, ForeignKey, String, Enum, DateTime, Boolean, Time
from sqlalchemy.orm import relationship
import enum
from app.models.base import Base, UUIDMixin, TimestampMixin, GUID


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

    user = relationship("User", back_populates="notification_preference")


class DeviceToken(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "device_tokens"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    token = Column(String(512), nullable=False, index=True)
    platform = Column(Enum(DevicePlatform), nullable=False)
    last_used_at = Column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="device_tokens")
