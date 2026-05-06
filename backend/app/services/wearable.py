from uuid import UUID
from datetime import date, datetime, timedelta, timezone
from typing import Optional, Sequence
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.wearable import WearableConnection, WearableData, WearableProvider
from app.integrations.base import NormalizedWearableData
from app.integrations.oura import OuraIntegration
from app.integrations.whoop import WhoopIntegration


class WearableService:
    """
    Service for managing wearable connections and syncing data.
    """

    def __init__(self, db: AsyncSession):
        self.db = db
        self._integrations = {
            WearableProvider.OURA: OuraIntegration(),
            WearableProvider.WHOOP: WhoopIntegration(),
        }

    def _get_integration(self, provider: WearableProvider):
        integration = self._integrations.get(provider)
        if not integration:
            raise ValueError(f"Provider {provider} not supported")
        return integration

    async def get_connection(
        self,
        connection_id: UUID,
        user_id: UUID,
    ) -> Optional[WearableConnection]:
        """Get a wearable connection by ID for a user."""
        result = await self.db.execute(
            select(WearableConnection).where(
                and_(
                    WearableConnection.id == connection_id,
                    WearableConnection.user_id == user_id,
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_connection_by_provider(
        self,
        user_id: UUID,
        provider: WearableProvider,
    ) -> Optional[WearableConnection]:
        """Get a user's connection for a specific provider."""
        result = await self.db.execute(
            select(WearableConnection).where(
                and_(
                    WearableConnection.user_id == user_id,
                    WearableConnection.provider == provider,
                )
            )
        )
        return result.scalar_one_or_none()

    async def list_connections(self, user_id: UUID) -> Sequence[WearableConnection]:
        """List all wearable connections for a user."""
        result = await self.db.execute(
            select(WearableConnection)
            .where(WearableConnection.user_id == user_id)
            .order_by(WearableConnection.created_at.desc())
        )
        return result.scalars().all()

    async def get_auth_url(
        self,
        provider: WearableProvider,
        redirect_uri: str,
    ) -> str:
        """Get OAuth authorization URL for a provider."""
        integration = self._get_integration(provider)
        return await integration.get_auth_url(redirect_uri)

    async def connect(
        self,
        user_id: UUID,
        provider: WearableProvider,
        code: str,
        redirect_uri: str,
    ) -> WearableConnection:
        """
        Complete OAuth flow and create/update wearable connection.
        """
        integration = self._get_integration(provider)
        tokens = await integration.exchange_code(code, redirect_uri)

        existing = await self.get_connection_by_provider(user_id, provider)

        if existing:
            existing.access_token = tokens.get("access_token")
            existing.refresh_token = tokens.get("refresh_token")
            existing.is_active = True
            if "expires_in" in tokens:
                existing.token_expires_at = datetime.now(timezone.utc) + timedelta(
                    seconds=tokens["expires_in"]
                )
            await self.db.commit()
            await self.db.refresh(existing)
            return existing

        connection = WearableConnection(
            user_id=user_id,
            provider=provider,
            access_token=tokens.get("access_token"),
            refresh_token=tokens.get("refresh_token"),
            is_active=True,
        )
        if "expires_in" in tokens:
            connection.token_expires_at = datetime.now(timezone.utc) + timedelta(
                seconds=tokens["expires_in"]
            )

        self.db.add(connection)
        await self.db.commit()
        await self.db.refresh(connection)
        return connection

    async def disconnect(self, connection: WearableConnection) -> None:
        """Deactivate a wearable connection."""
        connection.is_active = False
        connection.access_token = None
        connection.refresh_token = None
        await self.db.commit()

    async def delete_connection(self, connection: WearableConnection) -> None:
        """Permanently delete a wearable connection and its data."""
        await self.db.execute(
            WearableData.__table__.delete().where(
                and_(
                    WearableData.user_id == connection.user_id,
                    WearableData.provider == connection.provider,
                )
            )
        )
        await self.db.delete(connection)
        await self.db.commit()

    async def refresh_tokens_if_needed(
        self,
        connection: WearableConnection,
    ) -> WearableConnection:
        """Refresh OAuth tokens if they're expired or about to expire."""
        if not connection.token_expires_at:
            return connection

        buffer = timedelta(minutes=5)
        now = datetime.now(timezone.utc)
        expires_at = connection.token_expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at > now + buffer:
            return connection

        if not connection.refresh_token:
            raise ValueError("No refresh token available")

        integration = self._get_integration(connection.provider)
        tokens = await integration.refresh_tokens(connection.refresh_token)

        connection.access_token = tokens.get("access_token")
        if "refresh_token" in tokens:
            connection.refresh_token = tokens["refresh_token"]
        if "expires_in" in tokens:
            connection.token_expires_at = datetime.now(timezone.utc) + timedelta(
                seconds=tokens["expires_in"]
            )

        await self.db.commit()
        await self.db.refresh(connection)
        return connection

    async def sync_data(
        self,
        connection: WearableConnection,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
    ) -> int:
        """
        Sync wearable data for a connection.
        Returns the number of records synced.
        """
        if not connection.is_active:
            raise ValueError("Connection is not active")

        connection = await self.refresh_tokens_if_needed(connection)

        if not connection.access_token:
            raise ValueError("No access token available")

        if not end_date:
            end_date = date.today()
        if not start_date:
            start_date = end_date - timedelta(days=7)

        integration = self._get_integration(connection.provider)
        data = await integration.fetch_data(
            connection.access_token,
            start_date,
            end_date,
        )

        records_synced = 0
        for item in data:
            await self._upsert_wearable_data(connection, item)
            records_synced += 1

        connection.last_sync_at = datetime.now(timezone.utc)
        await self.db.commit()

        return records_synced

    async def _upsert_wearable_data(
        self,
        connection: WearableConnection,
        data: NormalizedWearableData,
    ) -> WearableData:
        """Insert or update wearable data for a specific date."""
        result = await self.db.execute(
            select(WearableData).where(
                and_(
                    WearableData.user_id == connection.user_id,
                    WearableData.provider == connection.provider,
                    WearableData.date == data.date,
                )
            )
        )
        existing = result.scalar_one_or_none()

        if existing:
            existing.sleep_hours = data.sleep_hours
            existing.sleep_quality_score = data.sleep_quality_score
            existing.hrv_ms = data.hrv_ms
            existing.resting_hr = data.resting_hr
            existing.steps = data.steps
            existing.active_calories = data.active_calories
            existing.recovery_score = data.recovery_score
            existing.strain_score = data.strain_score
            existing.readiness_score = data.readiness_score
            if data.raw_data:
                import json
                existing.raw_data = json.dumps(data.raw_data)
            return existing

        import json
        wearable_data = WearableData(
            user_id=connection.user_id,
            provider=connection.provider,
            date=data.date,
            sleep_hours=data.sleep_hours,
            sleep_quality_score=data.sleep_quality_score,
            hrv_ms=data.hrv_ms,
            resting_hr=data.resting_hr,
            steps=data.steps,
            active_calories=data.active_calories,
            recovery_score=data.recovery_score,
            strain_score=data.strain_score,
            readiness_score=data.readiness_score,
            raw_data=json.dumps(data.raw_data) if data.raw_data else None,
        )
        self.db.add(wearable_data)
        return wearable_data

    async def get_data(
        self,
        user_id: UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        provider: Optional[WearableProvider] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> Sequence[WearableData]:
        """Get wearable data for a user with optional filters."""
        query = select(WearableData).where(WearableData.user_id == user_id)

        if start_date:
            query = query.where(WearableData.date >= start_date)
        if end_date:
            query = query.where(WearableData.date <= end_date)
        if provider:
            query = query.where(WearableData.provider == provider)

        query = query.order_by(WearableData.date.desc()).offset(offset).limit(limit)

        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_latest_data(
        self,
        user_id: UUID,
        provider: Optional[WearableProvider] = None,
    ) -> Optional[WearableData]:
        """Get the most recent wearable data for a user."""
        query = select(WearableData).where(WearableData.user_id == user_id)

        if provider:
            query = query.where(WearableData.provider == provider)

        query = query.order_by(WearableData.date.desc()).limit(1)

        result = await self.db.execute(query)
        return result.scalar_one_or_none()
