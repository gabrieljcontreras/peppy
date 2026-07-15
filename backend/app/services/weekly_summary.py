"""Deterministic weekly-summary aggregation with optional AI narrative caching."""

import asyncio
import json
import logging
from datetime import date, timedelta
from typing import Optional
from uuid import UUID
from weakref import WeakValueDictionary

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.adherence import expected_doses, logged_dose_events
from app.ml.narrator import Narrator
from app.ml.snapshot import build_longitudinal_snapshot
from app.models.checkin import Checkin
from app.models.weekly_summary import WeeklySummary

logger = logging.getLogger(__name__)

_COMPLETED_WEEK_LOOKBACK = 8
_MIN_CHECKINS = 3
_summary_locks: WeakValueDictionary[UUID, asyncio.Lock] = WeakValueDictionary()


def _summary_lock(user_id: UUID) -> asyncio.Lock:
    lock = _summary_locks.get(user_id)
    if lock is None:
        lock = asyncio.Lock()
        _summary_locks[user_id] = lock
    return lock


def completed_week_bounds(today: date) -> tuple[date, date]:
    """Return Monday through Sunday of the most recently completed week."""
    current_week_start = today - timedelta(days=today.weekday())
    week_start = current_week_start - timedelta(days=7)
    return week_start, week_start + timedelta(days=6)


def _mean(values: list[float | int]) -> Optional[float]:
    return sum(values) / len(values) if values else None


def _rounded(value: Optional[float]) -> Optional[float]:
    return round(value, 2) if value is not None else None


def _positive_change(delta: float) -> Optional[bool]:
    if delta > 0:
        return True
    if delta < 0:
        return False
    return None


def _change_metric(
    *,
    key: str,
    label: str,
    current: Optional[float],
    prior: Optional[float],
) -> Optional[dict]:
    if current is None or prior is None:
        return None
    delta = current - prior
    return {
        "key": key,
        "label": label,
        "value": f"{delta:+.1f} pts",
        "detail": f"{current:.1f} vs {prior:.1f} prior week",
        "positive": _positive_change(delta),
    }


def _format_expected_doses(value: float) -> str:
    rounded = round(value, 1)
    return str(int(rounded)) if rounded.is_integer() else f"{rounded:.1f}"


async def _latest_qualifying_week(
    db: AsyncSession,
    user_id: UUID,
    today: date,
) -> Optional[tuple[date, date]]:
    latest_start, _ = completed_week_bounds(today)
    earliest_start = latest_start - timedelta(weeks=_COMPLETED_WEEK_LOOKBACK - 1)
    latest_end = latest_start + timedelta(days=6)
    dates = (
        (
            await db.execute(
                select(Checkin.date).where(
                    and_(
                        Checkin.user_id == user_id,
                        Checkin.date >= earliest_start,
                        Checkin.date <= latest_end,
                    )
                )
            )
        )
        .scalars()
        .all()
    )
    checkin_dates = set(dates)

    for offset in range(_COMPLETED_WEEK_LOOKBACK):
        week_start = latest_start - timedelta(weeks=offset)
        week_end = week_start + timedelta(days=6)
        count = sum(week_start <= checkin_date <= week_end for checkin_date in checkin_dates)
        if count >= _MIN_CHECKINS:
            return week_start, week_end
    return None


