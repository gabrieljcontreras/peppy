from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class DoseLogCreate(BaseModel):
    protocol_id: UUID
    compound_id: UUID
    dose: float = Field(gt=0)
    unit: str = Field(min_length=1, max_length=20)
    administered_at: datetime
    route: str = Field(min_length=1, max_length=50)
    notes: Optional[str] = Field(default=None, max_length=2000)

    @field_validator("administered_at")
    @classmethod
    def validate_administered_at(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("administered_at must include a timezone offset")
        return value.astimezone(timezone.utc)


class DoseLogResponse(BaseModel):
    id: UUID
    protocol_id: UUID
    compound_id: UUID
    dose: float
    unit: str
    administered_at: datetime
    route: str
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
