from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID
from enum import Enum

router = APIRouter()


class InsightType(str, Enum):
    ANOMALY = "anomaly"
    TREND = "trend"
    SUGGESTION = "suggestion"
    MILESTONE = "milestone"


class InsightSeverity(str, Enum):
    INFO = "info"
    WARNING = "warning"
    ALERT = "alert"


class InsightResponse(BaseModel):
    id: UUID
    type: InsightType
    severity: InsightSeverity
    title: str
    description: str
    explanation: str  # Why this insight was generated
    confidence: float  # 0.0 to 1.0
    created_at: datetime
    read_at: Optional[datetime]
    dismissed_at: Optional[datetime]
    action_taken: Optional[str]


class InsightAction(BaseModel):
    action: str  # "accept", "dismiss", "snooze"
    notes: Optional[str] = None


@router.get("/", response_model=list[InsightResponse])
async def list_insights(
    unread_only: bool = False,
    type: Optional[InsightType] = None,
    severity: Optional[InsightSeverity] = None,
):
    # TODO: Return user's insights with filtering
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/latest", response_model=list[InsightResponse])
async def get_latest_insights(limit: int = 5):
    # TODO: Get most recent insights
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/{insight_id}", response_model=InsightResponse)
async def get_insight(insight_id: UUID):
    # TODO: Get specific insight
    raise HTTPException(status_code=501, detail="Not implemented")


@router.post("/{insight_id}/action")
async def take_action_on_insight(insight_id: UUID, action: InsightAction):
    # TODO: Record user's action on an insight
    raise HTTPException(status_code=501, detail="Not implemented")


@router.post("/{insight_id}/read")
async def mark_insight_read(insight_id: UUID):
    # TODO: Mark insight as read
    raise HTTPException(status_code=501, detail="Not implemented")


@router.post("/generate")
async def trigger_insight_generation():
    # TODO: Manually trigger insight generation (normally done async)
    raise HTTPException(status_code=501, detail="Not implemented")
