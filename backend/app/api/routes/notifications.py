from typing import Annotated
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.api.deps import CurrentUser
from app.services.notification import NotificationService
from app.models.notification import DevicePlatform as DevicePlatformModel
from app.api.schemas.notification import (
    DeviceTokenCreate,
    DeviceTokenResponse,
    NotificationPreferenceResponse,
    NotificationPreferenceUpdate,
)

router = APIRouter()


@router.post("/devices", response_model=DeviceTokenResponse, status_code=status.HTTP_201_CREATED)
async def register_device(
    device: DeviceTokenCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Register a device token for push notifications."""
    service = NotificationService(db)
    platform = DevicePlatformModel(device.platform.value)
    token = await service.register_device(
        user_id=current_user.id,
        token=device.token,
        platform=platform,
    )
    return token


@router.get("/devices", response_model=list[DeviceTokenResponse])
async def list_devices(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """List all registered device tokens for the user."""
    service = NotificationService(db)
    return await service.list_devices(current_user.id)


@router.delete("/devices/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unregister_device(
    device_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Unregister a device token."""
    service = NotificationService(db)
    device = await service.get_device_by_id(device_id, current_user.id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device token not found",
        )
    await service.delete_device(device)


@router.get("/preferences", response_model=NotificationPreferenceResponse)
async def get_preferences(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get notification preferences for the current user."""
    service = NotificationService(db)
    return await service.get_or_create_preferences(current_user.id)


@router.patch("/preferences", response_model=NotificationPreferenceResponse)
async def update_preferences(
    updates: NotificationPreferenceUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Update notification preferences for the current user."""
    service = NotificationService(db)
    return await service.update_preferences(
        user_id=current_user.id,
        insights_enabled=updates.insights_enabled,
        alert_severity_only=updates.alert_severity_only,
        quiet_hours_start=updates.quiet_hours_start,
        quiet_hours_end=updates.quiet_hours_end,
    )
