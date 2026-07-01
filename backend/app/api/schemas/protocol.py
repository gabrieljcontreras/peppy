from uuid import UUID
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, Field, field_validator
from enum import Enum


class Frequency(str, Enum):
    """Standard dosing frequencies for peptides."""
    DAILY = "daily"
    EVERY_OTHER_DAY = "every_other_day"
    TWICE_WEEKLY = "twice_weekly"
    WEEKLY = "weekly"
    EVERY_10_DAYS = "every_10_days"
    BIWEEKLY = "biweekly"
    MONTHLY = "monthly"
    CUSTOM = "custom"


class AdministrationRoute(str, Enum):
    """How the peptide is administered."""
    SUBCUTANEOUS = "subcutaneous"
    INTRAMUSCULAR = "intramuscular"
    ORAL = "oral"
    NASAL = "nasal"
    OTHER = "other"


class ProtocolSetupStatus(str, Enum):
    """Setup lifecycle for protocols derived from onboarding."""
    PENDING_SETUP = "pending_setup"
    ACTIVE = "active"
    INACTIVE = "inactive"


class CompoundBase(BaseModel):
    """Base compound fields shared across create/update/response."""
    name: str = Field(
        min_length=1,
        max_length=100,
        description="Peptide name (e.g., 'Retatrutide', 'Semaglutide')",
        examples=["Retatrutide", "Semaglutide", "Tirzepatide"],
    )
    dose_mg: float = Field(
        gt=0,
        description="Dose amount in the specified unit",
        examples=[2.5, 5.0, 10.0],
    )
    dose_unit: str = Field(
        default="mg",
        max_length=20,
        description="Unit of measurement",
        examples=["mg", "mcg", "IU"],
    )
    frequency: str = Field(
        description="How often the compound is taken",
        examples=["weekly", "daily", "every_other_day"],
    )
    administration_route: str = Field(
        default="subcutaneous",
        description="How the compound is administered",
        examples=["subcutaneous", "intramuscular", "oral"],
    )
    notes: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Additional notes about this compound",
    )


class CompoundCreate(CompoundBase):
    """Schema for creating a new compound within a protocol."""
    pass


class CompoundUpdate(BaseModel):
    """Schema for updating an existing compound. All fields optional."""
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    dose_mg: Optional[float] = Field(default=None, gt=0)
    dose_unit: Optional[str] = Field(default=None, max_length=20)
    frequency: Optional[str] = Field(default=None)
    administration_route: Optional[str] = Field(default=None)
    notes: Optional[str] = Field(default=None, max_length=1000)


class CompoundResponse(CompoundBase):
    """Schema for compound in API responses."""
    id: UUID
    dose_mg: float = Field(
        ge=0,
        description="Dose amount in the specified unit. Pending setup compounds may be 0.",
        examples=[0, 2.5, 5.0],
    )
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class PendingCompoundResponse(BaseModel):
    """Schema for compounds that still need starter protocol setup."""
    id: UUID
    name: str
    dose_mg: float
    dose_unit: str
    frequency: str
    administration_route: str
    notes: Optional[str]

    class Config:
        from_attributes = True


class ProtocolCreate(BaseModel):
    """Schema for creating a new protocol."""
    name: str = Field(
        min_length=1,
        max_length=200,
        description="Human-readable name for this protocol",
        examples=["Retatrutide Titration", "GLP-1 Maintenance", "Summer Cut Protocol"],
    )
    start_date: date = Field(
        description="When the protocol begins",
    )
    end_date: Optional[date] = Field(
        default=None,
        description="Planned end date (optional)",
    )
    compounds: list[CompoundCreate] = Field(
        min_length=1,
        description="List of compounds in this protocol (at least one required)",
    )
    notes: Optional[str] = Field(
        default=None,
        max_length=2000,
        description="Notes about this protocol",
    )

    @field_validator("end_date")
    @classmethod
    def end_date_after_start(cls, v: Optional[date], info) -> Optional[date]:
        if v is not None and "start_date" in info.data:
            if v < info.data["start_date"]:
                raise ValueError("End date must be after start date")
        return v


class ProtocolUpdate(BaseModel):
    """Schema for updating protocol metadata. Compounds updated separately."""
    name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    start_date: Optional[date] = Field(default=None)
    end_date: Optional[date] = Field(default=None)
    notes: Optional[str] = Field(default=None, max_length=2000)
    is_active: Optional[bool] = Field(default=None)


class ProtocolCompoundsUpdate(BaseModel):
    """Schema for replacing all compounds in a protocol."""
    compounds: list[CompoundCreate] = Field(
        min_length=1,
        description="New list of compounds (replaces existing)",
    )


class StarterProtocolActivation(BaseModel):
    """Schema for completing and activating a pending starter protocol."""
    dose_mg: float = Field(gt=0)
    dose_unit: str = Field(default="mg", max_length=20)
    frequency: str = Field(min_length=1)
    administration_route: str = Field(min_length=1)
    start_date: date | datetime


class ProtocolResponse(BaseModel):
    """Schema for protocol in API responses."""
    id: UUID
    name: str
    start_date: date
    end_date: Optional[date]
    is_active: bool
    setup_status: str = "active"
    is_starter: bool = False
    notes: Optional[str]
    compounds: list[CompoundResponse]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ProtocolSummary(BaseModel):
    """Lightweight protocol response without full compound details."""
    id: UUID
    name: str
    start_date: date
    end_date: Optional[date]
    is_active: bool
    compound_count: int
    created_at: datetime

    class Config:
        from_attributes = True


class ProtocolListResponse(BaseModel):
    """Paginated list of protocols."""
    protocols: list[ProtocolResponse]
    total: int
    limit: int
    offset: int


class MessageResponse(BaseModel):
    """Generic message response."""
    message: str
