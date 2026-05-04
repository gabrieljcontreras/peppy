from sqlalchemy import Column, Float, DateTime, Date, ForeignKey, Text, Enum, Boolean
from sqlalchemy.orm import relationship
import enum
from app.models.base import Base, UUIDMixin, TimestampMixin, GUID


class WearableProvider(enum.Enum):
    APPLE_HEALTH = "apple_health"
    OURA = "oura"
    WHOOP = "whoop"


class WearableConnection(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "wearable_connections"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    provider = Column(Enum(WearableProvider), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # OAuth tokens (encrypted in production)
    access_token = Column(Text, nullable=True)
    refresh_token = Column(Text, nullable=True)
    token_expires_at = Column(DateTime(timezone=True), nullable=True)

    last_sync_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", back_populates="wearable_connections")


class WearableData(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "wearable_data"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    provider = Column(Enum(WearableProvider), nullable=False)
    date = Column(Date, nullable=False, index=True)

    # Normalized metrics (not all providers have all metrics)
    sleep_hours = Column(Float, nullable=True)
    sleep_quality_score = Column(Float, nullable=True)  # Normalized 0-100
    hrv_ms = Column(Float, nullable=True)  # Heart rate variability in ms
    resting_hr = Column(Float, nullable=True)  # Resting heart rate
    steps = Column(Float, nullable=True)
    active_calories = Column(Float, nullable=True)
    recovery_score = Column(Float, nullable=True)  # Normalized 0-100
    strain_score = Column(Float, nullable=True)  # Normalized 0-100 (Whoop-style)
    readiness_score = Column(Float, nullable=True)  # Normalized 0-100 (Oura-style)

    # Raw data JSON for provider-specific fields
    raw_data = Column(Text, nullable=True)
