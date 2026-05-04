from datetime import date
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
        # TODO: Implement Oura API data fetching
        # Fetch from /v2/usercollection/daily_sleep, /daily_activity, etc.
        # Normalize to NormalizedWearableData format
        return []
