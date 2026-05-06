from typing import Annotated, Optional
from uuid import UUID
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.api.deps import CurrentUser
from app.services.lab import LabService
from app.api.schemas.lab import (
    LabResultCreate,
    LabResultUpdate,
    LabResultResponse,
    LabMarkersUpdate,
    MarkerHistoryResponse,
    MarkerHistoryPoint,
)

router = APIRouter()


@router.get("/", response_model=list[LabResultResponse])
async def list_lab_results(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: Optional[date] = Query(None, description="Filter from this date"),
    end_date: Optional[date] = Query(None, description="Filter until this date"),
    panel_type: Optional[str] = Query(None, description="Filter by panel type"),
    limit: int = Query(100, ge=1, le=365, description="Maximum results to return"),
    offset: int = Query(0, ge=0, description="Number of results to skip"),
):
    """
    List lab results for the authenticated user.

    Returns results ordered by date (most recent first).
    Filter by date range or panel type.
    """
    service = LabService(db)
    results = await service.list_for_user(
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
        panel_type=panel_type,
        limit=limit,
        offset=offset,
    )
    return results


@router.post("/", response_model=LabResultResponse, status_code=status.HTTP_201_CREATED)
async def create_lab_result(
    lab_data: LabResultCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Create a new lab result with markers.

    At least one marker is required. Each marker needs:
    - name: The marker name (e.g., "HbA1c", "fasting_glucose")
    - value: The measured value
    - unit: Unit of measurement (e.g., "mg/dL", "%")
    """
    service = LabService(db)

    try:
        markers_data = [m.model_dump() for m in lab_data.markers]
        result = await service.create(
            user_id=current_user.id,
            lab_date=lab_data.date,
            panel_type=lab_data.panel_type,
            markers=markers_data,
            lab_name=lab_data.lab_name,
            notes=lab_data.notes,
        )
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get("/markers", response_model=list[str])
async def list_marker_names(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Get all unique marker names the user has recorded.

    Useful for autocomplete and marker history lookup.
    """
    service = LabService(db)
    return await service.get_distinct_marker_names(current_user.id)


@router.get("/markers/{marker_name}", response_model=MarkerHistoryResponse)
async def get_marker_history(
    marker_name: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: Optional[date] = Query(None, description="History from this date"),
    end_date: Optional[date] = Query(None, description="History until this date"),
):
    """
    Get the history of a specific marker across all lab results.

    Returns chronological list of all measurements for this marker.
    """
    service = LabService(db)
    history = await service.get_marker_history(
        user_id=current_user.id,
        marker_name=marker_name,
        start_date=start_date,
        end_date=end_date,
    )

    return MarkerHistoryResponse(
        marker_name=marker_name,
        history=[
            MarkerHistoryPoint(
                date=h["date"],
                value=h["value"],
                unit=h["unit"],
                reference_low=h["reference_low"],
                reference_high=h["reference_high"],
            )
            for h in history
        ],
    )


@router.get("/{lab_id}", response_model=LabResultResponse)
async def get_lab_result(
    lab_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Get a specific lab result by ID.

    Only returns results owned by the authenticated user.
    """
    service = LabService(db)
    result = await service.get_by_id(lab_id, current_user.id)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lab result not found",
        )

    return result


@router.patch("/{lab_id}", response_model=LabResultResponse)
async def update_lab_result(
    lab_id: UUID,
    update_data: LabResultUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Update lab result metadata (date, panel type, lab name, notes).

    To update markers, use PUT /{lab_id}/markers.
    """
    service = LabService(db)
    result = await service.get_by_id(lab_id, current_user.id)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lab result not found",
        )

    updated = await service.update(
        result,
        lab_date=update_data.date,
        panel_type=update_data.panel_type,
        lab_name=update_data.lab_name,
        notes=update_data.notes,
    )
    return updated


@router.put("/{lab_id}/markers", response_model=LabResultResponse)
async def replace_markers(
    lab_id: UUID,
    markers_data: LabMarkersUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Replace all markers in a lab result.

    This is a full replacement - existing markers are removed
    and replaced with the new list.
    """
    service = LabService(db)
    result = await service.get_by_id(lab_id, current_user.id)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lab result not found",
        )

    try:
        markers_list = [m.model_dump() for m in markers_data.markers]
        updated = await service.update_markers(result, markers_list)
        return updated
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.delete("/{lab_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_lab_result(
    lab_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Delete a lab result and all its markers.

    This action cannot be undone.
    """
    service = LabService(db)
    result = await service.get_by_id(lab_id, current_user.id)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lab result not found",
        )

    await service.delete(result)
