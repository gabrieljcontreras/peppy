from uuid import UUID
from datetime import date
from typing import Optional, Sequence
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.lab import LabResult, LabMarker


class LabService:
    """
    Service for managing user lab results.

    Lab results contain panels of markers (e.g., metabolic panel, lipid panel)
    that users manually enter to track how their protocols affect their health.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, lab_id: UUID, user_id: UUID) -> Optional[LabResult]:
        """Get a lab result by ID, ensuring it belongs to the specified user."""
        result = await self.db.execute(
            select(LabResult)
            .options(selectinload(LabResult.markers))
            .where(
                and_(
                    LabResult.id == lab_id,
                    LabResult.user_id == user_id,
                )
            )
        )
        return result.scalar_one_or_none()

    async def list_for_user(
        self,
        user_id: UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        panel_type: Optional[str] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> Sequence[LabResult]:
        """
        List lab results for a user, ordered by date descending.
        Optionally filter by date range and panel type.
        """
        query = (
            select(LabResult)
            .options(selectinload(LabResult.markers))
            .where(LabResult.user_id == user_id)
        )

        if start_date:
            query = query.where(LabResult.date >= start_date)
        if end_date:
            query = query.where(LabResult.date <= end_date)
        if panel_type:
            query = query.where(LabResult.panel_type == panel_type)

        query = query.order_by(LabResult.date.desc()).offset(offset).limit(limit)

        result = await self.db.execute(query)
        return result.scalars().all()

    async def create(
        self,
        user_id: UUID,
        lab_date: date,
        panel_type: str,
        markers: list[dict],
        lab_name: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> LabResult:
        """
        Create a new lab result with markers.

        Args:
            user_id: The user creating the lab result
            lab_date: Date the labs were drawn
            panel_type: Type of panel (metabolic, lipid, etc.)
            markers: List of marker dicts with keys:
                - name: Marker name (e.g., "HbA1c")
                - value: Measured value
                - unit: Unit of measurement
                - reference_low: Optional lower bound
                - reference_high: Optional upper bound
            lab_name: Optional name of lab facility
            notes: Optional notes
        """
        if not markers:
            raise ValueError("Lab result must have at least one marker")

        lab_result = LabResult(
            user_id=user_id,
            date=lab_date,
            panel_type=panel_type,
            lab_name=lab_name,
            notes=notes,
        )

        for marker_data in markers:
            marker = LabMarker(
                name=marker_data["name"],
                value=marker_data["value"],
                unit=marker_data["unit"],
                reference_low=marker_data.get("reference_low"),
                reference_high=marker_data.get("reference_high"),
            )
            lab_result.markers.append(marker)

        self.db.add(lab_result)
        await self.db.commit()
        await self.db.refresh(lab_result)

        return await self.get_by_id(lab_result.id, user_id)

    async def update(
        self,
        lab_result: LabResult,
        lab_date: Optional[date] = None,
        panel_type: Optional[str] = None,
        lab_name: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> LabResult:
        """Update lab result metadata (not markers)."""
        if lab_date is not None:
            lab_result.date = lab_date
        if panel_type is not None:
            lab_result.panel_type = panel_type
        if lab_name is not None:
            lab_result.lab_name = lab_name
        if notes is not None:
            lab_result.notes = notes

        await self.db.commit()
        await self.db.refresh(lab_result)
        return lab_result

    async def update_markers(
        self,
        lab_result: LabResult,
        markers: list[dict],
    ) -> LabResult:
        """
        Replace all markers in a lab result with new ones.
        """
        if not markers:
            raise ValueError("Lab result must have at least one marker")

        lab_result.markers.clear()
        await self.db.flush()

        for marker_data in markers:
            marker = LabMarker(
                lab_result_id=lab_result.id,
                name=marker_data["name"],
                value=marker_data["value"],
                unit=marker_data["unit"],
                reference_low=marker_data.get("reference_low"),
                reference_high=marker_data.get("reference_high"),
            )
            lab_result.markers.append(marker)

        await self.db.commit()
        return await self.get_by_id(lab_result.id, lab_result.user_id)

    async def delete(self, lab_result: LabResult) -> None:
        """Delete a lab result and all its markers."""
        await self.db.delete(lab_result)
        await self.db.commit()

    async def get_marker_history(
        self,
        user_id: UUID,
        marker_name: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
    ) -> list[dict]:
        """
        Get the history of a specific marker across all lab results.
        Returns list of dicts with date, value, unit, and reference range.
        """
        query = (
            select(
                LabResult.date,
                LabMarker.value,
                LabMarker.unit,
                LabMarker.reference_low,
                LabMarker.reference_high,
            )
            .join(LabMarker)
            .where(
                and_(
                    LabResult.user_id == user_id,
                    LabMarker.name == marker_name,
                )
            )
        )

        if start_date:
            query = query.where(LabResult.date >= start_date)
        if end_date:
            query = query.where(LabResult.date <= end_date)

        query = query.order_by(LabResult.date.asc())

        result = await self.db.execute(query)
        return [
            {
                "date": row[0],
                "value": row[1],
                "unit": row[2],
                "reference_low": row[3],
                "reference_high": row[4],
            }
            for row in result.all()
        ]

    async def get_distinct_marker_names(self, user_id: UUID) -> list[str]:
        """Get all unique marker names the user has recorded."""
        query = (
            select(LabMarker.name)
            .join(LabResult)
            .where(LabResult.user_id == user_id)
            .distinct()
            .order_by(LabMarker.name)
        )
        result = await self.db.execute(query)
        return [row[0] for row in result.all()]
