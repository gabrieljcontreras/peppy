import json
from datetime import date
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.insights_engine import GeneratedInsight
from app.models.checkin import Checkin
from app.models.insight import InsightSeverity, InsightType

_MIN_CHECKINS = 3
_SOURCE_REFERENCE = json.dumps(
    {"rule": "checkin_baseline_v1"},
    sort_keys=True,
)


def _average(values: list[float]) -> float:
    return sum(values) / len(values)


async def checkin_baseline_rule(
    db: AsyncSession,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> list[GeneratedInsight]:
    result = await db.execute(
        select(Checkin)
        .where(
            and_(
                Checkin.user_id == user_id,
                Checkin.date >= start_date,
                Checkin.date <= end_date,
            )
        )
        .order_by(Checkin.date.desc(), Checkin.id.desc())
        .limit(_MIN_CHECKINS)
    )
    checkins = list(reversed(result.scalars().all()))
    if len(checkins) < _MIN_CHECKINS:
        return []

    date_range = f"{checkins[0].date.isoformat()} – {checkins[-1].date.isoformat()}"
    description_parts: list[str] = []
    supporting_data: list[dict] = []

    weights = [
        float(checkin.weight_kg)
        for checkin in checkins
        if checkin.weight_kg is not None
    ]
    if weights:
        if len(weights) == 1:
            description_parts.append(f"Your recorded weight was {weights[0]:.1f} kg")
            weight_value = f"{weights[0]:.1f} kg"
        else:
            description_parts.append(
                f"Your weight moved from {weights[0]:.1f} kg to {weights[-1]:.1f} kg"
            )
            weight_value = f"{weights[0]:.1f} → {weights[-1]:.1f} kg"
        supporting_data.append(
            {
                "icon_key": "weight",
                "label": "Weight",
                "sublabel": date_range,
                "value": weight_value,
            }
        )

    rating_metrics = (
        ("energy_level", "Energy", "Average energy", "chart"),
        ("mood", "Mood", "Average mood", "chart"),
        ("sleep_quality", "Sleep quality", "Average sleep quality", "sleep"),
    )
    for field, description_label, row_label, icon_key in rating_metrics:
        values = [
            float(value)
            for checkin in checkins
            if (value := getattr(checkin, field)) is not None
        ]
        if not values:
            continue
        average = _average(values)
        description_parts.append(f"{description_label} averaged {average:.1f}/10")
        supporting_data.append(
            {
                "icon_key": icon_key,
                "label": row_label,
                "sublabel": date_range,
                "value": f"{average:.1f} / 10",
            }
        )

    if not description_parts:
        return []

    supporting_data.append(
        {
            "icon_key": "calendar",
            "label": "Check-ins analyzed",
            "sublabel": date_range,
            "value": str(len(checkins)),
        }
    )
    description = ". ".join(description_parts[:2]) + "."

    return [
        GeneratedInsight(
            type=InsightType.TREND,
            severity=InsightSeverity.INFO,
            title="Your recent check-in pattern",
            description=description,
            explanation=(
                "Computed from your latest 3 check-ins from "
                f"{checkins[0].date.isoformat()} to {checkins[-1].date.isoformat()}. "
                "Only values you recorded are included."
            ),
            confidence=0.6,
            source_data_refs=_SOURCE_REFERENCE,
            supporting_data=json.dumps(supporting_data),
        )
    ]
