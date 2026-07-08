from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.dose_log import DoseLog
from app.models.protocol import Compound, Protocol


class DoseLogService:
    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def _normalize_input_administered_at(administered_at: datetime) -> datetime:
        if administered_at.tzinfo is None or administered_at.utcoffset() is None:
            raise ValueError("administered_at must include a timezone offset")
        return administered_at.astimezone(timezone.utc)

    @staticmethod
    def _restore_administered_at_from_db(administered_at: datetime) -> datetime:
        if administered_at.tzinfo is None or administered_at.utcoffset() is None:
            return administered_at.replace(tzinfo=timezone.utc)
        return administered_at.astimezone(timezone.utc)

    async def create(
        self,
        user_id: UUID,
        protocol_id: UUID,
        compound_id: UUID,
        dose: float,
        unit: str,
        administered_at: datetime,
        route: str,
        notes: str | None,
    ) -> DoseLog:
        if dose <= 0:
            raise ValueError("Dose must be greater than 0")

        protocol_result = await self.db.execute(
            select(Protocol).where(
                and_(
                    Protocol.id == protocol_id,
                    Protocol.user_id == user_id,
                )
            )
        )
        protocol = protocol_result.scalar_one_or_none()
        if protocol is None:
            raise ValueError("Protocol not found")

        compound_result = await self.db.execute(
            select(Compound)
            .join(Protocol)
            .where(
                and_(
                    Compound.id == compound_id,
                    Protocol.user_id == user_id,
                )
            )
        )
        compound = compound_result.scalar_one_or_none()
        if compound is None:
            raise ValueError("Compound not found")

        if compound.protocol_id != protocol.id:
            raise ValueError("Compound does not belong to protocol")

        administered_at = self._normalize_input_administered_at(administered_at)

        dose_log = DoseLog(
            user_id=user_id,
            protocol_id=protocol.id,
            compound_id=compound.id,
            dose=dose,
            unit=unit,
            administered_at=administered_at,
            route=route,
            notes=notes,
        )
        self.db.add(dose_log)
        await self.db.commit()
        await self.db.refresh(dose_log)
        dose_log.administered_at = self._restore_administered_at_from_db(dose_log.administered_at)
        return dose_log

    async def list_for_protocol(self, user_id: UUID, protocol_id: UUID) -> list[DoseLog] | None:
        protocol_result = await self.db.execute(
            select(Protocol.id).where(
                and_(
                    Protocol.id == protocol_id,
                    Protocol.user_id == user_id,
                )
            )
        )
        if protocol_result.scalar_one_or_none() is None:
            return None

        result = await self.db.execute(
            select(DoseLog)
            .where(
                and_(
                    DoseLog.user_id == user_id,
                    DoseLog.protocol_id == protocol_id,
                )
            )
            .order_by(DoseLog.administered_at.desc())
        )
        logs = list(result.scalars().all())
        for log in logs:
            log.administered_at = self._restore_administered_at_from_db(log.administered_at)
        return logs
