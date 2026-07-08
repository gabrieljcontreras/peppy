from datetime import datetime
from typing import Annotated, Optional
from uuid import UUID
from fastapi import APIRouter, Body, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.api.deps import CurrentUser
from app.services.protocol import ProtocolService
from app.api.schemas.protocol import (
    ProtocolCreate,
    ProtocolUpdate,
    ProtocolResponse,
    ProtocolCompoundsUpdate,
    StarterProtocolActivation,
    CompoundCreate,
    CompoundUpdate,
    CompoundResponse,
    MessageResponse,
)

router = APIRouter()


@router.get("/", response_model=list[ProtocolResponse])
async def list_protocols(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    include_inactive: bool = Query(True, description="Include inactive protocols"),
    limit: int = Query(50, ge=1, le=100, description="Maximum protocols to return"),
    offset: int = Query(0, ge=0, description="Number of protocols to skip"),
):
    """
    List all protocols for the authenticated user.

    Returns protocols ordered by start date (most recent first).
    By default includes both active and inactive protocols.
    """
    service = ProtocolService(db)
    protocols = await service.list_for_user(
        user_id=current_user.id,
        include_inactive=include_inactive,
        limit=limit,
        offset=offset,
    )
    return protocols


@router.post("/", response_model=ProtocolResponse, status_code=status.HTTP_201_CREATED)
async def create_protocol(
    protocol_data: ProtocolCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Create a new protocol.

    Creating a new protocol automatically deactivates any existing active
    protocol. This ensures there's always a clear "current" protocol.

    At least one compound is required. Each compound needs:
    - name: The peptide name (e.g., "Retatrutide")
    - dose_mg: The dose amount
    - frequency: How often taken (e.g., "weekly", "daily")
    """
    service = ProtocolService(db)

    try:
        compounds_data = [c.model_dump() for c in protocol_data.compounds]
        protocol = await service.create(
            user_id=current_user.id,
            name=protocol_data.name,
            start_date=protocol_data.start_date,
            end_date=protocol_data.end_date,
            compounds=compounds_data,
            notes=protocol_data.notes,
        )
        return protocol
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get("/active", response_model=Optional[ProtocolResponse])
async def get_active_protocol(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Get the user's currently active protocol.

    Returns null if no active protocol exists.
    """
    service = ProtocolService(db)
    protocol = await service.get_active(current_user.id)
    return protocol


@router.get("/{protocol_id}", response_model=ProtocolResponse)
async def get_protocol(
    protocol_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Get a specific protocol by ID.

    Only returns protocols owned by the authenticated user.
    """
    service = ProtocolService(db)
    protocol = await service.get_by_id(protocol_id, current_user.id)

    if not protocol:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Protocol not found",
        )

    return protocol


@router.patch("/{protocol_id}", response_model=ProtocolResponse)
async def update_protocol(
    protocol_id: UUID,
    update_data: ProtocolUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Update protocol metadata (name, dates, notes, active status).

    To update compounds, use the compounds endpoints instead.
    Setting is_active to true will deactivate any other active protocol.
    """
    service = ProtocolService(db)
    protocol = await service.get_by_id(protocol_id, current_user.id)

    if not protocol:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Protocol not found",
        )

    try:
        updated = await service.update(
            protocol,
            name=update_data.name,
            start_date=update_data.start_date,
            end_date=update_data.end_date,
            notes=update_data.notes,
            is_active=update_data.is_active,
        )
        return updated
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.put("/{protocol_id}/compounds", response_model=ProtocolResponse)
async def replace_compounds(
    protocol_id: UUID,
    compounds_data: ProtocolCompoundsUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Replace all compounds in a protocol.

    This is a full replacement - existing compounds are removed
    and replaced with the new list. Use this for major protocol
    changes like adding/removing peptides or restructuring doses.

    For single compound updates, use PATCH /compounds/{compound_id}.
    """
    service = ProtocolService(db)
    protocol = await service.get_by_id(protocol_id, current_user.id)

    if not protocol:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Protocol not found",
        )

    try:
        compounds_list = [c.model_dump() for c in compounds_data.compounds]
        updated = await service.update_compounds(protocol, compounds_list)
        return updated
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/{protocol_id}/compounds", response_model=CompoundResponse, status_code=status.HTTP_201_CREATED)
async def add_compound(
    protocol_id: UUID,
    compound_data: CompoundCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Add a new compound to an existing protocol.

    Use this when adding a new peptide to a stack without
    changing existing compounds.
    """
    service = ProtocolService(db)
    protocol = await service.get_by_id(protocol_id, current_user.id)

    if not protocol:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Protocol not found",
        )

    compound = await service.add_compound(
        protocol,
        name=compound_data.name,
        dose_mg=compound_data.dose_mg,
        dose_unit=compound_data.dose_unit,
        frequency=compound_data.frequency,
        administration_route=compound_data.administration_route,
        notes=compound_data.notes,
    )
    return compound


@router.patch("/compounds/{compound_id}", response_model=CompoundResponse)
async def update_compound(
    compound_id: UUID,
    update_data: CompoundUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Update a single compound's properties.

    Use this for dose adjustments, frequency changes, or
    updating notes on a specific compound.
    """
    service = ProtocolService(db)
    compound = await service.get_compound(compound_id, current_user.id)

    if not compound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Compound not found",
        )

    updated = await service.update_compound(
        compound,
        name=update_data.name,
        dose_mg=update_data.dose_mg,
        dose_unit=update_data.dose_unit,
        frequency=update_data.frequency,
        administration_route=update_data.administration_route,
        notes=update_data.notes,
    )
    return updated


@router.post("/{protocol_id}/activate", response_model=ProtocolResponse)
async def activate_protocol(
    protocol_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    activation_data: StarterProtocolActivation | None = Body(default=None),
):
    """
    Activate a protocol.

    Pending starter protocols may include setup payload fields for the initial
    dose, frequency, route, and start date before activation.
    """
    service = ProtocolService(db)
    protocol = await service.get_by_id(protocol_id, current_user.id)

    if not protocol:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Protocol not found",
        )

    try:
        if protocol.setup_status == "pending_setup":
            if activation_data is not None:
                protocol.start_date = _start_date_value(activation_data.start_date)
                for compound in protocol.compounds:
                    compound.dose_mg = activation_data.dose_mg
                    compound.dose_unit = activation_data.dose_unit
                    compound.frequency = activation_data.frequency
                    compound.administration_route = activation_data.administration_route
            return await service.activate_pending_protocol(protocol)

        return await service.update(protocol, is_active=True)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.delete("/compounds/{compound_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_compound(
    compound_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Remove a compound from its protocol.

    The protocol must have at least one remaining compound.
    """
    service = ProtocolService(db)
    compound = await service.get_compound(compound_id, current_user.id)

    if not compound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Compound not found",
        )

    # Load the protocol to check compound count
    protocol = await service.get_by_id(compound.protocol_id, current_user.id)
    if protocol and len(protocol.compounds) <= 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot remove the last compound. Delete the protocol instead.",
        )

    await service.remove_compound(compound)


@router.post("/{protocol_id}/deactivate", response_model=ProtocolResponse)
async def deactivate_protocol(
    protocol_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Deactivate (end) a protocol.

    Sets the protocol to inactive and sets end_date to today
    if not already set. Use this when finishing a protocol
    without deleting historical data.
    """
    service = ProtocolService(db)
    protocol = await service.get_by_id(protocol_id, current_user.id)

    if not protocol:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Protocol not found",
        )

    if not protocol.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Protocol is already inactive",
        )

    deactivated = await service.deactivate(protocol)
    return deactivated


@router.delete("/{protocol_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_protocol(
    protocol_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Permanently delete a protocol and all its compounds.

    This action cannot be undone. Consider using deactivate
    instead to preserve historical data.
    """
    service = ProtocolService(db)
    protocol = await service.get_by_id(protocol_id, current_user.id)

    if not protocol:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Protocol not found",
        )

    await service.delete(protocol)


def _start_date_value(value):
    if isinstance(value, datetime):
        return value.date()
    return value
