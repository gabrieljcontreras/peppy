from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


def validate_schema_version(value: int) -> int:
    if value != 1:
        raise ValueError("schema_version must be 1")
    return value


class HealthKitPayload(BaseModel):
    requested: bool | None = None
    last_sync_at: datetime | None = None


class NotificationsPayload(BaseModel):
    authorized: bool | None = None


class OnboardingProfilePayload(BaseModel):
    schema_version: int = Field(default=1)
    age: int | None = Field(default=None, ge=13, le=120)
    height_cm: float | None = Field(default=None, ge=100, le=250)
    preferred_height_unit: Literal["ft_in", "cm"] | None = None
    weight_kg: float | None = Field(default=None, ge=27, le=318)
    preferred_weight_unit: Literal["lb", "kg"] | None = None
    peptides: list[str] | None = None
    custom_peptides: list[str] | None = None
    other_medications: str | None = Field(default=None, max_length=200)
    workout_days_per_week: int | None = Field(default=None, ge=0, le=7)
    goals: list[str] | None = None
    custom_goal: str | None = Field(default=None, max_length=200)
    healthkit: HealthKitPayload | None = None
    notifications: NotificationsPayload | None = None

    @field_validator("schema_version")
    @classmethod
    def schema_version_is_supported(cls, value: int) -> int:
        return validate_schema_version(value)

    @field_validator("peptides", "custom_peptides", "goals")
    @classmethod
    def trim_unique_list(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return value

        normalized = []
        seen = set()
        for item in value:
            stripped = item.strip()
            if not stripped:
                continue
            if len(stripped) > 200:
                raise ValueError("list items must be 200 characters or fewer")
            key = stripped.casefold()
            if key in seen:
                continue
            seen.add(key)
            normalized.append(stripped)
        return normalized

    @field_validator("other_medications", "custom_goal")
    @classmethod
    def trim_optional_string(cls, value: str | None) -> str | None:
        if value is None:
            return value
        stripped = value.strip()
        return stripped or None


class OnboardingProfileAttachRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schema_version: int = Field(default=1)
    draft_id: str = Field(min_length=1, max_length=200)
    draft_created_at: datetime | None = None
    draft_updated_at: datetime | None = None
    is_complete: bool
    current_step: str | None = Field(default=None, max_length=100)
    profile: OnboardingProfilePayload

    @field_validator("schema_version")
    @classmethod
    def schema_version_is_supported(cls, value: int) -> int:
        return validate_schema_version(value)


class OnboardingProfileResponse(BaseModel):
    id: UUID
    schema_version: int
    age: int | None
    height_cm: float | None
    preferred_height_unit: Literal["ft_in", "cm"] | None
    weight_kg: float | None
    preferred_weight_unit: Literal["lb", "kg"] | None
    peptides: list[str]
    custom_peptides: list[str]
    other_medications: str | None
    workout_days_per_week: int | None
    goals: list[str]
    custom_goal: str | None
    healthkit: HealthKitPayload | None
    notifications: NotificationsPayload | None
    source_draft_id: str | None
    source_draft_created_at: datetime | None
    source_draft_updated_at: datetime | None
    source_current_step: str | None
    source_is_complete: bool | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
