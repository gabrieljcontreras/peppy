from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.dose_log import DoseLog
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


@dataclass(frozen=True)
class _CompoundDoseWindow:
    protocol_id: UUID
    compound_id: UUID
    start: date
    end: date
    expected: float


def doses_per_day(frequency: str) -> Optional[float]:
    key = "".join(ch for ch in frequency.lower() if ch.isalnum())
    return _RATES.get(key)


async def _compound_dose_windows(
    db: AsyncSession,
    user_id: UUID,
    start: date,
    end: date,
) -> list[_CompoundDoseWindow]:
    rows = await db.execute(
        select(Compound, Protocol.start_date, Protocol.end_date)
        .join(Protocol, Compound.protocol_id == Protocol.id)
        .where(and_(Protocol.user_id == user_id, Protocol.is_active.is_(True)))
    )
    windows: list[_CompoundDoseWindow] = []
    for compound, protocol_start, protocol_end in rows.all():
        rate = doses_per_day(compound.frequency or "")
        if rate is None:
            continue
        overlap_start = max(start, protocol_start)
        overlap_end = min(end, protocol_end) if protocol_end is not None else end
        if overlap_start > overlap_end:
            continue
        windows.append(
            _CompoundDoseWindow(
                protocol_id=compound.protocol_id,
                compound_id=compound.id,
                start=overlap_start,
                end=overlap_end,
                expected=rate * ((overlap_end - overlap_start).days + 1),
            )
        )
    return windows


async def expected_doses(
    db: AsyncSession,
    user_id: UUID,
    start: date,
    end: date,
) -> Optional[float]:
    """Expected compound-dose events in each active protocol's window overlap."""
    windows = await _compound_dose_windows(db, user_id, start, end)
    return sum(window.expected for window in windows) if windows else None


async def logged_dose_events(
    db: AsyncSession,
    user_id: UUID,
    start: date,
    end: date,
) -> int:
    """Count eligible compound/date dose events, de-duplicating repeated logs."""
    windows = await _compound_dose_windows(db, user_id, start, end)
    if not windows:
        return 0

    start_at = datetime.combine(start, time.min, tzinfo=timezone.utc)
    end_at = datetime.combine(end + timedelta(days=1), time.min, tzinfo=timezone.utc)
    protocol_ids = {window.protocol_id for window in windows}
    compound_ids = {window.compound_id for window in windows}
    rows = await db.execute(
        select(DoseLog.protocol_id, DoseLog.compound_id, DoseLog.administered_at).where(
            and_(
                DoseLog.user_id == user_id,
                DoseLog.protocol_id.in_(protocol_ids),
                DoseLog.compound_id.in_(compound_ids),
                DoseLog.administered_at >= start_at,
                DoseLog.administered_at < end_at,
            )
        )
    )

    windows_by_pair = {(window.protocol_id, window.compound_id): window for window in windows}
    events: set[tuple[UUID, date]] = set()
    for protocol_id, compound_id, administered_at in rows.all():
        window = windows_by_pair.get((protocol_id, compound_id))
        administered_date = administered_at.date()
        if window is not None and window.start <= administered_date <= window.end:
            events.add((compound_id, administered_date))
    return len(events)