async def _build_stats(
    db: AsyncSession,
    user_id: UUID,
    week_start: date,
    week_end: date,
) -> dict:
    prior_start = week_start - timedelta(days=7)
    checkins = list(
        (
            await db.execute(
                select(Checkin)
                .where(
                    and_(
                        Checkin.user_id == user_id,
                        Checkin.date >= prior_start,
                        Checkin.date <= week_end,
                    )
                )
                .order_by(Checkin.date.asc(), Checkin.id.asc())
            )
        )
        .scalars()
        .all()
    )
    current = [checkin for checkin in checkins if checkin.date >= week_start]
    prior = [checkin for checkin in checkins if checkin.date < week_start]

    current_weights = [checkin.weight_kg for checkin in current if checkin.weight_kg is not None]
    prior_weights = [checkin.weight_kg for checkin in prior if checkin.weight_kg is not None]
    current_weight = _mean(current_weights)
    prior_weight = _mean(prior_weights)
    weight_delta = (
        current_weight - prior_weight
        if current_weight is not None and prior_weight is not None
        else None
    )

    current_sleep = _mean(
        [checkin.sleep_quality for checkin in current if checkin.sleep_quality is not None]
    )
    prior_sleep = _mean(
        [checkin.sleep_quality for checkin in prior if checkin.sleep_quality is not None]
    )
    current_energy = _mean(
        [checkin.energy_level for checkin in current if checkin.energy_level is not None]
    )
    prior_energy = _mean(
        [checkin.energy_level for checkin in prior if checkin.energy_level is not None]
    )

    what_changed: list[dict] = []
    sleep_metric = _change_metric(
        key="sleep_quality",
        label="Sleep quality",
        current=current_sleep,
        prior=prior_sleep,
    )
    if sleep_metric is not None:
        what_changed.append(sleep_metric)

    expected = await expected_doses(db, user_id, week_start, week_end)
    if expected is not None and expected > 0:
        logged = await logged_dose_events(db, user_id, week_start, week_end)
        adherence = logged / expected
        what_changed.append(
            {
                "key": "dose_adherence",
                "label": "Dose adherence",
                "value": f"{min(round(adherence * 100), 100):.0f}%",
                "detail": (f"{logged} of {_format_expected_doses(expected)} expected doses"),
                "positive": adherence >= 0.7,
            }
        )

    what_changed.append(
        {
            "key": "checkins",
            "label": "Check-ins",
            "value": f"{len(current)} of 7",
            "detail": None,
            "positive": len(current) >= _MIN_CHECKINS,
        }
    )

    energy_metric = _change_metric(
        key="energy",
        label="Energy",
        current=current_energy,
        prior=prior_energy,
    )
    if energy_metric is not None:
        what_changed.append(energy_metric)

    return {
        "week_start": week_start.isoformat(),
        "week_end": week_end.isoformat(),
        "hero": {
            "weight_delta_kg": _rounded(weight_delta),
            "weight_from_kg": _rounded(prior_weight),
            "weight_to_kg": _rounded(current_weight),
        },
        "weight_series": [
            {
                "date": checkin.date.isoformat(),
                "weight_kg": checkin.weight_kg,
            }
            for checkin in current
            if checkin.weight_kg is not None
        ],
        "what_changed": what_changed,
        "what_to_watch": [],
        "provider_questions": [],
        "narrative": None,
    }


async def get_or_create_weekly_summary(
    db: AsyncSession,
    user_id: UUID,
    narrator: Narrator | None = None,
    today: date | None = None,
) -> Optional[dict]:
    """Return the latest qualifying completed-week summary, caching AI success."""
    async with _summary_lock(user_id):
        return await _get_or_create_weekly_summary(
            db,
            user_id,
            narrator=narrator,
            today=today,
        )


async def _get_or_create_weekly_summary(
    db: AsyncSession,
    user_id: UUID,
    narrator: Narrator | None = None,
    today: date | None = None,
) -> Optional[dict]:
    """Run one serialized cache lookup or summary computation for a user."""
    today = today or date.today()
    bounds = await _latest_qualifying_week(db, user_id, today)
    if bounds is None:
        return None
    week_start, week_end = bounds

    cached = (
        await db.execute(
            select(WeeklySummary).where(
                and_(
                    WeeklySummary.user_id == user_id,
                    WeeklySummary.week_start == week_start,
                )
            )
        )
    ).scalar_one_or_none()
    if cached is not None:
        return json.loads(cached.payload)

    payload = await _build_stats(db, user_id, week_start, week_end)
    if narrator is None:
        try:
            narrator = Narrator()
        except Exception:
            logger.warning("weekly summary narrator setup failed", exc_info=True)
            return payload
    if not narrator.enabled:
        return payload

    try:
        snapshot = await build_longitudinal_snapshot(
            db,
            user_id,
            week_start - timedelta(days=7),
            week_end,
        )
        narrative = await narrator.write_summary_narrative(payload, snapshot)
    except Exception:
        logger.warning("weekly summary narration failed", exc_info=True)
        return payload
    if narrative is None:
        return payload

    payload.update(narrative)
    db.add(
        WeeklySummary(
            user_id=user_id,
            week_start=week_start,
            payload=json.dumps(payload),
            model_used=narrator.summary_model,
        )
    )
    await db.commit()
    return payload
