from sqlalchemy import Boolean, Column, DateTime, Integer, String
from sqlalchemy.orm import relationship

from app.models.base import Base, TimestampMixin, UUIDMixin


class User(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "users"

    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    auth_version = Column(Integer, default=1, server_default="1", nullable=False)

    # Profile
    display_name = Column(String(100), nullable=True)
    timezone = Column(String(50), default="UTC", nullable=False)

    # Staleness marker for generate-if-stale insight list fetches.
    last_insight_run_at = Column(DateTime(timezone=True), nullable=True)

    # Premium subscription state, synced from StoreKit transactions.
    subscription_tier = Column(
        String(20), default="free", server_default="free", nullable=False
    )
    subscription_product_id = Column(String(100), nullable=True)
    subscription_expires_at = Column(DateTime(timezone=True), nullable=True)
    subscription_original_transaction_id = Column(String(100), nullable=True, index=True)
    subscription_updated_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    protocols = relationship("Protocol", back_populates="user", cascade="all, delete-orphan")
    dose_logs = relationship("DoseLog", back_populates="user", cascade="all, delete")
    checkins = relationship("Checkin", back_populates="user", cascade="all, delete-orphan")
    lab_results = relationship("LabResult", back_populates="user", cascade="all, delete-orphan")
    insights = relationship("Insight", back_populates="user", cascade="all, delete-orphan")
    wearable_connections = relationship(
        "WearableConnection", back_populates="user", cascade="all, delete-orphan"
    )
    jobs = relationship("Job", back_populates="user", cascade="all, delete-orphan")
    device_tokens = relationship("DeviceToken", back_populates="user", cascade="all, delete-orphan")
    dose_reminder_settings = relationship(
        "DoseReminderSetting", back_populates="user", cascade="all, delete-orphan"
    )
    notification_preference = relationship(
        "NotificationPreference", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    onboarding_profile = relationship(
        "OnboardingProfile", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
