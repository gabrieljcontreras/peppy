"""Shared orchestration for insight generation."""

import asyncio
import logging
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from uuid import UUID
from weakref import WeakValueDictionary

from sqlalchemy import select
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
_generation_locks: WeakValueDictionary[UUID, asyncio.Lock] = WeakValueDictionary()


def _generation_lock(user_id: UUID) -> asyncio.Lock:
    """Return the in-process lock complementing the database user-row lock."""
    lock = _generation_locks.get(user_id)
    if lock is None:
        lock = asyncio.Lock()
        _generation_locks[user_id] = lock
    return lock


async def run_generation(
    db: AsyncSession,
    user_id: UUID,
    start_date: date | None = None,
    end_date: date | None = None,
    narrator: Narrator | None = None,
) -> dict:
    """Run rules, deduplicate candidates, persist new insights, and stamp the user."""
    async with _generation_lock(user_id):
        return await _run_generation(
            db,
            user_id,
            start_date=start_date,
            end_date=end_date,
            narrator=narrator,
        )


async def _run_generation(
    db: AsyncSession,
    user_id: UUID,
    start_date: date | None = None,
    end_date: date | None = None,
    narrator: Narrator | None = None,
) -> dict:
    """Run one serialized generation transaction for a user."""
    if end_date is None:
        end_date = date.today()
    if start_date is None:
        start_date = end_date - timedelta(days=30)

    user_result = await db.execute(select(User).where(User.id == user_id).with_for_update())
    user = user_result.scalar_one_or_none()
    if user is None:
        raise ValueError("User not found")

    engine = InsightsEngine(db)
    candidates = await engine.analyze_user_data(user_id, start_date, end_date)

    service = InsightService(db)
    new_candidates = []
    seen_candidates = set()
    for candidate in candidates:
        candidate_key = (candidate.type, candidate.source_data_refs)
        if candidate_key in seen_candidates:
            continue
        if await service.exists_matching(
            user_id,
            candidate.type,
            candidate.source_data_refs,
        ):
            continue
        seen_candidates.add(candidate_key)
        new_candidates.append(candidate)

    descriptions = None
    if new_candidates:
        try:
            if narrator is None:
                narrator = Narrator()
            if narrator.enabled:
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
        except Exception:
            logger.warning("insight narration failed; using template text", exc_info=True)

    alerts = []
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
            commit=False,
        )
        if candidate.severity == InsightSeverity.ALERT:
            alerts.append((insight.id, candidate, description))

    user.last_insight_run_at = datetime.now(timezone.utc)
    await db.commit()

    notification_service = NotificationService(db)
    for insight_id, candidate, description in alerts:
        try:
            await notification_service.send_insight_notification(
                user_id=user_id,
                insight_id=insight_id,
                title=candidate.title,
                body=description,
                severity=candidate.severity,
            )
        except Exception:
            logger.warning(
                "insight notification failed after generation commit",
                exc_info=True,
            )

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
