from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.waitlist import WaitlistEntry

router = APIRouter()


class WaitlistSignup(BaseModel):
    email: EmailStr


class WaitlistResponse(BaseModel):
    message: str
    email: str


@router.post("", response_model=WaitlistResponse)
async def join_waitlist(
    body: WaitlistSignup,
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(WaitlistEntry).where(WaitlistEntry.email == body.email)
    )
    if existing.scalar_one_or_none():
        return WaitlistResponse(
            message="You're already on the list!",
            email=body.email,
        )

    entry = WaitlistEntry(email=body.email)
    db.add(entry)
    await db.commit()

    return WaitlistResponse(
        message="You're on the list! We'll be in touch.",
        email=body.email,
    )
