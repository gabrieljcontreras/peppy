import json
from datetime import date
from uuid import UUID

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.checkin import Checkin
from app.models.insight import InsightType, InsightSeverity
from app.ml.insights_engine import GeneratedInsight


_MIN_CHECKINS = 3
_MIN_SPAN_DAYS = 14
_MAX_RANGE_KG = 0.5


async def weight_plateau_rule(
    db: AsyncSession,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> list[GeneratedInsight]:
    """
    Detect a weight plateau in the analysis window.

    Fires when the user has at least three weight check-ins spanning at
    least 14 days, and the weight range (max - min) is <= 0.5 kg.
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

    first_date = checkins[0].date
    last_date = checkins[-1].date
    span_days = (last_date - first_date).days
    if span_days < _MIN_SPAN_DAYS:
        return []

    weights = [c.weight_kg for c in checkins]
    weight_range = max(weights) - min(weights)
    if weight_range > _MAX_RANGE_KG:
        return []

    avg_weight = sum(weights) / len(weights)
    refs = json.dumps([f"checkin:{c.id}" for c in checkins])
    confidence = min(0.5 + 0.05 * (span_days - _MIN_SPAN_DAYS), 0.9)

    return [
        GeneratedInsight(
            type=InsightType.TREND,
            severity=InsightSeverity.INFO,
            title="Weight plateau detected",
            description=(
                f"Your weight has stayed within {weight_range:.1f} kg "
                f"(around {avg_weight:.1f} kg) for {span_days} days."
            ),
            explanation=(
                f"Computed from {len(checkins)} weight check-ins between "
                f"{first_date.isoformat()} and {last_date.isoformat()}. "
                f"Range: {min(weights):.1f} - {max(weights):.1f} kg."
            ),
            confidence=confidence,
            source_data_refs=refs,
        )
    ]
