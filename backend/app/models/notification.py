from sqlalchemy import Column, ForeignKey, String, Enum, DateTime
from sqlalchemy.orm import relationship
import enum
from app.models.base import Base, UUIDMixin, TimestampMixin, GUID


class DevicePlatform(enum.Enum):
    IOS = "ios"
    ANDROID = "android"


class DeviceToken(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "device_tokens"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    token = Column(String(512), nullable=False, index=True)
    platform = Column(Enum(DevicePlatform), nullable=False)
    last_used_at = Column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="device_tokens")
