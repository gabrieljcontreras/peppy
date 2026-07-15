"""Seed a demo user whose data fires every insight rule and the weekly summary.

Run: cd backend && venv/bin/python -m scripts.seed_insights_demo

Creates (or resets) insights-demo@peppy.dev / peppy-demo-1 with:
- an active weekly Retatrutide protocol started 30 days ago (4-week milestone),
- weekly dose logs, the most recent two days ago,
- 30 consecutive daily check-ins ending today (7-day streak):
  weight declining ~0.35 kg/week (weight trend), energy 7 / nausea 0 baseline,
  energy 2 + nausea 5 + mood 3 on each day after a dose
  (symptom-after-dose anomaly, dose-day energy dip),
- two full Mon-Sun weeks of data so the weekly summary qualifies.

Ends by running insight generation directly and printing the breakdown.
"""

import asyncio
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_maker
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import Insight
from app.models.protocol import Compound, Protocol
from app.models.user import User
from app.models.weekly_summary import WeeklySummary
from app.services.auth import hash_password
from app.services.insight_generation import run_generation

DEMO_EMAIL = "insights-demo@peppy.dev"
DEMO_PASSWORD = "peppy-demo-1"

CHECKIN_DAYS = 30
DOSE_DAY_OFFSETS = (29, 22, 15, 8, 2)  # weekly cadence, most recent 2 days ago
WEIGHT_START_KG = 84.0
WEIGHT_STEP_KG = 0.05  # per day ≈ 0.35 kg/week; ~1.7% over the window (trend fires at 1%)
BASELINE_ENERGY = 7
BASELINE_MOOD = 7
AFTER_DOSE_ENERGY = 2
AFTER_DOSE_MOOD = 3
AFTER_DOSE_NAUSEA = 5


async def _get_or_create_user(db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.email == DEMO_EMAIL))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(email=DEMO_EMAIL, hashed_password=hash_password(DEMO_PASSWORD))
        db.add(user)
    else:
        user.hashed_password = hash_password(DEMO_PASSWORD)
    user.last_insight_run_at = None
    await db.flush()
    return user


async def _reset_user_data(db: AsyncSession, user: User) -> None:
    """Wipe prior demo data so reruns produce a deterministic dataset."""
    for model in (Checkin, DoseLog, Insight, WeeklySummary):
        await db.execute(delete(model).where(model.user_id == user.id))
    protocol_ids = (
        await db.execute(select(Protocol.id).where(Protocol.user_id == user.id))
    ).scalars().all()
    if protocol_ids:
        await db.execute(delete(Compound).where(Compound.protocol_id.in_(protocol_ids)))
        await db.execute(delete(Protocol).where(Protocol.id.in_(protocol_ids)))


async def seed() -> None:
    async with async_session_maker() as db:
        user = await _get_or_create_user(db)
        await _reset_user_data(db, user)

        today = date.today()

        protocol = Protocol(
            user_id=user.id,
            name="Retatrutide titration",
            start_date=today - timedelta(days=30),  # 4-week milestone 2 days ago
            is_active=True,
        )
        db.add(protocol)
        await db.flush()

        compound = Compound(
            protocol_id=protocol.id,
            name="Retatrutide",
            dose_mg=4,
            dose_unit="mg",
            frequency="weekly",
            administration_route="subcutaneous",
        )
        db.add(compound)
        await db.flush()

        dose_dates = [today - timedelta(days=offset) for offset in DOSE_DAY_OFFSETS]
        for dose_date in dose_dates:
            db.add(DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=4,
                unit="mg",
                route="subcutaneous",
                administered_at=datetime.combine(dose_date, time(hour=9), tzinfo=timezone.utc),
            ))

        after_dose_days = {d + timedelta(days=1) for d in dose_dates}
        for offset in range(CHECKIN_DAYS - 1, -1, -1):
            day = today - timedelta(days=offset)
            is_after_dose = day in after_dose_days
            db.add(Checkin(
                user_id=user.id,
                date=day,
                weight_kg=round(WEIGHT_START_KG - WEIGHT_STEP_KG * (CHECKIN_DAYS - 1 - offset), 2),
                energy_level=AFTER_DOSE_ENERGY if is_after_dose else BASELINE_ENERGY,
                mood=AFTER_DOSE_MOOD if is_after_dose else BASELINE_MOOD,
                sleep_quality=7,
                appetite_level=5,
                nausea=AFTER_DOSE_NAUSEA if is_after_dose else 0,
            ))

        await db.commit()

        breakdown = await run_generation(db, user.id)

        print(f"Seeded demo user {DEMO_EMAIL} / {DEMO_PASSWORD}")
        print(f"  protocol: {protocol.name} (started {protocol.start_date.isoformat()})")
        print(f"  dose logs: {len(dose_dates)} weekly doses, latest {dose_dates[-1].isoformat()}")
        print(f"  check-ins: {CHECKIN_DAYS} consecutive days ending {today.isoformat()}")
        print(f"Generation breakdown: {breakdown}")


if __name__ == "__main__":
    asyncio.run(seed())
