from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, date
from uuid import UUID

router = APIRouter()


class CheckinCreate(BaseModel):
    date: date
    weight_kg: Optional[float] = None
    energy_level: Optional[int] = None  # 1-10 scale
    sleep_quality: Optional[int] = None  # 1-10 scale
    appetite_level: Optional[int] = None  # 1-10 scale
    nausea: Optional[int] = None  # 0-10 scale
    injection_site_reaction: Optional[int] = None  # 0-10 scale
    mood: Optional[int] = None  # 1-10 scale
    notes: Optional[str] = None


class CheckinResponse(BaseModel):
    id: UUID
    date: date
    weight_kg: Optional[float]
    energy_level: Optional[int]
    sleep_quality: Optional[int]
    appetite_level: Optional[int]
    nausea: Optional[int]
    injection_site_reaction: Optional[int]
    mood: Optional[int]
    notes: Optional[str]
    created_at: datetime


@router.get("/", response_model=list[CheckinResponse])
async def list_checkins(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
):
    # TODO: Return user's check-ins with optional date filtering
    raise HTTPException(status_code=501, detail="Not implemented")


@router.post("/", response_model=CheckinResponse, status_code=status.HTTP_201_CREATED)
async def create_checkin(checkin: CheckinCreate):
    # TODO: Create a new check-in
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/today", response_model=Optional[CheckinResponse])
async def get_today_checkin():
    # TODO: Get today's check-in if exists
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/{checkin_id}", response_model=CheckinResponse)
async def get_checkin(checkin_id: UUID):
    # TODO: Get specific check-in
    raise HTTPException(status_code=501, detail="Not implemented")


@router.put("/{checkin_id}", response_model=CheckinResponse)
async def update_checkin(checkin_id: UUID, checkin: CheckinCreate):
    # TODO: Update check-in
    raise HTTPException(status_code=501, detail="Not implemented")


@router.delete("/{checkin_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_checkin(checkin_id: UUID):
    # TODO: Delete check-in
    raise HTTPException(status_code=501, detail="Not implemented")
