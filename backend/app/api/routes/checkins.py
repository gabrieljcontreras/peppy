from typing import Annotated, Optional
from uuid import UUID
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.api.deps import CurrentUser
from app.services.checkin import CheckinService
from app.api.schemas.checkin import (
    CheckinCreate,
    CheckinUpdate,
    CheckinResponse,
    CheckinStats,
    WeightTrendPoint,
)

router = APIRouter()


@router.get("/", response_model=list[CheckinResponse])
async def list_checkins(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: Optional[date] = Query(None, description="Filter from this date"),
    end_date: Optional[date] = Query(None, description="Filter until this date"),
    limit: int = Query(100, ge=1, le=365, description="Maximum check-ins to return"),
    offset: int = Query(0, ge=0, description="Number of check-ins to skip"),
):
    """
    List check-ins for the authenticated user.

    Returns check-ins ordered by date (most recent first).
    Use start_date and end_date to filter by date range.
    """
    service = CheckinService(db)
    checkins = await service.list_for_user(
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
        limit=limit,
        offset=offset,
    )
    return checkins


@router.post("/", response_model=CheckinResponse, status_code=status.HTTP_201_CREATED)
async def create_checkin(
    checkin_data: CheckinCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Create a new check-in.

    Only one check-in per day is allowed. If a check-in already exists
    for the specified date, use PUT to update it instead.
    """
    service = CheckinService(db)

    try:
        checkin = await service.create(
            user_id=current_user.id,
            checkin_date=checkin_data.date,
            weight_kg=checkin_data.weight_kg,
            energy_level=checkin_data.energy_level,
            sleep_quality=checkin_data.sleep_quality,
            appetite_level=checkin_data.appetite_level,
            mood=checkin_data.mood,
            nausea=checkin_data.nausea,
            injection_site_reaction=checkin_data.injection_site_reaction,
            fatigue=checkin_data.fatigue,
            headache=checkin_data.headache,
            gi_issues=checkin_data.gi_issues,
            notes=checkin_data.notes,
        )
        return checkin
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )


@router.get("/today", response_model=Optional[CheckinResponse])
async def get_today_checkin(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Get today's check-in if it exists.

    Returns null if no check-in has been recorded today.
    """
    service = CheckinService(db)
    checkin = await service.get_today(current_user.id)
    return checkin


@router.get("/stats", response_model=CheckinStats)
async def get_checkin_stats(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: Optional[date] = Query(None, description="Stats from this date"),
    end_date: Optional[date] = Query(None, description="Stats until this date"),
):
    """
    Get aggregated statistics over a date range.

    Returns averages for weight, energy, sleep quality, and mood.
    """
    service = CheckinService(db)
    stats = await service.get_stats(
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
    )
    return CheckinStats(
        total_checkins=stats["total_checkins"],
        avg_weight_kg=stats["avg_weight_kg"],
        avg_energy=stats["avg_energy"],
        avg_sleep_quality=stats["avg_sleep_quality"],
        avg_mood=stats["avg_mood"],
        common_symptoms=[],
    )


@router.get("/weight-trend", response_model=list[WeightTrendPoint])
async def get_weight_trend(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: Optional[date] = Query(None, description="Trend from this date"),
    end_date: Optional[date] = Query(None, description="Trend until this date"),
):
    """
    Get weight measurements over time for trend visualization.

    Returns date/weight pairs ordered chronologically.
    Only includes check-ins where weight was recorded.
    """
    service = CheckinService(db)
    trend = await service.get_weight_trend(
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
    )
    return [WeightTrendPoint(date=d, weight_kg=w) for d, w in trend]


@router.get("/{checkin_id}", response_model=CheckinResponse)
async def get_checkin(
    checkin_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Get a specific check-in by ID.

    Only returns check-ins owned by the authenticated user.
    """
    service = CheckinService(db)
    checkin = await service.get_by_id(checkin_id, current_user.id)

    if not checkin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Check-in not found",
        )

    return checkin


@router.patch("/{checkin_id}", response_model=CheckinResponse)
async def update_checkin(
    checkin_id: UUID,
    update_data: CheckinUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Update an existing check-in.

    All fields are optional - only provided fields will be updated.
    """
    service = CheckinService(db)
    checkin = await service.get_by_id(checkin_id, current_user.id)

    if not checkin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Check-in not found",
        )

    try:
        updated = await service.update(
            checkin,
            checkin_date=update_data.date,
            weight_kg=update_data.weight_kg,
            energy_level=update_data.energy_level,
            sleep_quality=update_data.sleep_quality,
            appetite_level=update_data.appetite_level,
            mood=update_data.mood,
            nausea=update_data.nausea,
            injection_site_reaction=update_data.injection_site_reaction,
            fatigue=update_data.fatigue,
            headache=update_data.headache,
            gi_issues=update_data.gi_issues,
            notes=update_data.notes,
        )
        return updated
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )


@router.delete("/{checkin_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_checkin(
    checkin_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Delete a check-in.

    This action cannot be undone.
    """
    service = CheckinService(db)
    checkin = await service.get_by_id(checkin_id, current_user.id)

    if not checkin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Check-in not found",
        )

    await service.delete(checkin)
