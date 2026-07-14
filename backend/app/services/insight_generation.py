"""Shared orchestration for deterministic insight generation."""

import logging
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_maker
from app.ml.insights_engine import InsightsEngine
from app.ml.narrator import Narrator
from app.ml.snapshot import build_longitudinal_snapshot
from app.models.insight import InsightSeverity
from app.models.user import User
from app.services.insight import InsightService
from app.services.notification import NotificationService

logger = logging.getLogger(__name__)

STALENESS_WINDOW = timedelta(hours=6)
session_factory = async_session_maker


async def run_generation(
    db: AsyncSession,
    user_id: UUID,
    start_date: date | None = None,
    end_date: date | None = None,
    narrator: Narrator | None = None,
) -> dict:
    """Run rules, deduplicate candidates, persist new insights, and stamp the user."""
    if end_date is None:
        end_date = date.today()
    if start_date is None:
        start_date = end_date - timedelta(days=30)

    engine = InsightsEngine(db)
    candidates = await engine.analyze_user_data(user_id, start_date, end_date)

    service = InsightService(db)
    new_candidates = []
    for candidate in candidates:
        if await service.exists_matching(
            user_id,
            candidate.type,
            candidate.source_data_refs,
        ):
            continue
        new_candidates.append(candidate)

    if narrator is None:
        narrator = Narrator()

    descriptions = None
    if new_candidates and narrator.enabled:
        snapshot = await build_longitudinal_snapshot(
            db,
            user_id,
            start_date,
            end_date,
        )
        descriptions = await narrator.enrich_insight_descriptions(
            new_candidates,
            snapshot,
        )

    notification_service = NotificationService(db)
    for index, candidate in enumerate(new_candidates):
        description = descriptions[index] if descriptions is not None else candidate.description
        insight = await service.create(
            user_id=user_id,
            type=candidate.type,
            severity=candidate.severity,
            title=candidate.title,
            description=description,
            explanation=candidate.explanation,
            confidence=candidate.confidence,
            source_data_refs=candidate.source_data_refs,
            supporting_data=candidate.supporting_data,
        )
        if candidate.severity == InsightSeverity.ALERT:
            await notification_service.send_insight_notification(
                user_id=user_id,
                insight_id=insight.id,
                title=candidate.title,
                body=description,
                severity=candidate.severity,
            )

    user = await db.get(User, user_id)
    if user is None:
        raise ValueError("User not found")
    user.last_insight_run_at = datetime.now(timezone.utc)
    await db.commit()

    breakdown = Counter(candidate.type.value for candidate in new_candidates)
    return {
        "insights_generated": len(new_candidates),
        "types_breakdown": dict(breakdown),
    }


async def run_generation_in_background(user_id: UUID) -> None:
    """Open a dedicated session and generate insights for a background trigger."""
    try:
        async with session_factory() as db:
            await run_generation(db, user_id)
    except Exception:
        logger.warning("background insight generation failed", exc_info=True)


def is_stale(user) -> bool:
    """Return whether a user's insight generation marker is older than six hours."""
    last_run = user.last_insight_run_at
    if last_run is None:
        return True
    if last_run.tzinfo is None or last_run.utcoffset() is None:
        last_run = last_run.replace(tzinfo=timezone.utc)
    return last_run < datetime.now(timezone.utc) - STALENESS_WINDOW
