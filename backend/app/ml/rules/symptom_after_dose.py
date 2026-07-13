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

    recent_dose_dates = dose_dates[-_LOOKBACK_DOSES:]
    checkin_result = await db.execute(
        select(Checkin).where(
            and_(
                Checkin.user_id == user_id,
                Checkin.date >= start_date,
                Checkin.date <= end_date,
            )
        )
    )
    checkins_by_date = {checkin.date: checkin for checkin in checkin_result.scalars().all()}
    dose_window_dates = {
        window_date
        for dose_date in dose_dates
        for window_date in (dose_date, dose_date + timedelta(days=1))
    }

    insights: list[GeneratedInsight] = []
    for field, display_name in _SYMPTOMS.items():
        occurrences = 0
        for dose_date in recent_dose_dates:
            if any(
                (checkin := checkins_by_date.get(checkin_date))
                and (getattr(checkin, field) or 0) >= _SEVERITY_THRESHOLD
                for checkin_date in (dose_date, dose_date + timedelta(days=1))
            ):
                occurrences += 1

        if occurrences < _MIN_OCCURRENCES:
            continue

        non_dose_dates = [
            checkin_date
            for checkin_date in checkins_by_date
            if checkin_date not in dose_window_dates
        ]
        non_dose_hits = sum(
            (getattr(checkins_by_date[checkin_date], field) or 0) >= _SEVERITY_THRESHOLD
            for checkin_date in non_dose_dates
        )
        if non_dose_dates and 2 * non_dose_hits * len(recent_dose_dates) >= occurrences * len(
            non_dose_dates
        ):
            continue

        evidence = json.dumps(
            [
                {
                    "icon_key": "symptom",
                    "label": f"{display_name} after dose",
                    "sublabel": "Within 24h of a logged dose",
                    "value": f"{occurrences} of last {len(recent_dose_dates)} dose days",
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
                        f"{non_dose_hits} of {len(non_dose_dates)} days"
                        if non_dose_dates
                        else "no data"
                    ),
                },
            ]
        )
        confidence = min(0.5 + 0.1 * occurrences, 0.9)
        insights.append(
            GeneratedInsight(
                type=InsightType.ANOMALY,
                severity=InsightSeverity.WARNING,
                title=f"{display_name} is appearing after dose day",
                description=(
                    f"You've logged {display_name.lower()} within 24 hours after your dose "
                    f"on {occurrences} of the last {len(recent_dose_dates)} dose days."
                ),
                explanation=(
                    f"Computed from {len(checkins_by_date)} check-ins and {len(dose_dates)} "
                    f"dose days between {start_date.isoformat()} and {end_date.isoformat()}. "
                    f"A dose day counts when {display_name.lower()} severity is "
                    f"{_SEVERITY_THRESHOLD}+ on the dose day or the day after."
                ),
                confidence=confidence,
                source_data_refs=json.dumps(
                    {
                        "rule": "symptom_after_dose",
                        "symptom": field,
                        "month": recent_dose_dates[-1].strftime("%Y-%m"),
                    }
                ),
                supporting_data=evidence,
            )
        )

    return insights
