import json
from datetime import date, datetime, time, timedelta, timezone
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.insights_engine import GeneratedInsight
from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.insight import InsightSeverity, InsightType

_SYMPTOMS = {
    "nausea": "Nausea",
    "injection_site_reaction": "Injection-site reaction",
    "fatigue": "Fatigue",
    "headache": "Headache",
    "gi_issues": "GI discomfort",
}
_SEVERITY_THRESHOLD = 3
_MIN_DOSE_DATES = 3
_MIN_OCCURRENCES = 3
_LOOKBACK_DOSES = 4


async def symptom_after_dose_rule(
    db: AsyncSession,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> list[GeneratedInsight]:
    """Detect symptoms recurring on a dose date or the following day."""
    window_start = datetime.combine(start_date, time.min, tzinfo=timezone.utc)
    window_end = datetime.combine(end_date + timedelta(days=1), time.min, tzinfo=timezone.utc)
    dose_rows = await db.execute(
        select(DoseLog.administered_at).where(
            and_(
                DoseLog.user_id == user_id,
                DoseLog.administered_at >= window_start,
                DoseLog.administered_at < window_end,
            )
        )
    )
    dose_dates = sorted({row[0].date() for row in dose_rows.all()})
    if len(dose_dates) < _MIN_DOSE_DATES:
        return []
    recent_doses = dose_dates[-_LOOKBACK_DOSES:]

    checkin_rows = await db.execute(
        select(Checkin).where(
            and_(
                Checkin.user_id == user_id,
                Checkin.date >= start_date,
                Checkin.date <= end_date,
            )
        )
    )
    checkins_by_date = {checkin.date: checkin for checkin in checkin_rows.scalars().all()}

    dose_window_days = {
        day for dose_date in dose_dates for day in (dose_date, dose_date + timedelta(days=1))
    }

    results: list[GeneratedInsight] = []
    for field, display in _SYMPTOMS.items():
        occurrences = 0
        for dose_date in recent_doses:
            for day in (dose_date, dose_date + timedelta(days=1)):
                checkin = checkins_by_date.get(day)
                if checkin and (getattr(checkin, field) or 0) >= _SEVERITY_THRESHOLD:
                    occurrences += 1
                    break

        if occurrences < _MIN_OCCURRENCES:
            continue

        non_dose_days = [day for day in checkins_by_date if day not in dose_window_days]
        non_dose_hits = sum(
            (getattr(checkins_by_date[day], field) or 0) >= _SEVERITY_THRESHOLD
            for day in non_dose_days
        )
        if non_dose_days and 2 * non_dose_hits * len(recent_doses) >= occurrences * len(
            non_dose_days
        ):
            continue

        confidence = min(0.5 + 0.1 * occurrences, 0.9)
        month_key = recent_doses[-1].strftime("%Y-%m")
        supporting_data = json.dumps(
            [
                {
                    "icon_key": "symptom",
                    "label": f"{display} after dose",
                    "sublabel": "Within 24h of a logged dose",
                    "value": f"{occurrences} of last {len(recent_doses)} dose days",
                },
                {
                    "icon_key": "calendar",
                    "label": "Dose events analyzed",
                    "sublabel": f"{start_date.isoformat()} – {end_date.isoformat()}",
                    "value": str(len(dose_dates)),
                },
                {
                    "icon_key": "chart",
                    "label": "On non-dose days",
                    "sublabel": "Same symptom, days without a dose",
                    "value": (
                        f"{non_dose_hits} of {len(non_dose_days)} days"
                        if non_dose_days
                        else "no data"
                    ),
                },
            ]
        )
        results.append(
            GeneratedInsight(
                type=InsightType.ANOMALY,
                severity=InsightSeverity.WARNING,
                title=f"{display} is appearing after dose day",
                description=(
                    f"You've logged {display.lower()} within 24 hours after your dose "
                    f"on {occurrences} of the last {len(recent_doses)} dose days."
                ),
                explanation=(
                    f"Computed from {len(checkins_by_date)} check-ins and {len(dose_dates)} "
                    f"dose days between {start_date.isoformat()} and {end_date.isoformat()}. "
                    f"A dose day counts when {display.lower()} severity is "
                    f"{_SEVERITY_THRESHOLD}+ on the dose day or the day after."
                ),
                confidence=confidence,
                source_data_refs=json.dumps(
                    {"rule": "symptom_after_dose", "symptom": field, "month": month_key}
                ),
                supporting_data=supporting_data,
            )
        )

    return results
