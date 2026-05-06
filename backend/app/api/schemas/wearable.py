from uuid import UUID
from datetime import date as date_type, datetime
from typing import Optional
from pydantic import BaseModel, Field
from enum import Enum


class WearableProvider(str, Enum):
    OURA = "oura"
    WHOOP = "whoop"
    APPLE_HEALTH = "apple_health"


class WearableConnectionResponse(BaseModel):
    """Schema for wearable connection in API responses."""
    id: UUID
    provider: WearableProvider
    is_active: bool
    last_sync_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


class WearableAuthUrl(BaseModel):
    """OAuth authorization URL response."""
    auth_url: str
    provider: WearableProvider


class WearableCallback(BaseModel):
    """OAuth callback request."""
    code: str
    state: Optional[str] = None


class WearableDataResponse(BaseModel):
    """Schema for wearable data in API responses."""
    id: UUID
    provider: WearableProvider
    date: date_type
    sleep_hours: Optional[float]
    sleep_quality_score: Optional[float]
    hrv_ms: Optional[float]
    resting_hr: Optional[float]
    steps: Optional[float]
    active_calories: Optional[float]
    recovery_score: Optional[float]
    strain_score: Optional[float]
    readiness_score: Optional[float]
    created_at: datetime

    class Config:
        from_attributes = True


class WearableDataSummary(BaseModel):
    """Aggregated wearable data summary."""
    date: date_type
    avg_sleep_hours: Optional[float]
    avg_hrv_ms: Optional[float]
    avg_resting_hr: Optional[float]
    total_steps: Optional[float]
    avg_recovery_score: Optional[float]
    avg_readiness_score: Optional[float]
    sources: list[WearableProvider]


class SyncResult(BaseModel):
    """Result of a wearable sync operation."""
    connection_id: UUID
    provider: WearableProvider
    records_synced: int
    sync_start_date: date_type
    sync_end_date: date_type
    last_sync_at: datetime
