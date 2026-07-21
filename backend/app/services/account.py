from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.wearable import WearableData
from app.models.weekly_summary import WeeklySummary
from app.services.auth import verify_password


class AccountService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def delete_account(self, user: User, current_password: str) -> None:
        if not verify_password(current_password, user.hashed_password):
            raise ValueError("Current password is incorrect")

        try:
            await self.db.execute(delete(WeeklySummary).where(WeeklySummary.user_id == user.id))
            await self.db.execute(delete(WearableData).where(WearableData.user_id == user.id))
            await self.db.delete(user)
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise
