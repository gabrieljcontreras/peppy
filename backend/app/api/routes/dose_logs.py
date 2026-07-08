from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.api.schemas.dose_log import DoseLogCreate, DoseLogResponse
from app.database import get_db
from app.services.dose_log import DoseLogService
from app.services.protocol import ProtocolService

router = APIRouter()
protocol_router = APIRouter()


@router.post("", response_model=DoseLogResponse, status_code=status.HTTP_201_CREATED)
async def create_dose_log(
    payload: DoseLogCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> DoseLogResponse:
    protocol = await ProtocolService(db).get_by_id(payload.protocol_id, current_user.id)
    if protocol is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Protocol not found")

    try:
        return await DoseLogService(db).create(
            user_id=current_user.id,
            protocol_id=payload.protocol_id,
            compound_id=payload.compound_id,
            dose=payload.dose,
            unit=payload.unit,
            administered_at=payload.administered_at,
            route=payload.route,
            notes=payload.notes,
        )
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error


@protocol_router.get("/{protocol_id}/dose-logs", response_model=list[DoseLogResponse])
async def list_protocol_dose_logs(
    protocol_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[DoseLogResponse]:
    logs = await DoseLogService(db).list_for_protocol(
        user_id=current_user.id,
        protocol_id=protocol_id,
    )
    if logs is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Protocol not found")
    return logs
