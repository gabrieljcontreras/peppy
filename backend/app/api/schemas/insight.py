import json
from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class InsightType(str, Enum):
    ANOMALY = "anomaly"
    TREND = "trend"
    SUGGESTION = "suggestion"
    MILESTONE = "milestone"


class InsightSeverity(str, Enum):
    INFO = "info"
    WARNING = "warning"
    ALERT = "alert"


class InsightBase(BaseModel):
    type: InsightType
    severity: InsightSeverity
    title: str = Field(..., max_length=200)
    description: str
    explanation: str
    confidence: float = Field(..., ge=0.0, le=1.0)


class InsightCreate(InsightBase):
    source_data_refs: Optional[str] = None


class SupportingDataItem(BaseModel):
    icon_key: str
    label: str
    sublabel: Optional[str] = None
    value: str


class InsightResponse(InsightBase):
    id: UUID
    created_at: datetime
    read_at: Optional[datetime] = None
    dismissed_at: Optional[datetime] = None
    action_taken: Optional[str] = None
    action_notes: Optional[str] = None
    snoozed_until: Optional[datetime] = None
    supporting_data: Optional[list[SupportingDataItem]] = None

    @field_validator("supporting_data", mode="before")
    @classmethod
    def _parse_supporting_data(cls, value):
        if isinstance(value, str):
            return json.loads(value) if value else None
        return value

    model_config = {"from_attributes": True}


class InsightAction(BaseModel):
    action: str = Field(..., pattern="^(accept|dismiss|snooze)$")
    notes: Optional[str] = None


class InsightSummary(BaseModel):
    total: int
    unread: int
    by_type: dict[str, int]
    by_severity: dict[str, int]


class GenerationResult(BaseModel):
    insights_generated: int
    types_breakdown: dict[str, int]


class JobResponse(BaseModel):
    job_id: UUID
    status: str
    result: Optional[dict] = None
    error: Optional[str] = None

    model_config = {"from_attributes": True}
