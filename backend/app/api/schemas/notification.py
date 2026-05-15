from uuid import UUID
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from enum import Enum


class DevicePlatform(str, Enum):
    IOS = "ios"
    ANDROID = "android"


class DeviceTokenCreate(BaseModel):
    token: str = Field(..., min_length=1, max_length=512)
    platform: DevicePlatform


class DeviceTokenResponse(BaseModel):
    id: UUID
    token: str
    platform: DevicePlatform
    last_used_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True
