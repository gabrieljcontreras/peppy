from datetime import date, datetime
from typing import Optional
import httpx
from app.integrations.base import WearableIntegration, NormalizedWearableData
from app.config import get_settings

settings = get_settings()

WHOOP_AUTH_URL = "https://api.prod.whoop.com/oauth/oauth2/auth"
WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token"
WHOOP_API_BASE = "https://api.prod.whoop.com/developer/v1"


class WhoopIntegration(WearableIntegration):
    async def get_auth_url(self, redirect_uri: str) -> str:
        params = {
            "client_id": settings.whoop_client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": "read:recovery read:sleep read:workout read:cycles read:body_measurement",
        }
        query = "&".join(f"{k}={v}" for k, v in params.items())
        return f"{WHOOP_AUTH_URL}?{query}"

    async def exchange_code(self, code: str, redirect_uri: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                WHOOP_TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri,
                    "client_id": settings.whoop_client_id,
                    "client_secret": settings.whoop_client_secret,
                },
            )
            response.raise_for_status()
            return response.json()

    async def refresh_tokens(self, refresh_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                WHOOP_TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                    "client_id": settings.whoop_client_id,
                    "client_secret": settings.whoop_client_secret,
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
        Fetch data from Whoop API v1 and normalize it.

        Fetches:
        - Recovery data (recovery score, HRV, resting HR)
        - Sleep data (sleep hours, sleep quality)
        - Cycle/strain data (strain score, calories)
        """
        headers = {"Authorization": f"Bearer {access_token}"}

        async with httpx.AsyncClient() as client:
            recovery_data = await self._fetch_recovery(client, headers, start_date, end_date)
            sleep_data = await self._fetch_sleep(client, headers, start_date, end_date)
            cycle_data = await self._fetch_cycles(client, headers, start_date, end_date)

        return self._merge_data(recovery_data, sleep_data, cycle_data, start_date, end_date)

    async def _fetch_recovery(
        self,
        client: httpx.AsyncClient,
        headers: dict,
        start_date: date,
        end_date: date,
    ) -> dict[date, dict]:
        """Fetch recovery data."""
        try:
            response = await client.get(
                f"{WHOOP_API_BASE}/recovery",
                headers=headers,
                params={
                    "start": f"{start_date.isoformat()}T00:00:00.000Z",
                    "end": f"{end_date.isoformat()}T23:59:59.999Z",
                },
            )
            response.raise_for_status()
            data = response.json()

            result = {}
            for item in data.get("records", []):
                created = item.get("created_at", "")
                if created:
                    day = date.fromisoformat(created[:10])
                    score = item.get("score", {})
                    result[day] = {
                        "recovery_score": score.get("recovery_score"),
                        "hrv_rmssd_milli": score.get("hrv_rmssd_milli"),
                        "resting_heart_rate": score.get("resting_heart_rate"),
                    }
            return result
        except Exception:
            return {}

    async def _fetch_sleep(
        self,
        client: httpx.AsyncClient,
        headers: dict,
        start_date: date,
        end_date: date,
    ) -> dict[date, dict]:
        """Fetch sleep data."""
        try:
            response = await client.get(
                f"{WHOOP_API_BASE}/activity/sleep",
                headers=headers,
                params={
                    "start": f"{start_date.isoformat()}T00:00:00.000Z",
                    "end": f"{end_date.isoformat()}T23:59:59.999Z",
                },
            )
            response.raise_for_status()
            data = response.json()

            result = {}
            for item in data.get("records", []):
                end_time = item.get("end", "")
                if end_time:
                    day = date.fromisoformat(end_time[:10])
                    score = item.get("score", {})

                    total_sleep_ms = (
                        score.get("stage_summary", {}).get("total_light_sleep_time_milli", 0) +
                        score.get("stage_summary", {}).get("total_slow_wave_sleep_time_milli", 0) +
                        score.get("stage_summary", {}).get("total_rem_sleep_time_milli", 0)
                    )

                    result[day] = {
                        "sleep_hours": total_sleep_ms / 3600000 if total_sleep_ms else None,
                        "sleep_performance_percentage": score.get("sleep_performance_percentage"),
                        "sleep_efficiency_percentage": score.get("sleep_efficiency_percentage"),
                    }
            return result
        except Exception:
            return {}

    async def _fetch_cycles(
        self,
        client: httpx.AsyncClient,
        headers: dict,
        start_date: date,
        end_date: date,
    ) -> dict[date, dict]:
        """Fetch cycle/strain data."""
        try:
            response = await client.get(
                f"{WHOOP_API_BASE}/cycle",
                headers=headers,
                params={
                    "start": f"{start_date.isoformat()}T00:00:00.000Z",
                    "end": f"{end_date.isoformat()}T23:59:59.999Z",
                },
            )
            response.raise_for_status()
            data = response.json()

            result = {}
            for item in data.get("records", []):
                end_time = item.get("end", "")
                if end_time:
                    day = date.fromisoformat(end_time[:10])
                    score = item.get("score", {})
                    result[day] = {
                        "strain": score.get("strain"),
                        "kilojoule": score.get("kilojoule"),
                        "average_heart_rate": score.get("average_heart_rate"),
                    }
            return result
        except Exception:
            return {}

    def _merge_data(
        self,
        recovery_data: dict[date, dict],
        sleep_data: dict[date, dict],
        cycle_data: dict[date, dict],
        start_date: date,
        end_date: date,
    ) -> list[NormalizedWearableData]:
        """Merge all data sources into normalized format."""
        all_dates = set(recovery_data.keys()) | set(sleep_data.keys()) | set(cycle_data.keys())

        result = []
        for day in sorted(all_dates):
            if start_date <= day <= end_date:
                recovery = recovery_data.get(day, {})
                sleep = sleep_data.get(day, {})
                cycle = cycle_data.get(day, {})

                active_calories = None
                if cycle.get("kilojoule"):
                    active_calories = cycle["kilojoule"] * 0.239006

                strain_score = None
                if cycle.get("strain"):
                    strain_score = min(100, cycle["strain"] * 4.76)

                sleep_quality = None
                if sleep.get("sleep_performance_percentage"):
                    sleep_quality = sleep["sleep_performance_percentage"]

                result.append(NormalizedWearableData(
                    date=day,
                    sleep_hours=sleep.get("sleep_hours"),
                    sleep_quality_score=sleep_quality,
                    hrv_ms=recovery.get("hrv_rmssd_milli"),
                    resting_hr=recovery.get("resting_heart_rate"),
                    active_calories=active_calories,
                    recovery_score=recovery.get("recovery_score"),
                    strain_score=strain_score,
                    raw_data={
                        "recovery": recovery,
                        "sleep": sleep,
                        "cycle": cycle,
                    },
                ))

        return result
