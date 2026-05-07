import json
from datetime import date
from uuid import UUID

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.checkin import Checkin
from app.models.insight import InsightType, InsightSeverity
from app.ml.insights_engine import GeneratedInsight


_MIN_CHECKINS = 3
_MIN_DROP_FRACTION = 0.01  # 1%


async def weight_trend_rule(
    db: AsyncSession,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> list[GeneratedInsight]:
    """
    Detect a sustained downward weight trend in the analysis window.

    Fires when the user has at least three weight check-ins in the window
    and weight has decreased by at least 1% from the first to the last
    measurement.
    """
    result = await db.execute(
        select(Checkin)
        .where(
            and_(
                Checkin.user_id == user_id,
                Checkin.weight_kg.is_not(None),
                Checkin.date >= start_date,
                Checkin.date <= end_date,
            )
        )
        .order_by(Checkin.date.asc())
    )
    checkins = result.scalars().all()

    if len(checkins) < _MIN_CHECKINS:
        return []

    first_weight = checkins[0].weight_kg
    last_weight = checkins[-1].weight_kg
    if first_weight <= 0:
        return []

    change_fraction = (last_weight - first_weight) / first_weight
    if change_fraction > -_MIN_DROP_FRACTION:
        return []

    drop_kg = first_weight - last_weight
    drop_pct = -change_fraction * 100
    refs = json.dumps([f"checkin:{c.id}" for c in checkins])

    confidence = min(0.5 + 0.1 * (len(checkins) - _MIN_CHECKINS), 0.95)

    return [
        GeneratedInsight(
            type=InsightType.TREND,
            severity=InsightSeverity.INFO,
            title="Weight trending down",
            description=(
                f"Your weight is down {drop_kg:.1f} kg ({drop_pct:.1f}%) "
                f"over {len(checkins)} check-ins from "
                f"{checkins[0].date.isoformat()} to {checkins[-1].date.isoformat()}."
            ),
            explanation=(
                f"Computed from {len(checkins)} weight check-ins between "
                f"{start_date.isoformat()} and {end_date.isoformat()}. "
                f"First measurement: {first_weight:.1f} kg. "
                f"Last measurement: {last_weight:.1f} kg."
            ),
            confidence=confidence,
            source_data_refs=refs,
        )
    ]
