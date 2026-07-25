from datetime import date, datetime, timedelta, timezone
from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.checkin import Checkin
from app.models.insight import Insight
from app.models.lab import LabResult
from app.models.profile import OnboardingProfile
from app.models.protocol import Protocol
from app.models.wearable import WearableConnection


class DashboardService:
    """Read-only aggregate for the iOS Home dashboard."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def summary_for_user(self, user_id: UUID) -> dict[str, Any]:
        profile = await self._profile(user_id)
        protocol = await self._protocol(user_id)
        today = await self._today_checkin(user_id)
        recent = await self._recent_checkins(user_id)
        latest_insight = await self._latest_insight(user_id)

        return {
            "generated_at": datetime.now(timezone.utc),
            "profile_status": "present" if profile else "missing",
            "protocol": self._protocol_summary(protocol),
            "today_checkin": {
                "logged": today is not None,
                "checkin_id": None if today is None else today.id,
            },
            "response_snapshot": {
                "weight_trend": [
                    {"date": checkin.date, "weight_kg": checkin.weight_kg}
                    for checkin in reversed(recent)
                    if checkin.weight_kg is not None
                ],
                "latest_energy": None if not recent else recent[0].energy_level,
                "latest_mood": None if not recent else recent[0].mood,
            },
            "insight": self._insight_summary(latest_insight, len(recent)),
            "connected_context": {
                "healthkit_requested": None if profile is None else profile.healthkit_requested,
                "has_labs": await self._has_rows(LabResult, user_id),
                "has_wearables": await self._has_rows(WearableConnection, user_id),
            },
        }

    async def _profile(self, user_id: UUID) -> OnboardingProfile | None:
        result = await self.db.execute(
            select(OnboardingProfile).where(OnboardingProfile.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def _protocol(self, user_id: UUID) -> Protocol | None:
        result = await self.db.execute(
            select(Protocol)
            .options(selectinload(Protocol.compounds))
            .where(Protocol.user_id == user_id)
            .order_by(Protocol.is_active.desc(), Protocol.updated_at.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def _today_checkin(self, user_id: UUID) -> Checkin | None:
        result = await self.db.execute(
            select(Checkin).where(Checkin.user_id == user_id, Checkin.date == date.today())
        )
        return result.scalar_one_or_none()

    async def _recent_checkins(self, user_id: UUID) -> list[Checkin]:
        result = await self.db.execute(
            select(Checkin)
            .where(Checkin.user_id == user_id, Checkin.date >= date.today() - timedelta(days=30))
            .order_by(Checkin.date.desc())
            .limit(10)
        )
        return list(result.scalars().all())

    async def _latest_insight(self, user_id: UUID) -> Insight | None:
        result = await self.db.execute(
            select(Insight)
            .where(Insight.user_id == user_id, Insight.dismissed_at.is_(None))
            .order_by(Insight.created_at.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def _has_rows(self, model: Any, user_id: UUID) -> bool:
        result = await self.db.execute(select(func.count(model.id)).where(model.user_id == user_id))
        return bool(result.scalar() or 0)

    def _protocol_summary(self, protocol: Protocol | None) -> dict[str, Any]:
        if protocol is None:
            return {
                "id": None,
                "status": "missing",
                "title": "Create your protocol",
                "compounds": [],
                "start_date": None,
            }
        return {
            "id": protocol.id,
            "status": protocol.setup_status,
            "title": protocol.name,
            "compounds": [compound.name for compound in protocol.compounds],
            "start_date": protocol.start_date,
        }

    def _insight_summary(self, insight: Insight | None, checkin_count: int) -> dict[str, Any]:
        if insight:
            severity = insight.severity.value if hasattr(insight.severity, "value") else str(insight.severity)
            return {
                "id": insight.id,
                "title": insight.title,
                "severity": severity,
                "empty_message": None,
            }
        if checkin_count < 3:
            return {
                "id": None,
                "title": None,
                "severity": None,
                "empty_message": "Peppy needs a few check-ins to find useful patterns.",
            }
        return {
            "id": None,
            "title": None,
            "severity": None,
            "empty_message": "No new insights right now.",
        }
