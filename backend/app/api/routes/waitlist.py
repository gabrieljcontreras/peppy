from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import re

from app.database import get_db
from app.models.waitlist import WaitlistEntry
from app.services.sms import send_sms

router = APIRouter()

PHONE_RE = re.compile(r"^\+?[1-9]\d{6,14}$")

WELCOME_SMS = "Welcome, you will be able to access peppy soon"


class WaitlistSignup(BaseModel):
    phone: str
    email: EmailStr | None = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        digits = re.sub(r"[\s\-().]+", "", v)
        if not PHONE_RE.match(digits):
            raise ValueError("Please enter a valid phone number.")
        return digits


class WaitlistResponse(BaseModel):
    message: str
    phone: str
    email: str | None = None


@router.post("", response_model=WaitlistResponse)
async def join_waitlist(
    body: WaitlistSignup,
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(WaitlistEntry).where(WaitlistEntry.phone == body.phone)
    )
    if existing.scalar_one_or_none():
        return WaitlistResponse(
            message="You're already on the list!",
            phone=body.phone,
            email=body.email,
        )

    entry = WaitlistEntry(phone=body.phone, email=body.email)
    db.add(entry)
    await db.commit()

    send_sms(body.phone, WELCOME_SMS)

    return WaitlistResponse(
        message="You're on the list! We'll be in touch.",
        phone=body.phone,
        email=body.email,
    )
