from uuid import UUID
from datetime import date
from typing import Optional, Sequence
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.checkin import Checkin


class CheckinService:
    """
    Service for managing user check-ins.

    Check-ins are daily logs of metrics and symptoms that users record
    to track their response to peptide protocols over time.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, checkin_id: UUID, user_id: UUID) -> Optional[Checkin]:
        """Get a check-in by ID, ensuring it belongs to the specified user."""
        result = await self.db.execute(
            select(Checkin).where(
                and_(
                    Checkin.id == checkin_id,
                    Checkin.user_id == user_id,
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_by_date(self, user_id: UUID, checkin_date: date) -> Optional[Checkin]:
        """Get a user's check-in for a specific date."""
        result = await self.db.execute(
            select(Checkin).where(
                and_(
                    Checkin.user_id == user_id,
                    Checkin.date == checkin_date,
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_today(self, user_id: UUID) -> Optional[Checkin]:
        """Get today's check-in for a user."""
        return await self.get_by_date(user_id, date.today())

    async def list_for_user(
        self,
        user_id: UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> Sequence[Checkin]:
        """
        List check-ins for a user, ordered by date descending.
        Optionally filter by date range.
        """
        query = select(Checkin).where(Checkin.user_id == user_id)

        if start_date:
            query = query.where(Checkin.date >= start_date)
        if end_date:
            query = query.where(Checkin.date <= end_date)

        query = query.order_by(Checkin.date.desc()).offset(offset).limit(limit)

        result = await self.db.execute(query)
        return result.scalars().all()

    async def create(
        self,
        user_id: UUID,
        checkin_date: date,
        weight_kg: Optional[float] = None,
        energy_level: Optional[int] = None,
        sleep_quality: Optional[int] = None,
        appetite_level: Optional[int] = None,
        mood: Optional[int] = None,
        nausea: Optional[int] = None,
        injection_site_reaction: Optional[int] = None,
        fatigue: Optional[int] = None,
        headache: Optional[int] = None,
        gi_issues: Optional[int] = None,
        notes: Optional[str] = None,
    ) -> Checkin:
        """
        Create a new check-in for a user.

        Only one check-in per user per date is allowed.
        """
        existing = await self.get_by_date(user_id, checkin_date)
        if existing:
            raise ValueError(f"Check-in already exists for {checkin_date}")

        checkin = Checkin(
            user_id=user_id,
            date=checkin_date,
            weight_kg=weight_kg,
            energy_level=energy_level,
            sleep_quality=sleep_quality,
            appetite_level=appetite_level,
            mood=mood,
            nausea=nausea,
            injection_site_reaction=injection_site_reaction,
            fatigue=fatigue,
            headache=headache,
            gi_issues=gi_issues,
            notes=notes,
        )

        self.db.add(checkin)
        await self.db.commit()
        await self.db.refresh(checkin)
        return checkin

    async def update(self, checkin: Checkin, changes: dict[str, object]) -> Checkin:
        """Apply only provided fields; explicit None clears nullable columns."""
        if "date" in changes:
            checkin_date = changes["date"]
            if checkin_date is not None and checkin_date != checkin.date:
                existing = await self.get_by_date(checkin.user_id, checkin_date)
                if existing and existing.id != checkin.id:
                    raise ValueError(f"Check-in already exists for {checkin_date}")
                checkin.date = checkin_date

        mutable_fields = (
            "weight_kg",
            "energy_level",
            "sleep_quality",
            "appetite_level",
            "mood",
            "nausea",
            "injection_site_reaction",
            "fatigue",
            "headache",
            "gi_issues",
            "notes",
        )
        for field in mutable_fields:
            if field in changes:
                setattr(checkin, field, changes[field])

        await self.db.commit()
        await self.db.refresh(checkin)
        return checkin

    async def delete(self, checkin: Checkin) -> None:
        """Delete a check-in."""
        await self.db.delete(checkin)
        await self.db.commit()

    async def get_weight_trend(
        self,
        user_id: UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
    ) -> list[tuple[date, float]]:
        """
        Get weight measurements over time for trend analysis.
        Returns list of (date, weight_kg) tuples ordered by date.
        """
        query = select(Checkin.date, Checkin.weight_kg).where(
            and_(
                Checkin.user_id == user_id,
                Checkin.weight_kg.is_not(None),
            )
        )

        if start_date:
            query = query.where(Checkin.date >= start_date)
        if end_date:
            query = query.where(Checkin.date <= end_date)

        query = query.order_by(Checkin.date.asc())

        result = await self.db.execute(query)
        return [(row[0], row[1]) for row in result.all()]

    async def get_stats(
        self,
        user_id: UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
    ) -> dict:
        """
        Calculate aggregated stats over a date range.
        """
        query = select(
            func.count(Checkin.id).label("total"),
            func.avg(Checkin.weight_kg).label("avg_weight"),
            func.avg(Checkin.energy_level).label("avg_energy"),
            func.avg(Checkin.sleep_quality).label("avg_sleep"),
            func.avg(Checkin.mood).label("avg_mood"),
        ).where(Checkin.user_id == user_id)

        if start_date:
            query = query.where(Checkin.date >= start_date)
        if end_date:
            query = query.where(Checkin.date <= end_date)

        result = await self.db.execute(query)
        row = result.one()

        return {
            "total_checkins": row.total or 0,
            "avg_weight_kg": float(row.avg_weight) if row.avg_weight else None,
            "avg_energy": float(row.avg_energy) if row.avg_energy else None,
            "avg_sleep_quality": float(row.avg_sleep) if row.avg_sleep else None,
            "avg_mood": float(row.avg_mood) if row.avg_mood else None,
        }
