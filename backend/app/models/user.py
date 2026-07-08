from sqlalchemy import Column, String, Boolean
from sqlalchemy.orm import relationship
from app.models.base import Base, UUIDMixin, TimestampMixin


class User(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "users"

    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)

    # Profile
    display_name = Column(String(100), nullable=True)
    timezone = Column(String(50), default="UTC", nullable=False)

    # Relationships
    protocols = relationship("Protocol", back_populates="user", cascade="all, delete-orphan")
    dose_logs = relationship("DoseLog", back_populates="user", cascade="all, delete")
    checkins = relationship("Checkin", back_populates="user", cascade="all, delete-orphan")
    lab_results = relationship("LabResult", back_populates="user", cascade="all, delete-orphan")
    insights = relationship("Insight", back_populates="user", cascade="all, delete-orphan")
    wearable_connections = relationship("WearableConnection", back_populates="user", cascade="all, delete-orphan")
    jobs = relationship("Job", back_populates="user", cascade="all, delete-orphan")
    device_tokens = relationship("DeviceToken", back_populates="user", cascade="all, delete-orphan")
    notification_preference = relationship("NotificationPreference", back_populates="user", uselist=False, cascade="all, delete-orphan")
    onboarding_profile = relationship("OnboardingProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")
