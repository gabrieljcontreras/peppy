from abc import ABC, abstractmethod
from datetime import date
from typing import Optional
from dataclasses import dataclass


@dataclass
class NormalizedWearableData:
    date: date
    sleep_hours: Optional[float] = None
    sleep_quality_score: Optional[float] = None  # 0-100
    hrv_ms: Optional[float] = None
    resting_hr: Optional[float] = None
    steps: Optional[float] = None
    active_calories: Optional[float] = None
    recovery_score: Optional[float] = None  # 0-100
    strain_score: Optional[float] = None  # 0-100
    readiness_score: Optional[float] = None  # 0-100
    raw_data: Optional[dict] = None


class WearableIntegration(ABC):
    @abstractmethod
    async def get_auth_url(self, redirect_uri: str) -> str:
        pass

    @abstractmethod
    async def exchange_code(self, code: str, redirect_uri: str) -> dict:
        pass

    @abstractmethod
    async def refresh_tokens(self, refresh_token: str) -> dict:
        pass

    @abstractmethod
    async def fetch_data(
        self,
        access_token: str,
        start_date: date,
        end_date: date,
    ) -> list[NormalizedWearableData]:
        pass
