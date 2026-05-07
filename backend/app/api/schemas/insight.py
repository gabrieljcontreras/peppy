from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from uuid import UUID
from enum import Enum


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


class InsightResponse(InsightBase):
    id: UUID
    created_at: datetime
    read_at: Optional[datetime] = None
    dismissed_at: Optional[datetime] = None
    action_taken: Optional[str] = None
    action_notes: Optional[str] = None

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
