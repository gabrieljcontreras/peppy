from uuid import UUID
from datetime import date as date_type, datetime
from typing import Optional
from pydantic import BaseModel, Field


class LabMarkerBase(BaseModel):
    """Base lab marker fields."""
    name: str = Field(
        min_length=1,
        max_length=100,
        description="Marker name (e.g., 'HbA1c', 'ALT', 'TSH')",
        examples=["HbA1c", "fasting_glucose", "ALT", "TSH"],
    )
    value: float = Field(description="The measured value")
    unit: str = Field(
        max_length=30,
        description="Unit of measurement",
        examples=["mg/dL", "U/L", "%", "mIU/L"],
    )
    reference_low: Optional[float] = Field(
        default=None,
        description="Lower bound of reference range",
    )
    reference_high: Optional[float] = Field(
        default=None,
        description="Upper bound of reference range",
    )


class LabMarkerCreate(LabMarkerBase):
    """Schema for creating a lab marker."""
    pass


class LabMarkerResponse(LabMarkerBase):
    """Schema for lab marker in API responses."""
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class LabResultBase(BaseModel):
    """Base lab result fields."""
    date: date_type = Field(description="Date the labs were drawn")
    panel_type: str = Field(
        min_length=1,
        max_length=50,
        description="Type of lab panel",
        examples=["metabolic", "lipid", "hormone", "liver", "kidney", "thyroid"],
    )
    lab_name: Optional[str] = Field(
        default=None,
        max_length=200,
        description="Name of the lab facility",
    )
    notes: Optional[str] = Field(
        default=None,
        max_length=2000,
        description="Additional notes",
    )


class LabResultCreate(LabResultBase):
    """Schema for creating a lab result with markers."""
    markers: list[LabMarkerCreate] = Field(
        min_length=1,
        description="Lab markers in this result (at least one required)",
    )


class LabResultUpdate(BaseModel):
    """Schema for updating lab result metadata."""
    date: Optional[date_type] = Field(default=None)
    panel_type: Optional[str] = Field(default=None, min_length=1, max_length=50)
    lab_name: Optional[str] = Field(default=None, max_length=200)
    notes: Optional[str] = Field(default=None, max_length=2000)


class LabResultResponse(LabResultBase):
    """Schema for lab result in API responses."""
    id: UUID
    user_id: UUID
    markers: list[LabMarkerResponse]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class LabMarkersUpdate(BaseModel):
    """Schema for replacing all markers in a lab result."""
    markers: list[LabMarkerCreate] = Field(
        min_length=1,
        description="New list of markers (replaces existing)",
    )


class MarkerHistoryPoint(BaseModel):
    """A single point in marker history."""
    date: date_type
    value: float
    unit: str
    reference_low: Optional[float]
    reference_high: Optional[float]


class MarkerHistoryResponse(BaseModel):
    """History of a specific marker over time."""
    marker_name: str
    history: list[MarkerHistoryPoint]
