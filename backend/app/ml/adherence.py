from datetime import date
from typing import Optional
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.protocol import Compound, Protocol

_RATES = {
    "daily": 1.0,
    "everyotherday": 0.5,
    "twiceweekly": 2 / 7,
    "weekly": 1 / 7,
    "onceweekly": 1 / 7,
    "every10days": 0.1,
    "biweekly": 1 / 14,
    "monthly": 1 / 30,
}


def doses_per_day(frequency: str) -> Optional[float]:
    key = "".join(ch for ch in frequency.lower() if ch.isalnum())
    return _RATES.get(key)


async def expected_doses(
    db: AsyncSession,
    user_id: UUID,
    start: date,
    end: date,
) -> Optional[float]:
    """Expected dose count across active-protocol compounds for [start, end]."""
    rows = await db.execute(
        select(Compound)
        .join(Protocol, Compound.protocol_id == Protocol.id)
        .where(and_(Protocol.user_id == user_id, Protocol.is_active.is_(True)))
    )
    compounds = rows.scalars().all()
    days = (end - start).days + 1
    total = 0.0
    mapped = False
    for compound in compounds:
        rate = doses_per_day(compound.frequency or "")
        if rate is None:
            continue
        mapped = True
        total += rate * days
    return total if mapped else None
