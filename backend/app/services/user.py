from typing import Optional
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import DeviceToken
from app.models.user import User
from app.services.auth import hash_password, verify_password


class UserService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, user_id: UUID) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.email == email.lower()))
        return result.scalar_one_or_none()

    async def create(self, email: str, password: str, display_name: Optional[str] = None) -> User:
        user = User(
            email=email.lower(),
            hashed_password=hash_password(password),
            display_name=display_name,
        )
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        return user

    async def authenticate(self, email: str, password: str) -> Optional[User]:
        user = await self.get_by_email(email)
        if not user:
            return None
        if not verify_password(password, user.hashed_password):
            return None
        if not user.is_active:
            return None
        return user

    async def update(self, user: User, **kwargs) -> User:
        for key, value in kwargs.items():
            if hasattr(user, key):
                setattr(user, key, value)
        await self.db.commit()
        await self.db.refresh(user)
        return user

    async def change_password(
        self,
        user: User,
        current_password: str,
        new_password: str,
    ) -> None:
        if not verify_password(current_password, user.hashed_password):
            raise ValueError("Current password is incorrect")
        if verify_password(new_password, user.hashed_password):
            raise ValueError("New password must be different")

        user.hashed_password = hash_password(new_password)
        user.auth_version += 1
        await self.db.execute(
            delete(DeviceToken).where(DeviceToken.user_id == user.id)
        )
        await self.db.commit()

    async def deactivate(self, user: User) -> User:
        user.is_active = False
        await self.db.commit()
        await self.db.refresh(user)
        return user
