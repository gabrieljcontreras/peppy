import json
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.adherence import expected_doses, logged_dose_events
from app.ml.insights_engine import GeneratedInsight
from app.models.checkin import Checkin
from app.models.insight import InsightSeverity, InsightType
from app.models.protocol import Protocol

_STREAK_LENGTH = 7
_PROTOCOL_MILESTONE_DAYS = 28
_ADHERENCE_WINDOW_DAYS = 14
_ADHERENCE_FLOOR = 0.7
_MIN_EXPECTED = 2.0


async def adherence_consistency_rule(
    db: AsyncSession,
    user_id: UUID,
    start_date: date,
    end_date: date,
) -> list[GeneratedInsight]:
    results: list[GeneratedInsight] = []

    rows = await db.execute(
        select(Checkin.date).where(
            and_(
                Checkin.user_id == user_id,
                Checkin.date > end_date - timedelta(days=_STREAK_LENGTH),
                Checkin.date <= end_date,
            )
        )
    )
    streak_days = {row[0] for row in rows.all()}
    if len(streak_days) == _STREAK_LENGTH:
        streak_start = end_date - timedelta(days=_STREAK_LENGTH - 1)
        results.append(
            GeneratedInsight(
                type=InsightType.MILESTONE,
                severity=InsightSeverity.INFO,
                title="7-day check-in streak",
                description=(
                    "You've checked in every day for the last 7 days. "
                    "Consistent logging is what makes your insights accurate."
                ),
                explanation=(
                    f"Check-ins found for every day from {streak_start.isoformat()} "
                    f"to {end_date.isoformat()}."
                ),
                confidence=0.9,
                source_data_refs=json.dumps(
                    {"rule": "checkin_streak_7", "start": streak_start.isoformat()}
                ),
                supporting_data=json.dumps(
                    [
                        {
                            "icon_key": "checkmark",
                            "label": "Check-in streak",
                            "sublabel": (f"{streak_start.isoformat()} – {end_date.isoformat()}"),
                            "value": "7 of 7 days",
                        }
                    ]
                ),
            )
        )

    protocols = (
        (
            await db.execute(
                select(Protocol).where(
                    and_(Protocol.user_id == user_id, Protocol.is_active.is_(True))
                )
            )
        )
        .scalars()
        .all()
    )
    for protocol in protocols:
        milestone_day = protocol.start_date + timedelta(days=_PROTOCOL_MILESTONE_DAYS)
        if start_date <= milestone_day <= end_date:
            results.append(
                GeneratedInsight(
                    type=InsightType.MILESTONE,
                    severity=InsightSeverity.INFO,
                    title=f"4 weeks on {protocol.name}",
                    description=(
                        f"You've completed 4 weeks on {protocol.name}. That's enough "
                        "history for your trends to start meaning something."
                    ),
                    explanation=(
                        f"{protocol.name} started {protocol.start_date.isoformat()}; "
                        f"week 4 completed {milestone_day.isoformat()}."
                    ),
                    confidence=0.9,
                    source_data_refs=json.dumps(
                        {"rule": "protocol_weeks_4", "protocol": str(protocol.id)}
                    ),
                    supporting_data=json.dumps(
                        [
                            {
                                "icon_key": "calendar",
                                "label": "Protocol duration",
                                "sublabel": f"Started {protocol.start_date.isoformat()}",
                                "value": "Week 4",
                            }
                        ]
                    ),
                )
            )

    window_start = end_date - timedelta(days=_ADHERENCE_WINDOW_DAYS - 1)
    expected = await expected_doses(db, user_id, window_start, end_date)
    if expected is not None and expected >= _MIN_EXPECTED:
        logged = await logged_dose_events(db, user_id, window_start, end_date)
        if logged / expected < _ADHERENCE_FLOOR:
            results.append(
                GeneratedInsight(
                    type=InsightType.SUGGESTION,
                    severity=InsightSeverity.INFO,
                    title="Doses are slipping",
                    description=(
                        f"You've logged {logged} of about {expected:.0f} expected doses "
                        f"over the last {_ADHERENCE_WINDOW_DAYS} days. A reminder or a "
                        "set dose day can help."
                    ),
                    explanation=(
                        "Expected doses computed from your active protocol's compound "
                        f"frequencies over {window_start.isoformat()} – "
                        f"{end_date.isoformat()}."
                    ),
                    confidence=0.7,
                    source_data_refs=json.dumps(
                        {"rule": "adherence_low", "window_end": end_date.isoformat()}
                    ),
                    supporting_data=json.dumps(
                        [
                            {
                                "icon_key": "chart",
                                "label": "Dose adherence",
                                "sublabel": f"Last {_ADHERENCE_WINDOW_DAYS} days",
                                "value": f"{logged} of {expected:.0f} expected doses",
                            }
                        ]
                    ),
                )
            )

    return results
