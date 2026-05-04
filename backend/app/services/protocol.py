from uuid import UUID
from datetime import date
from typing import Optional, Sequence
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.protocol import Protocol, Compound


class ProtocolService:
    """
    Service for managing user peptide protocols.

    A protocol represents a user's complete peptide regimen - the compounds
    they're taking, doses, frequencies, and timing. Users can have multiple
    protocols over time, but typically only one is active at any moment.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, protocol_id: UUID, user_id: UUID) -> Optional[Protocol]:
        """
        Get a protocol by ID, ensuring it belongs to the specified user.
        Eagerly loads compounds to avoid N+1 queries.
        """
        result = await self.db.execute(
            select(Protocol)
            .options(selectinload(Protocol.compounds))
            .where(
                and_(
                    Protocol.id == protocol_id,
                    Protocol.user_id == user_id,
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_active(self, user_id: UUID) -> Optional[Protocol]:
        """
        Get the user's currently active protocol.
        Returns None if no active protocol exists.
        """
        result = await self.db.execute(
            select(Protocol)
            .options(selectinload(Protocol.compounds))
            .where(
                and_(
                    Protocol.user_id == user_id,
                    Protocol.is_active == True,
                )
            )
            .order_by(Protocol.start_date.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def list_for_user(
        self,
        user_id: UUID,
        include_inactive: bool = True,
        limit: int = 50,
        offset: int = 0,
    ) -> Sequence[Protocol]:
        """
        List all protocols for a user, ordered by start date descending.
        """
        query = (
            select(Protocol)
            .options(selectinload(Protocol.compounds))
            .where(Protocol.user_id == user_id)
        )

        if not include_inactive:
            query = query.where(Protocol.is_active == True)

        query = query.order_by(Protocol.start_date.desc()).offset(offset).limit(limit)

        result = await self.db.execute(query)
        return result.scalars().all()

    async def create(
        self,
        user_id: UUID,
        name: str,
        start_date: date,
        compounds: list[dict],
        end_date: Optional[date] = None,
        notes: Optional[str] = None,
        deactivate_existing: bool = True,
    ) -> Protocol:
        """
        Create a new protocol for a user.

        By default, deactivates any existing active protocol. This ensures
        users have a clear "current" protocol at any time.

        Args:
            user_id: The user creating the protocol
            name: Human-readable name for this protocol
            start_date: When the protocol begins
            compounds: List of compound dicts with keys:
                - name: Compound name (e.g., "Retatrutide")
                - dose_mg: Dose amount
                - dose_unit: Unit (default "mg")
                - frequency: How often (e.g., "weekly")
                - administration_route: How administered (default "subcutaneous")
                - notes: Optional notes
            end_date: Optional planned end date
            notes: Optional notes about the protocol
            deactivate_existing: If True, deactivate current active protocol
        """
        if end_date and end_date < start_date:
            raise ValueError("End date cannot be before start date")

        if not compounds:
            raise ValueError("Protocol must have at least one compound")

        if deactivate_existing:
            await self._deactivate_active_protocols(user_id)

        protocol = Protocol(
            user_id=user_id,
            name=name,
            start_date=start_date,
            end_date=end_date,
            is_active=True,
            notes=notes,
        )

        for compound_data in compounds:
            compound = Compound(
                name=compound_data["name"],
                dose_mg=compound_data["dose_mg"],
                dose_unit=compound_data.get("dose_unit", "mg"),
                frequency=compound_data["frequency"],
                administration_route=compound_data.get("administration_route", "subcutaneous"),
                notes=compound_data.get("notes"),
            )
            protocol.compounds.append(compound)

        self.db.add(protocol)
        await self.db.commit()
        await self.db.refresh(protocol)

        # Reload with compounds
        return await self.get_by_id(protocol.id, user_id)

    async def update(
        self,
        protocol: Protocol,
        name: Optional[str] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        notes: Optional[str] = None,
        is_active: Optional[bool] = None,
    ) -> Protocol:
        """
        Update protocol metadata (not compounds).
        For compound changes, use update_compounds().
        """
        if name is not None:
            protocol.name = name
        if start_date is not None:
            protocol.start_date = start_date
        if end_date is not None:
            protocol.end_date = end_date
        if notes is not None:
            protocol.notes = notes
        if is_active is not None:
            if is_active and not protocol.is_active:
                # Reactivating - deactivate others first
                await self._deactivate_active_protocols(protocol.user_id)
            protocol.is_active = is_active

        # Validate dates
        if protocol.end_date and protocol.end_date < protocol.start_date:
            raise ValueError("End date cannot be before start date")

        await self.db.commit()
        await self.db.refresh(protocol)
        return protocol

    async def update_compounds(
        self,
        protocol: Protocol,
        compounds: list[dict],
    ) -> Protocol:
        """
        Replace all compounds in a protocol with new ones.

        This is a full replacement - existing compounds are deleted
        and new ones are created. For dose adjustments over time,
        consider creating a new protocol or using the notes field
        to document changes.
        """
        if not compounds:
            raise ValueError("Protocol must have at least one compound")

        # Remove existing compounds
        for compound in protocol.compounds:
            await self.db.delete(compound)

        # Add new compounds
        for compound_data in compounds:
            compound = Compound(
                protocol_id=protocol.id,
                name=compound_data["name"],
                dose_mg=compound_data["dose_mg"],
                dose_unit=compound_data.get("dose_unit", "mg"),
                frequency=compound_data["frequency"],
                administration_route=compound_data.get("administration_route", "subcutaneous"),
                notes=compound_data.get("notes"),
            )
            self.db.add(compound)

        await self.db.commit()
        return await self.get_by_id(protocol.id, protocol.user_id)

    async def add_compound(
        self,
        protocol: Protocol,
        name: str,
        dose_mg: float,
        frequency: str,
        dose_unit: str = "mg",
        administration_route: str = "subcutaneous",
        notes: Optional[str] = None,
    ) -> Compound:
        """Add a single compound to an existing protocol."""
        compound = Compound(
            protocol_id=protocol.id,
            name=name,
            dose_mg=dose_mg,
            dose_unit=dose_unit,
            frequency=frequency,
            administration_route=administration_route,
            notes=notes,
        )
        self.db.add(compound)
        await self.db.commit()
        await self.db.refresh(compound)
        return compound

    async def update_compound(
        self,
        compound: Compound,
        name: Optional[str] = None,
        dose_mg: Optional[float] = None,
        dose_unit: Optional[str] = None,
        frequency: Optional[str] = None,
        administration_route: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> Compound:
        """Update a single compound's properties."""
        if name is not None:
            compound.name = name
        if dose_mg is not None:
            compound.dose_mg = dose_mg
        if dose_unit is not None:
            compound.dose_unit = dose_unit
        if frequency is not None:
            compound.frequency = frequency
        if administration_route is not None:
            compound.administration_route = administration_route
        if notes is not None:
            compound.notes = notes

        await self.db.commit()
        await self.db.refresh(compound)
        return compound

    async def remove_compound(self, compound: Compound) -> None:
        """Remove a compound from a protocol."""
        await self.db.delete(compound)
        await self.db.commit()

    async def get_compound(
        self,
        compound_id: UUID,
        user_id: UUID,
    ) -> Optional[Compound]:
        """
        Get a compound by ID, ensuring it belongs to a protocol owned by the user.
        """
        result = await self.db.execute(
            select(Compound)
            .join(Protocol)
            .where(
                and_(
                    Compound.id == compound_id,
                    Protocol.user_id == user_id,
                )
            )
        )
        return result.scalar_one_or_none()

    async def deactivate(self, protocol: Protocol) -> Protocol:
        """
        Deactivate a protocol (end it).
        Sets is_active to False and end_date to today if not set.
        """
        protocol.is_active = False
        if not protocol.end_date:
            protocol.end_date = date.today()
        await self.db.commit()
        await self.db.refresh(protocol)
        return protocol

    async def delete(self, protocol: Protocol) -> None:
        """
        Permanently delete a protocol and all its compounds.
        Use with caution - prefer deactivate() to preserve history.
        """
        await self.db.delete(protocol)
        await self.db.commit()

    async def _deactivate_active_protocols(self, user_id: UUID) -> None:
        """Deactivate all active protocols for a user."""
        result = await self.db.execute(
            select(Protocol).where(
                and_(
                    Protocol.user_id == user_id,
                    Protocol.is_active == True,
                )
            )
        )
        active_protocols = result.scalars().all()
        for protocol in active_protocols:
            protocol.is_active = False
            if not protocol.end_date:
                protocol.end_date = date.today()
        await self.db.flush()
