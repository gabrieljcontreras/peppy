from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.notification import DeviceToken, DevicePlatform


class NotificationService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_device_by_id(self, device_id: UUID, user_id: UUID) -> DeviceToken | None:
        result = await self.db.execute(
            select(DeviceToken).where(
                DeviceToken.id == device_id,
                DeviceToken.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def delete_device(self, device: DeviceToken) -> None:
        await self.db.delete(device)
        await self.db.commit()

    async def list_devices(self, user_id: UUID) -> list[DeviceToken]:
        result = await self.db.execute(
            select(DeviceToken).where(DeviceToken.user_id == user_id)
        )
        return list(result.scalars().all())

    async def get_device_by_token(self, user_id: UUID, token: str) -> DeviceToken | None:
        result = await self.db.execute(
            select(DeviceToken).where(
                DeviceToken.user_id == user_id,
                DeviceToken.token == token,
            )
        )
        return result.scalar_one_or_none()

    async def register_device(
        self,
        user_id: UUID,
        token: str,
        platform: DevicePlatform,
    ) -> DeviceToken:
        existing = await self.get_device_by_token(user_id, token)
        if existing:
            existing.platform = platform
            await self.db.commit()
            await self.db.refresh(existing)
            return existing

        device = DeviceToken(
            user_id=user_id,
            token=token,
            platform=platform,
        )
        self.db.add(device)
        await self.db.commit()
        await self.db.refresh(device)
        return device
