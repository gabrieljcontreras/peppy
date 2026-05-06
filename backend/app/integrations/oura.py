from datetime import date
from typing import Optional
import httpx
from app.integrations.base import WearableIntegration, NormalizedWearableData
from app.config import get_settings

settings = get_settings()

OURA_AUTH_URL = "https://cloud.ouraring.com/oauth/authorize"
OURA_TOKEN_URL = "https://api.ouraring.com/oauth/token"
OURA_API_BASE = "https://api.ouraring.com/v2"


class OuraIntegration(WearableIntegration):
    async def get_auth_url(self, redirect_uri: str) -> str:
        params = {
            "client_id": settings.oura_client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": "daily sleep activity heartrate",
        }
        query = "&".join(f"{k}={v}" for k, v in params.items())
        return f"{OURA_AUTH_URL}?{query}"

    async def exchange_code(self, code: str, redirect_uri: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                OURA_TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri,
                    "client_id": settings.oura_client_id,
                    "client_secret": settings.oura_client_secret,
                },
            )
            response.raise_for_status()
            return response.json()

    async def refresh_tokens(self, refresh_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                OURA_TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                    "client_id": settings.oura_client_id,
                    "client_secret": settings.oura_client_secret,
                },
            )
            response.raise_for_status()
            return response.json()

    async def fetch_data(
        self,
        access_token: str,
        start_date: date,
        end_date: date,
    ) -> list[NormalizedWearableData]:
        """
        Fetch data from Oura API v2 and normalize it.

        Fetches:
        - Daily sleep data (sleep hours, sleep quality)
        - Daily readiness (readiness score, HRV, resting HR)
        - Daily activity (steps, calories)
        """
        headers = {"Authorization": f"Bearer {access_token}"}

        async with httpx.AsyncClient() as client:
            sleep_data = await self._fetch_sleep(client, headers, start_date, end_date)
            readiness_data = await self._fetch_readiness(client, headers, start_date, end_date)
            activity_data = await self._fetch_activity(client, headers, start_date, end_date)

        return self._merge_data(sleep_data, readiness_data, activity_data, start_date, end_date)

    async def _fetch_sleep(
        self,
        client: httpx.AsyncClient,
        headers: dict,
        start_date: date,
        end_date: date,
    ) -> dict[date, dict]:
        """Fetch daily sleep data."""
        try:
            response = await client.get(
                f"{OURA_API_BASE}/usercollection/daily_sleep",
                headers=headers,
                params={
                    "start_date": start_date.isoformat(),
                    "end_date": end_date.isoformat(),
                },
            )
            response.raise_for_status()
            data = response.json()

            result = {}
            for item in data.get("data", []):
                day = date.fromisoformat(item["day"])
                result[day] = {
                    "sleep_score": item.get("score"),
                    "total_sleep_duration": item.get("contributors", {}).get("total_sleep"),
                }
            return result
        except Exception:
            return {}

    async def _fetch_readiness(
        self,
        client: httpx.AsyncClient,
        headers: dict,
        start_date: date,
        end_date: date,
    ) -> dict[date, dict]:
        """Fetch daily readiness data."""
        try:
            response = await client.get(
                f"{OURA_API_BASE}/usercollection/daily_readiness",
                headers=headers,
                params={
                    "start_date": start_date.isoformat(),
                    "end_date": end_date.isoformat(),
                },
            )
            response.raise_for_status()
            data = response.json()

            result = {}
            for item in data.get("data", []):
                day = date.fromisoformat(item["day"])
                result[day] = {
                    "readiness_score": item.get("score"),
                    "hrv_balance": item.get("contributors", {}).get("hrv_balance"),
                    "resting_heart_rate": item.get("contributors", {}).get("resting_heart_rate"),
                }
            return result
        except Exception:
            return {}

    async def _fetch_activity(
        self,
        client: httpx.AsyncClient,
        headers: dict,
        start_date: date,
        end_date: date,
    ) -> dict[date, dict]:
        """Fetch daily activity data."""
        try:
            response = await client.get(
                f"{OURA_API_BASE}/usercollection/daily_activity",
                headers=headers,
                params={
                    "start_date": start_date.isoformat(),
                    "end_date": end_date.isoformat(),
                },
            )
            response.raise_for_status()
            data = response.json()

            result = {}
            for item in data.get("data", []):
                day = date.fromisoformat(item["day"])
                result[day] = {
                    "steps": item.get("steps"),
                    "active_calories": item.get("active_calories"),
                }
            return result
        except Exception:
            return {}

    async def _fetch_heart_rate(
        self,
        client: httpx.AsyncClient,
        headers: dict,
        start_date: date,
        end_date: date,
    ) -> dict[date, dict]:
        """Fetch heart rate data for HRV and resting HR."""
        try:
            response = await client.get(
                f"{OURA_API_BASE}/usercollection/heartrate",
                headers=headers,
                params={
                    "start_date": start_date.isoformat(),
                    "end_date": end_date.isoformat(),
                },
            )
            response.raise_for_status()
            data = response.json()

            daily_hr = {}
            for item in data.get("data", []):
                timestamp = item.get("timestamp", "")
                if timestamp:
                    day = date.fromisoformat(timestamp[:10])
                    if day not in daily_hr:
                        daily_hr[day] = {"bpm_values": [], "source": item.get("source")}
                    daily_hr[day]["bpm_values"].append(item.get("bpm", 0))

            result = {}
            for day, hr_data in daily_hr.items():
                if hr_data["bpm_values"]:
                    result[day] = {
                        "resting_hr": min(hr_data["bpm_values"]),
                    }
            return result
        except Exception:
            return {}

    def _merge_data(
        self,
        sleep_data: dict[date, dict],
        readiness_data: dict[date, dict],
        activity_data: dict[date, dict],
        start_date: date,
        end_date: date,
    ) -> list[NormalizedWearableData]:
        """Merge all data sources into normalized format."""
        all_dates = set(sleep_data.keys()) | set(readiness_data.keys()) | set(activity_data.keys())

        result = []
        for day in sorted(all_dates):
            if start_date <= day <= end_date:
                sleep = sleep_data.get(day, {})
                readiness = readiness_data.get(day, {})
                activity = activity_data.get(day, {})

                sleep_hours = None
                if sleep.get("total_sleep_duration"):
                    sleep_hours = sleep["total_sleep_duration"] / 3600

                result.append(NormalizedWearableData(
                    date=day,
                    sleep_hours=sleep_hours,
                    sleep_quality_score=sleep.get("sleep_score"),
                    hrv_ms=readiness.get("hrv_balance"),
                    resting_hr=readiness.get("resting_heart_rate"),
                    steps=activity.get("steps"),
                    active_calories=activity.get("active_calories"),
                    readiness_score=readiness.get("readiness_score"),
                    raw_data={
                        "sleep": sleep,
                        "readiness": readiness,
                        "activity": activity,
                    },
                ))

        return result
