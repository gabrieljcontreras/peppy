from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel


class DashboardProtocolSummary(BaseModel):
    id: Optional[UUID]
    status: str
    title: str
    compounds: list[str]
    start_date: Optional[date] = None


class DashboardTodayCheckin(BaseModel):
    logged: bool
    checkin_id: Optional[UUID] = None


class DashboardWeightPoint(BaseModel):
    date: date
    weight_kg: float


class DashboardResponseSnapshot(BaseModel):
    weight_trend: list[DashboardWeightPoint]
    latest_energy: Optional[int] = None
    latest_mood: Optional[int] = None


class DashboardInsightSummary(BaseModel):
    id: Optional[UUID] = None
    title: Optional[str] = None
    severity: Optional[str] = None
    empty_message: Optional[str] = None
    confidence: Optional[float] = None


class DashboardConnectedContext(BaseModel):
    healthkit_requested: Optional[bool] = None
    has_labs: bool = False
    has_wearables: bool = False


class DashboardActivityItem(BaseModel):
    type: str
    title: str
    subtitle: str
    timestamp: datetime
    protocol_id: Optional[UUID] = None
    checkin_id: Optional[UUID] = None


class DashboardSummary(BaseModel):
    generated_at: datetime
    profile_status: str
    protocol: DashboardProtocolSummary
    today_checkin: DashboardTodayCheckin
    response_snapshot: DashboardResponseSnapshot
    insight: DashboardInsightSummary
    connected_context: DashboardConnectedContext
    recent_activity: list[DashboardActivityItem] = []
