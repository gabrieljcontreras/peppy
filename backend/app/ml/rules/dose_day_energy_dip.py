import json
from datetime import date, datetime, time, timedelta, timezone
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.insights_engine import GeneratedInsight
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import InsightSeverity, InsightType

_MIN_DOSE_DATES = 3
_MIN_GROUP_CHECKINS = 2
_GAP_THRESHOLD = 1.5
_WARNING_GAP = 3.0


def _mean(values: list[int]) -> float:
    return sum(values) / len(values)


async def dose_day_energy_dip_rule(
    db: AsyncSession,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> list[GeneratedInsight]:
    """Detect lower energy on dose dates and their following days."""
    start_at = datetime.combine(start_date, time.min, tzinfo=timezone.utc)
    end_at = datetime.combine(end_date + timedelta(days=1), time.min, tzinfo=timezone.utc)
    dose_result = await db.execute(
        select(DoseLog.administered_at).where(
            and_(
                DoseLog.user_id == user_id,
                DoseLog.administered_at >= start_at,
                DoseLog.administered_at < end_at,
            )
        )
    )
    dose_dates = sorted({administered_at.date() for (administered_at,) in dose_result.all()})
    if len(dose_dates) < _MIN_DOSE_DATES:
        return []

    dose_window_days = {
        window_day
        for dose_date in dose_dates
        for window_day in (dose_date, dose_date + timedelta(days=1))
    }
    checkin_result = await db.execute(
        select(Checkin).where(
            and_(
                Checkin.user_id == user_id,
                Checkin.date >= start_date,
                Checkin.date <= end_date,
            )
        )
    )
    checkins = checkin_result.scalars().all()

    def split(field: str) -> tuple[list[int], list[int]]:
        dose_values: list[int] = []
        other_values: list[int] = []
        for checkin in checkins:
            value = getattr(checkin, field)
            if value is None:
                continue
            target = dose_values if checkin.date in dose_window_days else other_values
            target.append(value)
        return dose_values, other_values

    dose_energy, other_energy = split("energy_level")
    if len(dose_energy) < _MIN_GROUP_CHECKINS or len(other_energy) < _MIN_GROUP_CHECKINS:
        return []

    dose_energy_mean = _mean(dose_energy)
    other_energy_mean = _mean(other_energy)
    energy_gap = other_energy_mean - dose_energy_mean
    if energy_gap < _GAP_THRESHOLD:
        return []

    dose_mood, other_mood = split("mood")
    mood_dips = (
        len(dose_mood) >= _MIN_GROUP_CHECKINS
        and len(other_mood) >= _MIN_GROUP_CHECKINS
        and _mean(other_mood) - _mean(dose_mood) >= _GAP_THRESHOLD
    )
    mood_clause = " Mood shows the same pattern." if mood_dips else ""
    severity = InsightSeverity.WARNING if energy_gap >= _WARNING_GAP else InsightSeverity.INFO

    return [
        GeneratedInsight(
            type=InsightType.TREND,
            severity=severity,
            title="Energy dips on dose day",
            description=(
                f"Your average energy is {dose_energy_mean:.1f}/10 on dose days "
                f"(and the day after) vs {other_energy_mean:.1f}/10 on other days."
                f"{mood_clause}"
            ),
            explanation=(
                f"Computed from {len(dose_energy) + len(other_energy)} energy check-ins "
                f"across {len(dose_dates)} dose days between {start_date.isoformat()} "
                f"and {end_date.isoformat()}. Dose window = dose day plus the following day."
            ),
            confidence=min(0.5 + 0.1 * len(dose_dates), 0.9),
            source_data_refs=json.dumps(
                {"rule": "dose_day_energy_dip", "month": end_date.strftime("%Y-%m")}
            ),
            supporting_data=json.dumps(
                [
                    {
                        "icon_key": "chart",
                        "label": "Energy on dose days",
                        "sublabel": "Dose day + day after",
                        "value": f"{dose_energy_mean:.1f} / 10 avg",
                    },
                    {
                        "icon_key": "chart",
                        "label": "Energy on other days",
                        "sublabel": None,
                        "value": f"{other_energy_mean:.1f} / 10 avg",
                    },
                    {
                        "icon_key": "calendar",
                        "label": "Dose days analyzed",
                        "sublabel": f"{start_date.isoformat()} – {end_date.isoformat()}",
                        "value": str(len(dose_dates)),
                    },
                ]
            ),
        )
    ]
