from typing import Annotated, Optional
from uuid import UUID
from datetime import date, timedelta
from collections import Counter

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.api.deps import CurrentUser
from app.services.insight import InsightService
from app.ml.insights_engine import InsightsEngine
from app.models.insight import InsightType as ModelInsightType, InsightSeverity as ModelInsightSeverity
from app.api.schemas.insight import (
    InsightResponse,
    InsightAction,
    InsightType,
    InsightSeverity,
    GenerationResult,
)

router = APIRouter()


@router.get("/", response_model=list[InsightResponse])
async def list_insights(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    unread_only: bool = Query(False, description="Only return insights the user has not read"),
    type: Optional[InsightType] = Query(None, description="Filter by insight type"),
    severity: Optional[InsightSeverity] = Query(None, description="Filter by severity"),
    limit: int = Query(100, ge=1, le=200, description="Maximum insights to return"),
    offset: int = Query(0, ge=0, description="Number of insights to skip"),
):
    """
    List insights for the authenticated user, newest first.
    """
    service = InsightService(db)
    insights = await service.list_for_user(
        user_id=current_user.id,
        unread_only=unread_only,
        type=ModelInsightType(type.value) if type else None,
        severity=ModelInsightSeverity(severity.value) if severity else None,
        limit=limit,
        offset=offset,
    )
    return insights


@router.get("/{insight_id}", response_model=InsightResponse)
async def get_insight(
    insight_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Get a specific insight by ID.

    Only returns insights owned by the authenticated user.
    """
    service = InsightService(db)
    insight = await service.get_by_id(insight_id, current_user.id)

    if not insight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Insight not found",
        )

    return insight


@router.post("/{insight_id}/action", response_model=InsightResponse)
async def take_action_on_insight(
    insight_id: UUID,
    action: InsightAction,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Record the user's action on an insight.

    Action must be one of: accept, dismiss, snooze.
    Dismiss also stamps dismissed_at.
    """
    service = InsightService(db)
    insight = await service.get_by_id(insight_id, current_user.id)

    if not insight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Insight not found",
        )

    updated = await service.record_action(insight, action=action.action, notes=action.notes)
    return updated


@router.post("/{insight_id}/read", response_model=InsightResponse)
async def mark_insight_read(
    insight_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Mark an insight as read. Idempotent.
    """
    service = InsightService(db)
    insight = await service.get_by_id(insight_id, current_user.id)

    if not insight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Insight not found",
        )

    updated = await service.mark_read(insight)
    return updated


@router.post("/generate", response_model=GenerationResult)
async def trigger_insight_generation(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: Optional[date] = Query(None, description="Analyze data from this date (default: today - 30 days)"),
    end_date: Optional[date] = Query(None, description="Analyze data up to this date (default: today)"),
):
    """
    Run the insights engine over the user's data and persist any
    generated insights. Returns a count and a breakdown by type.

    Defaults to the last 30 days when no date range is provided.
    """
    if end_date is None:
        end_date = date.today()
    if start_date is None:
        start_date = end_date - timedelta(days=30)

    engine = InsightsEngine(db)
    candidates = await engine.analyze_user_data(current_user.id, start_date, end_date)

    service = InsightService(db)
    for candidate in candidates:
        await service.create(
            user_id=current_user.id,
            type=candidate.type,
            severity=candidate.severity,
            title=candidate.title,
            description=candidate.description,
            explanation=candidate.explanation,
            confidence=candidate.confidence,
            source_data_refs=candidate.source_data_refs,
        )

    breakdown = Counter(c.type.value for c in candidates)
    return GenerationResult(
        insights_generated=len(candidates),
        types_breakdown=dict(breakdown),
    )
