from typing import Annotated, Optional
from uuid import UUID
from datetime import date, datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.api.deps import CurrentUser
from app.services.wearable import WearableService
from app.models.wearable import WearableProvider
from app.api.schemas.wearable import (
    WearableConnectionResponse,
    WearableAuthUrl,
    WearableCallback,
    WearableDataResponse,
    SyncResult,
    WearableProvider as WearableProviderSchema,
)

router = APIRouter()


@router.get("/connections", response_model=list[WearableConnectionResponse])
async def list_connections(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    List all wearable connections for the authenticated user.
    """
    service = WearableService(db)
    connections = await service.list_connections(current_user.id)
    return connections


@router.get("/connect/{provider}", response_model=WearableAuthUrl)
async def get_connect_url(
    provider: WearableProviderSchema,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    redirect_uri: str = Query(..., description="OAuth redirect URI"),
):
    """
    Get the OAuth authorization URL for a wearable provider.

    The client should redirect the user to this URL to authorize the connection.
    After authorization, the provider will redirect back to redirect_uri with a code.
    """
    if provider == WearableProviderSchema.APPLE_HEALTH:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Apple Health uses on-device sync, not OAuth",
        )

    service = WearableService(db)

    try:
        wearable_provider = WearableProvider(provider.value)
        auth_url = await service.get_auth_url(wearable_provider, redirect_uri)
        return WearableAuthUrl(auth_url=auth_url, provider=provider)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/callback/{provider}", response_model=WearableConnectionResponse)
async def oauth_callback(
    provider: WearableProviderSchema,
    callback: WearableCallback,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    redirect_uri: str = Query(..., description="OAuth redirect URI (must match original)"),
):
    """
    Complete the OAuth flow with the authorization code.

    This endpoint is called after the user authorizes with the wearable provider.
    It exchanges the code for access tokens and creates/updates the connection.
    """
    if provider == WearableProviderSchema.APPLE_HEALTH:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Apple Health uses on-device sync, not OAuth",
        )

    service = WearableService(db)

    try:
        wearable_provider = WearableProvider(provider.value)
        connection = await service.connect(
            user_id=current_user.id,
            provider=wearable_provider,
            code=callback.code,
            redirect_uri=redirect_uri,
        )
        return connection
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"OAuth failed: {str(e)}",
        )


@router.post("/connections/{connection_id}/sync", response_model=SyncResult)
async def sync_connection(
    connection_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: Optional[date] = Query(None, description="Sync from this date"),
    end_date: Optional[date] = Query(None, description="Sync until this date"),
):
    """
    Manually trigger a data sync for a wearable connection.

    By default, syncs the last 7 days. Use start_date and end_date
    to sync a specific range.
    """
    service = WearableService(db)
    connection = await service.get_connection(connection_id, current_user.id)

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Connection not found",
        )

    if not connection.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Connection is not active. Please reconnect.",
        )

    try:
        if not end_date:
            end_date = date.today()
        if not start_date:
            from datetime import timedelta
            start_date = end_date - timedelta(days=7)

        records_synced = await service.sync_data(
            connection,
            start_date=start_date,
            end_date=end_date,
        )

        return SyncResult(
            connection_id=connection.id,
            provider=WearableProviderSchema(connection.provider.value),
            records_synced=records_synced,
            sync_start_date=start_date,
            sync_end_date=end_date,
            last_sync_at=connection.last_sync_at or datetime.now(timezone.utc),
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Sync failed: {str(e)}",
        )


@router.delete("/connections/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
async def disconnect(
    connection_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    delete_data: bool = Query(False, description="Also delete synced data"),
):
    """
    Disconnect a wearable.

    By default, this deactivates the connection but preserves synced data.
    Set delete_data=true to also remove all synced data from this provider.
    """
    service = WearableService(db)
    connection = await service.get_connection(connection_id, current_user.id)

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Connection not found",
        )

    if delete_data:
        await service.delete_connection(connection)
    else:
        await service.disconnect(connection)


@router.get("/data", response_model=list[WearableDataResponse])
async def get_wearable_data(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: Optional[date] = Query(None, description="Filter from this date"),
    end_date: Optional[date] = Query(None, description="Filter until this date"),
    provider: Optional[WearableProviderSchema] = Query(None, description="Filter by provider"),
    limit: int = Query(100, ge=1, le=365, description="Maximum records to return"),
    offset: int = Query(0, ge=0, description="Number of records to skip"),
):
    """
    Get synced wearable data for the authenticated user.

    Data is ordered by date (most recent first).
    Filter by date range or specific provider.
    """
    service = WearableService(db)

    wearable_provider = None
    if provider:
        wearable_provider = WearableProvider(provider.value)

    data = await service.get_data(
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
        provider=wearable_provider,
        limit=limit,
        offset=offset,
    )
    return data


@router.get("/data/latest", response_model=Optional[WearableDataResponse])
async def get_latest_wearable_data(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    provider: Optional[WearableProviderSchema] = Query(None, description="Filter by provider"),
):
    """
    Get the most recent wearable data for the authenticated user.

    Optionally filter by provider to get the latest from a specific source.
    """
    service = WearableService(db)

    wearable_provider = None
    if provider:
        wearable_provider = WearableProvider(provider.value)

    data = await service.get_latest_data(
        user_id=current_user.id,
        provider=wearable_provider,
    )
    return data
