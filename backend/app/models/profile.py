from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy.orm import relationship

from app.models.base import GUID, Base, TimestampMixin, UUIDMixin


class OnboardingProfile(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "onboarding_profiles"
    __table_args__ = (
        CheckConstraint("schema_version = 1", name="ck_onboarding_profiles_schema_version"),
        CheckConstraint("age IS NULL OR age BETWEEN 13 AND 120", name="ck_onboarding_profiles_age"),
        CheckConstraint(
            "height_cm IS NULL OR height_cm BETWEEN 100 AND 250",
            name="ck_onboarding_profiles_height_cm",
        ),
        CheckConstraint(
            "preferred_height_unit IS NULL OR preferred_height_unit IN ('ft_in', 'cm')",
            name="ck_onboarding_profiles_preferred_height_unit",
        ),
        CheckConstraint(
            "weight_kg IS NULL OR weight_kg BETWEEN 27 AND 318",
            name="ck_onboarding_profiles_weight_kg",
        ),
        CheckConstraint(
            "preferred_weight_unit IS NULL OR preferred_weight_unit IN ('lb', 'kg')",
            name="ck_onboarding_profiles_preferred_weight_unit",
        ),
        CheckConstraint(
            "workout_days_per_week IS NULL OR workout_days_per_week BETWEEN 0 AND 7",
            name="ck_onboarding_profiles_workout_days_per_week",
        ),
    )

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, unique=True, index=True)
    schema_version = Column(Integer, default=1, server_default="1", nullable=False)

    age = Column(Integer, nullable=True)
    height_cm = Column(Float, nullable=True)
    preferred_height_unit = Column(String(10), nullable=True)
    weight_kg = Column(Float, nullable=True)
    preferred_weight_unit = Column(String(10), nullable=True)
    peptides = Column(JSON, default=list, nullable=False)
    custom_peptides = Column(JSON, default=list, nullable=False)
    other_medications = Column(String(200), nullable=True)
    workout_days_per_week = Column(Integer, nullable=True)
    goals = Column(JSON, default=list, nullable=False)
    custom_goal = Column(String(200), nullable=True)
    baseline_date = Column(Date, nullable=True)
    primary_goal = Column(String(100), nullable=True)
    secondary_goal = Column(String(100), nullable=True)
    focus_area = Column(String(100), nullable=True)

    healthkit_requested = Column(Boolean, nullable=True)
    healthkit_last_sync_at = Column(DateTime(timezone=True), nullable=True)
    notifications_authorized = Column(Boolean, nullable=True)

    source_draft_id = Column(String(200), nullable=True)
    source_draft_created_at = Column(DateTime(timezone=True), nullable=True)
    source_draft_updated_at = Column(DateTime(timezone=True), nullable=True)
    source_current_step = Column(String(100), nullable=True)
    source_is_complete = Column(Boolean, nullable=True)

    user = relationship("User", back_populates="onboarding_profile")
