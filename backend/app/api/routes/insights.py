from datetime import date, timedelta
from typing import Annotated, Optional, Union
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.api.schemas.insight import (
    GenerationResult,
    InsightAction,
    InsightResponse,
    InsightSeverity,
    InsightType,
    JobResponse,
    WeeklySummaryEnvelope,
)
from app.database import get_db
from app.ml.narrator import Narrator
from app.models.insight import (
    InsightSeverity as ModelInsightSeverity,
)
from app.models.insight import (
    InsightType as ModelInsightType,
)
from app.services.insight import InsightService
from app.services.insight_generation import (
    is_stale,
    run_generation,
    run_generation_in_background,
)
from app.services.job import JobService
from app.services.weekly_summary import get_or_create_weekly_summary

router = APIRouter()


@router.get("", response_model=list[InsightResponse])
async def list_insights(
    current_user: CurrentUser,
    background_tasks: BackgroundTasks,
    db: Annotated[AsyncSession, Depends(get_db)],
    unread_only: bool = Query(False, description="Only return insights the user has not read"),
    type: Optional[InsightType] = Query(None, description="Filter by insight type"),
    severity: Optional[InsightSeverity] = Query(None, description="Filter by severity"),
    include_dismissed: bool = Query(
        False, description="Include dismissed insights (excluded by default)"
    ),
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
        include_dismissed=include_dismissed,
        limit=limit,
        offset=offset,
    )
    if not await service.has_any_for_user(current_user.id):
        await run_generation(db, current_user.id)
        insights = await service.list_for_user(
            user_id=current_user.id,
            unread_only=unread_only,
            type=ModelInsightType(type.value) if type else None,
            severity=ModelInsightSeverity(severity.value) if severity else None,
            include_dismissed=include_dismissed,
            limit=limit,
            offset=offset,
        )
    elif is_stale(current_user):
        background_tasks.add_task(
            run_generation_in_background,
            current_user.id,
        )
    return insights


@router.get("/summary/weekly", response_model=WeeklySummaryEnvelope)
async def get_weekly_summary(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Return the latest qualifying completed-week summary."""
    payload = await get_or_create_weekly_summary(
        db,
        current_user.id,
        narrator=Narrator(),
    )
    if payload is None:
        return WeeklySummaryEnvelope(available=False)
    return WeeklySummaryEnvelope(available=True, summary=payload)


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


@router.get("/jobs/{job_id}", response_model=JobResponse)
async def get_job_status(
    job_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Get the status of an async insight generation job.
    """
    import json as json_module

    job_service = JobService(db)
    job = await job_service.get_by_id(job_id, current_user.id)

    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Job not found",
        )

    result = None
    if job.result:
        result = json_module.loads(job.result)

    return JobResponse(
        job_id=job.id,
        status=job.status.value,
        result=result,
        error=job.error,
    )


@router.post("/generate", response_model=Union[GenerationResult, JobResponse])
async def trigger_insight_generation(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    response: Response,
    start_date: Optional[date] = Query(
        None, description="Analyze data from this date (default: today - 30 days)"
    ),
    end_date: Optional[date] = Query(
        None, description="Analyze data up to this date (default: today)"
    ),
    run_async: bool = Query(False, description="Run generation asynchronously (returns job_id)"),
):
    """
    Run the insights engine over the user's data and persist any
    generated insights. Returns a count and a breakdown by type.

    Defaults to the last 30 days when no date range is provided.

    With run_async=true, returns 202 Accepted with a job_id for polling.
    """
    if end_date is None:
        end_date = date.today()
    if start_date is None:
        start_date = end_date - timedelta(days=30)

    if run_async:
        job_service = JobService(db)
        job = await job_service.create(user_id=current_user.id, job_type="insight_generation")
        response.status_code = status.HTTP_202_ACCEPTED
        return JobResponse(job_id=job.id, status=job.status.value)

    result = await run_generation(
        db,
        current_user.id,
        start_date=start_date,
        end_date=end_date,
    )
    return GenerationResult(**result)
