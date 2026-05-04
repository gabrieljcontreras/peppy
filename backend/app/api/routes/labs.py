from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, date
from uuid import UUID

router = APIRouter()


class LabMarker(BaseModel):
    name: str  # e.g., "HbA1c", "fasting_glucose", "ALT", "AST"
    value: float
    unit: str
    reference_low: Optional[float] = None
    reference_high: Optional[float] = None


class LabResultCreate(BaseModel):
    date: date
    panel_type: str  # e.g., "metabolic", "lipid", "hormone", "liver", "kidney"
    markers: list[LabMarker]
    lab_name: Optional[str] = None
    notes: Optional[str] = None


class LabResultResponse(BaseModel):
    id: UUID
    date: date
    panel_type: str
    markers: list[LabMarker]
    lab_name: Optional[str]
    notes: Optional[str]
    created_at: datetime


@router.get("/", response_model=list[LabResultResponse])
async def list_lab_results(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    panel_type: Optional[str] = None,
):
    # TODO: Return user's lab results with filtering
    raise HTTPException(status_code=501, detail="Not implemented")


@router.post("/", response_model=LabResultResponse, status_code=status.HTTP_201_CREATED)
async def create_lab_result(lab: LabResultCreate):
    # TODO: Create a new lab result
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/{lab_id}", response_model=LabResultResponse)
async def get_lab_result(lab_id: UUID):
    # TODO: Get specific lab result
    raise HTTPException(status_code=501, detail="Not implemented")


@router.put("/{lab_id}", response_model=LabResultResponse)
async def update_lab_result(lab_id: UUID, lab: LabResultCreate):
    # TODO: Update lab result
    raise HTTPException(status_code=501, detail="Not implemented")


@router.delete("/{lab_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_lab_result(lab_id: UUID):
    # TODO: Delete lab result
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/markers/{marker_name}", response_model=list[dict])
async def get_marker_history(marker_name: str):
    # TODO: Get history of a specific marker across all lab results
    raise HTTPException(status_code=501, detail="Not implemented")
