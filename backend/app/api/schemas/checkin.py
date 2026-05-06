from uuid import UUID
from datetime import date as date_type, datetime
from typing import Optional
from pydantic import BaseModel, Field


class CheckinBase(BaseModel):
    """Base checkin fields shared across create/update/response."""
    date: date_type = Field(description="Date of the check-in")
    weight_kg: Optional[float] = Field(
        default=None,
        gt=0,
        le=500,
        description="Weight in kilograms",
    )
    energy_level: Optional[int] = Field(
        default=None,
        ge=1,
        le=10,
        description="Energy level (1-10 scale)",
    )
    sleep_quality: Optional[int] = Field(
        default=None,
        ge=1,
        le=10,
        description="Sleep quality (1-10 scale)",
    )
    appetite_level: Optional[int] = Field(
        default=None,
        ge=1,
        le=10,
        description="Appetite level (1-10 scale)",
    )
    mood: Optional[int] = Field(
        default=None,
        ge=1,
        le=10,
        description="Mood (1-10 scale)",
    )
    nausea: Optional[int] = Field(
        default=None,
        ge=0,
        le=10,
        description="Nausea severity (0-10, 0 = none)",
    )
    injection_site_reaction: Optional[int] = Field(
        default=None,
        ge=0,
        le=10,
        description="Injection site reaction severity (0-10, 0 = none)",
    )
    fatigue: Optional[int] = Field(
        default=None,
        ge=0,
        le=10,
        description="Fatigue severity (0-10, 0 = none)",
    )
    headache: Optional[int] = Field(
        default=None,
        ge=0,
        le=10,
        description="Headache severity (0-10, 0 = none)",
    )
    gi_issues: Optional[int] = Field(
        default=None,
        ge=0,
        le=10,
        description="GI discomfort severity (0-10, 0 = none)",
    )
    notes: Optional[str] = Field(
        default=None,
        max_length=2000,
        description="Additional notes",
    )


class CheckinCreate(CheckinBase):
    """Schema for creating a new check-in."""
    pass


class CheckinUpdate(BaseModel):
    """Schema for updating a check-in. All fields optional."""
    date: Optional[date_type] = Field(default=None)
    weight_kg: Optional[float] = Field(default=None, gt=0, le=500)
    energy_level: Optional[int] = Field(default=None, ge=1, le=10)
    sleep_quality: Optional[int] = Field(default=None, ge=1, le=10)
    appetite_level: Optional[int] = Field(default=None, ge=1, le=10)
    mood: Optional[int] = Field(default=None, ge=1, le=10)
    nausea: Optional[int] = Field(default=None, ge=0, le=10)
    injection_site_reaction: Optional[int] = Field(default=None, ge=0, le=10)
    fatigue: Optional[int] = Field(default=None, ge=0, le=10)
    headache: Optional[int] = Field(default=None, ge=0, le=10)
    gi_issues: Optional[int] = Field(default=None, ge=0, le=10)
    notes: Optional[str] = Field(default=None, max_length=2000)


class CheckinResponse(BaseModel):
    """Schema for check-in in API responses."""
    id: UUID
    user_id: UUID
    date: date_type
    weight_kg: Optional[float]
    energy_level: Optional[int]
    sleep_quality: Optional[int]
    appetite_level: Optional[int]
    mood: Optional[int]
    nausea: Optional[int]
    injection_site_reaction: Optional[int]
    fatigue: Optional[int]
    headache: Optional[int]
    gi_issues: Optional[int]
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CheckinSummary(BaseModel):
    """Lightweight check-in for list views."""
    id: UUID
    date: date_type
    weight_kg: Optional[float]
    has_symptoms: bool
    created_at: datetime

    class Config:
        from_attributes = True


class WeightTrendPoint(BaseModel):
    """A single point in weight trend data."""
    date: date_type
    weight_kg: float


class CheckinStats(BaseModel):
    """Aggregated stats over a date range."""
    total_checkins: int
    avg_weight_kg: Optional[float]
    avg_energy: Optional[float]
    avg_sleep_quality: Optional[float]
    avg_mood: Optional[float]
    common_symptoms: list[str]
