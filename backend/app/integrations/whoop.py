from datetime import date
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
        # TODO: Implement Whoop API data fetching
        # Fetch from /v1/recovery, /v1/sleep, /v1/cycle, etc.
        # Normalize to NormalizedWearableData format
        return []
