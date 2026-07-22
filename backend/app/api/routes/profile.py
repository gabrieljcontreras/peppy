from collections.abc import Iterator
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.api.schemas.export import DataExportRequest
from app.api.schemas.profile import (
    OnboardingProfileAttachRequest,
    OnboardingProfilePayload,
    OnboardingProfileResponse,
)
from app.database import get_db
from app.services.export import ExportService
from app.services.profile import OnboardingProfileService

router = APIRouter()


@router.post("/export")
async def export_profile_data(
    request: DataExportRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> StreamingResponse:
    generated = await ExportService(db).generate(current_user, request)

    def stream_chunks() -> Iterator[bytes]:
        try:
            while chunk := generated.stream.read(64 * 1024):
                yield chunk
        finally:
            generated.stream.close()

    return StreamingResponse(
        stream_chunks(),
        media_type=generated.media_type,
        headers={
            "Content-Disposition": f'attachment; filename="{generated.filename}"',
            "Cache-Control": "no-store",
        },
    )


@router.get("/onboarding", response_model=OnboardingProfileResponse)
async def get_onboarding_profile(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = OnboardingProfileService(db)
    profile = await service.get_for_user(current_user.id)
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Onboarding profile not found",
        )
    return service.to_payload(profile)


@router.put("/onboarding", response_model=OnboardingProfileResponse)
async def put_onboarding_profile(
    payload: OnboardingProfilePayload,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = OnboardingProfileService(db)
    try:
        profile = await service.put_profile(current_user.id, payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    return service.to_payload(profile)


@router.patch("/onboarding", response_model=OnboardingProfileResponse)
async def patch_onboarding_profile(
    patch: OnboardingProfilePayload,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = OnboardingProfileService(db)
    try:
        profile = await service.patch_profile(current_user.id, patch)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    return service.to_payload(profile)


@router.post(
    "/onboarding/attach",
    response_model=OnboardingProfileResponse,
    status_code=status.HTTP_201_CREATED,
)
async def attach_onboarding_profile(
    request: OnboardingProfileAttachRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = OnboardingProfileService(db)
    try:
        profile = await service.attach_profile(
            user_id=current_user.id,
            draft_id=request.draft_id,
            draft_created_at=request.draft_created_at,
            draft_updated_at=request.draft_updated_at,
            is_complete=request.is_complete,
            current_step=request.current_step,
            profile_payload=request.profile,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    return service.to_payload(profile)
