# Peppy iOS Dashboard Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Peppy's first real iOS Home dashboard slice with backend profile persistence, pending starter protocol setup, daily check-ins, lightweight insights, and connected-context utility.

**Architecture:** The backend owns durable onboarding profile persistence, pending starter protocol derivation, and a read-only dashboard summary endpoint. The iOS app attaches the local onboarding draft after auth, opens Home immediately, and renders dashboard state from real API contracts with mock fallbacks for previews and tests.

**Tech Stack:** FastAPI, SQLAlchemy, Alembic, Pydantic, pytest, Swift 6, SwiftUI, Observation, XCTest, URLSession-backed `APIClientProtocol`.

---

## Source Material

- Approved design spec: `ios/peppy/docs/superpowers/specs/2026-06-30-ios-dashboard-vertical-slice-design.md`
- Existing iOS backend contract: `ios/peppy/BACKEND.md`
- iOS engineering guide: `ios/AGENTS.md`
- Figma source: `/Users/gabrielcontreras/Downloads/Peppy IOS.fig`

## Execution Notes

- Do not commit unless Gabriel explicitly asks. Stage only when asked.
- Preserve the existing unstaged Xcode workspace UI state file:
  `ios/peppy/peppy.xcodeproj/project.xcworkspace/xcuserdata/gabrielcontreras.xcuserdatad/UserInterfaceState.xcuserstate`.
- Use TDD for backend services/routes and iOS view models.
- Use `superpowers:systematic-debugging` before fixing any failing test or unexpected runtime behavior.
- Prefer subagent-driven execution because backend and iOS tasks have clear review checkpoints.

## Progress Checkpoint - 2026-06-30

Current branch: `IOS_iniitial_dashboard_dev`.

Task 1, backend onboarding profile persistence, has been implemented and locally verified. Do not reimplement it on resume unless a fresh test failure points to a concrete regression.

Implemented Task 1 files:

```text
backend/app/models/profile.py
backend/app/api/schemas/profile.py
backend/app/services/profile.py
backend/app/api/routes/profile.py
backend/tests/test_profile_service.py
backend/tests/test_profile_routes.py
backend/alembic/versions/b4c5d6e7f8a9_onboarding_profile_dashboard_slice.py
backend/app/models/__init__.py
backend/app/models/user.py
backend/app/main.py
backend/requirements.txt
.gitignore
```

Important Task 1 details:

- Attach endpoint body uses `profile`, not `profile_payload`.
- Attach envelope and nested profile both validate `schema_version == 1`.
- Attach envelope forbids unexpected top-level fields.
- Lists dedupe case-insensitively while preserving the first display value.
- Existing-profile attach fills only empty fields when a different draft is attached.
- `greenlet==3.0.3` was added because SQLAlchemy async tests require it.

Verification already run:

```bash
cd backend
.venv/bin/python -m pytest tests/test_profile_service.py tests/test_profile_routes.py tests/test_protocol_service.py tests/test_user_service.py -q
# 43 passed
```

Full backend suite baseline after Task 1 was `103 passed, 4 failed`; the failures are existing auth expectation drift, not profile persistence.

Resume at Task 2: Backend Pending Starter Protocol State.

## File Map

### Backend Create

```text
backend/app/models/profile.py
backend/app/api/schemas/profile.py
backend/app/api/schemas/dashboard.py
backend/app/services/profile.py
backend/app/services/dashboard.py
backend/app/api/routes/profile.py
backend/app/api/routes/dashboard.py
backend/alembic/versions/b4c5d6e7f8a9_onboarding_profile_dashboard_slice.py
backend/tests/test_profile_service.py
backend/tests/test_profile_routes.py
backend/tests/test_dashboard_service.py
backend/tests/test_dashboard_routes.py
```

### Backend Modify

```text
backend/app/main.py
backend/app/models/__init__.py
backend/app/models/user.py
backend/app/models/protocol.py
backend/app/api/schemas/protocol.py
backend/app/api/routes/protocols.py
backend/app/services/protocol.py
```

### iOS Create

```text
ios/peppy/Features/Dashboard/Models/DashboardModels.swift
ios/peppy/Features/Dashboard/ViewModels/DashboardViewModel.swift
ios/peppy/Features/Dashboard/Views/DashboardView.swift
ios/peppy/Features/Dashboard/Views/DashboardCards.swift
ios/peppy/Features/Protocols/ViewModels/StarterProtocolViewModel.swift
ios/peppy/Features/Protocols/Views/StarterProtocolSetupView.swift
ios/peppy/peppyTests/DashboardViewModelTests.swift
ios/peppy/peppyTests/StarterProtocolViewModelTests.swift
ios/peppy/peppyTests/ProfileAttachTests.swift
```

### iOS Modify

```text
ios/peppy/Core/Network/APIModels.swift
ios/peppy/Core/Network/Endpoint.swift
ios/peppy/Core/Network/MockAPIClient.swift
ios/peppy/App/AppFlowCoordinator.swift
ios/peppy/App/MainTabView.swift
ios/peppy/App/Dependencies.swift
ios/peppy/Features/Auth/Views/LoginView.swift
ios/peppy/Features/Auth/Views/RegisterView.swift
ios/peppy/Features/Onboarding/Models/OnboardingDraft.swift
```

## Task 1: Backend Onboarding Profile Persistence

**Files:**
- Create: `backend/app/models/profile.py`
- Create: `backend/app/api/schemas/profile.py`
- Create: `backend/app/services/profile.py`
- Create: `backend/app/api/routes/profile.py`
- Create: `backend/tests/test_profile_service.py`
- Create: `backend/tests/test_profile_routes.py`
- Modify: `backend/app/models/__init__.py`
- Modify: `backend/app/models/user.py`
- Modify: `backend/app/main.py`
- Create: `backend/alembic/versions/b4c5d6e7f8a9_onboarding_profile_dashboard_slice.py`

- [ ] **Step 1: Write service tests for profile create, patch, and attach**

Create `backend/tests/test_profile_service.py`:

```python
import pytest
from datetime import datetime, timezone

from app.services.user import UserService
from app.services.profile import OnboardingProfileService


@pytest.fixture
async def user(db_session):
    return await UserService(db_session).create(
        email="profile@example.com",
        password="password123",
    )


@pytest.fixture
def profile_payload():
    return {
        "schema_version": 1,
        "age": 32,
        "height_cm": 172.72,
        "preferred_height_unit": "ft_in",
        "weight_kg": 74.84,
        "preferred_weight_unit": "lb",
        "peptides": ["Retatrutide"],
        "custom_peptides": [],
        "other_medications": "Metformin",
        "workout_days_per_week": 3,
        "goals": ["track_protocols", "see_what_works"],
        "custom_goal": None,
        "healthkit": {"requested": True, "last_sync_at": None},
        "notifications": {"authorized": True},
    }


async def test_put_profile_creates_user_profile(db_session, user, profile_payload):
    service = OnboardingProfileService(db_session)

    profile = await service.put_profile(user.id, profile_payload)

    assert profile.user_id == user.id
    assert profile.schema_version == 1
    assert profile.age == 32
    assert profile.peptides == ["Retatrutide"]
    assert profile.goals == ["track_protocols", "see_what_works"]


async def test_patch_profile_updates_only_supplied_fields(db_session, user, profile_payload):
    service = OnboardingProfileService(db_session)
    await service.put_profile(user.id, profile_payload)

    profile = await service.patch_profile(
        user.id,
        {"weight_kg": 73.94, "goals": ["optimize_recovery"]},
    )

    assert profile.age == 32
    assert profile.weight_kg == 73.94
    assert profile.goals == ["optimize_recovery"]


async def test_attach_profile_is_idempotent_for_same_draft(db_session, user, profile_payload):
    service = OnboardingProfileService(db_session)
    draft_id = "6f3950d8-5aa8-4476-a2eb-2c967196cff9"

    first = await service.attach_profile(
        user_id=user.id,
        draft_id=draft_id,
        draft_created_at=datetime(2026, 6, 30, 12, 0, tzinfo=timezone.utc),
        draft_updated_at=datetime(2026, 6, 30, 12, 5, tzinfo=timezone.utc),
        is_complete=True,
        current_step="notifications",
        profile_payload=profile_payload,
    )
    second = await service.attach_profile(
        user_id=user.id,
        draft_id=draft_id,
        draft_created_at=datetime(2026, 6, 30, 12, 0, tzinfo=timezone.utc),
        draft_updated_at=datetime(2026, 6, 30, 12, 5, tzinfo=timezone.utc),
        is_complete=True,
        current_step="notifications",
        profile_payload=profile_payload,
    )

    assert first.id == second.id
    assert second.peptides == ["Retatrutide"]
```

- [ ] **Step 2: Run profile service tests and verify failure**

Run:

```bash
cd backend
pytest tests/test_profile_service.py -q
```

Expected: import failure because `app.services.profile` does not exist.

- [ ] **Step 3: Implement profile model**

Create `backend/app/models/profile.py`:

```python
from sqlalchemy import Column, Integer, Float, String, Boolean, DateTime, ForeignKey, JSON, UniqueConstraint
from sqlalchemy.orm import relationship

from app.models.base import Base, UUIDMixin, TimestampMixin, GUID


class OnboardingProfile(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "onboarding_profiles"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, unique=True, index=True)
    schema_version = Column(Integer, nullable=False, default=1)
    age = Column(Integer, nullable=True)
    height_cm = Column(Float, nullable=True)
    preferred_height_unit = Column(String(20), nullable=True)
    weight_kg = Column(Float, nullable=True)
    preferred_weight_unit = Column(String(20), nullable=True)
    peptides = Column(JSON, nullable=False, default=list)
    custom_peptides = Column(JSON, nullable=False, default=list)
    other_medications = Column(String(200), nullable=True)
    workout_days_per_week = Column(Integer, nullable=True)
    goals = Column(JSON, nullable=False, default=list)
    custom_goal = Column(String(200), nullable=True)
    healthkit_requested = Column(Boolean, nullable=True)
    healthkit_last_sync_at = Column(DateTime(timezone=True), nullable=True)
    notifications_authorized = Column(Boolean, nullable=True)
    source_draft_id = Column(String(64), nullable=True)
    source_draft_created_at = Column(DateTime(timezone=True), nullable=True)
    source_draft_updated_at = Column(DateTime(timezone=True), nullable=True)
    source_current_step = Column(String(50), nullable=True)
    source_is_complete = Column(Boolean, nullable=False, default=False)

    user = relationship("User", back_populates="onboarding_profile")

    __table_args__ = (
        UniqueConstraint("user_id", name="uq_onboarding_profiles_user_id"),
    )
```

Modify `backend/app/models/user.py`:

```python
    onboarding_profile = relationship("OnboardingProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")
```

Modify `backend/app/models/__init__.py` to import and export `OnboardingProfile`.

- [ ] **Step 4: Implement profile schemas**

Create `backend/app/api/schemas/profile.py` with enums, nested permission objects, request payloads, and response shape:

```python
from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, field_validator


class HealthKitProfile(BaseModel):
    requested: bool
    last_sync_at: Optional[datetime] = None


class NotificationProfile(BaseModel):
    authorized: bool


class OnboardingProfilePayload(BaseModel):
    schema_version: int = Field(1)
    age: Optional[int] = Field(default=None, ge=13, le=120)
    height_cm: Optional[float] = Field(default=None, ge=100, le=250)
    preferred_height_unit: Optional[str] = Field(default=None, pattern="^(ft_in|cm)$")
    weight_kg: Optional[float] = Field(default=None, ge=27, le=318)
    preferred_weight_unit: Optional[str] = Field(default=None, pattern="^(lb|kg)$")
    peptides: list[str] = Field(default_factory=list)
    custom_peptides: list[str] = Field(default_factory=list, max_length=20)
    other_medications: Optional[str] = Field(default=None, max_length=200)
    workout_days_per_week: Optional[int] = Field(default=None, ge=0, le=7)
    goals: list[str] = Field(default_factory=list)
    custom_goal: Optional[str] = Field(default=None, max_length=200)
    healthkit: Optional[HealthKitProfile] = None
    notifications: Optional[NotificationProfile] = None

    @field_validator("schema_version")
    @classmethod
    def supported_schema_version(cls, value: int) -> int:
        if value != 1:
            raise ValueError("Only schema_version 1 is supported")
        return value

    @field_validator("peptides", "custom_peptides", "goals")
    @classmethod
    def trim_unique_values(cls, values: list[str]) -> list[str]:
        unique: list[str] = []
        seen: set[str] = set()
        for raw in values:
            value = raw.strip()
            key = value.casefold()
            if value and key not in seen:
                unique.append(value)
                seen.add(key)
        return unique


class OnboardingProfilePatch(BaseModel):
    age: Optional[int] = Field(default=None, ge=13, le=120)
    height_cm: Optional[float] = Field(default=None, ge=100, le=250)
    preferred_height_unit: Optional[str] = Field(default=None, pattern="^(ft_in|cm)$")
    weight_kg: Optional[float] = Field(default=None, ge=27, le=318)
    preferred_weight_unit: Optional[str] = Field(default=None, pattern="^(lb|kg)$")
    peptides: Optional[list[str]] = None
    custom_peptides: Optional[list[str]] = Field(default=None, max_length=20)
    other_medications: Optional[str] = Field(default=None, max_length=200)
    workout_days_per_week: Optional[int] = Field(default=None, ge=0, le=7)
    goals: Optional[list[str]] = None
    custom_goal: Optional[str] = Field(default=None, max_length=200)
    healthkit: Optional[HealthKitProfile] = None
    notifications: Optional[NotificationProfile] = None


class OnboardingProfileAttach(BaseModel):
    schema_version: int = Field(1)
    draft_id: str = Field(min_length=1, max_length=64)
    draft_created_at: datetime
    draft_updated_at: datetime
    is_complete: bool
    current_step: str = Field(min_length=1, max_length=50)
    profile: OnboardingProfilePayload


class OnboardingProfileResponse(OnboardingProfilePayload):
    id: UUID
    user_id: UUID
    updated_at: datetime

    model_config = {"from_attributes": True}
```

- [ ] **Step 5: Implement profile service**

Create `backend/app/services/profile.py` with conversion helpers and CRUD:

```python
from datetime import datetime
from typing import Any, Optional
from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.profile import OnboardingProfile


class OnboardingProfileService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_for_user(self, user_id: UUID) -> Optional[OnboardingProfile]:
        result = await self.db.execute(
            select(OnboardingProfile).where(OnboardingProfile.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def put_profile(self, user_id: UUID, payload: dict[str, Any]) -> OnboardingProfile:
        profile = await self.get_for_user(user_id)
        if profile is None:
            profile = OnboardingProfile(user_id=user_id)
            self.db.add(profile)
        self._apply_payload(profile, payload, replace=True)
        await self.db.commit()
        await self.db.refresh(profile)
        return profile

    async def patch_profile(self, user_id: UUID, patch: dict[str, Any]) -> OnboardingProfile:
        profile = await self.get_for_user(user_id)
        if profile is None:
            profile = OnboardingProfile(user_id=user_id)
            self.db.add(profile)
        self._apply_payload(profile, patch, replace=False)
        await self.db.commit()
        await self.db.refresh(profile)
        return profile

    async def attach_profile(
        self,
        user_id: UUID,
        draft_id: str,
        draft_created_at: datetime,
        draft_updated_at: datetime,
        is_complete: bool,
        current_step: str,
        profile_payload: dict[str, Any],
    ) -> OnboardingProfile:
        profile = await self.get_for_user(user_id)
        if profile is not None and profile.source_draft_id == draft_id:
            return profile
        if profile is None:
            profile = OnboardingProfile(user_id=user_id)
            self.db.add(profile)
            self._apply_payload(profile, profile_payload, replace=True)
        else:
            self._fill_empty_fields(profile, profile_payload)
        profile.source_draft_id = draft_id
        profile.source_draft_created_at = draft_created_at
        profile.source_draft_updated_at = draft_updated_at
        profile.source_is_complete = is_complete
        profile.source_current_step = current_step
        await self.db.commit()
        await self.db.refresh(profile)
        return profile

    def to_payload(self, profile: OnboardingProfile) -> dict[str, Any]:
        return {
            "id": profile.id,
            "user_id": profile.user_id,
            "schema_version": profile.schema_version,
            "age": profile.age,
            "height_cm": profile.height_cm,
            "preferred_height_unit": profile.preferred_height_unit,
            "weight_kg": profile.weight_kg,
            "preferred_weight_unit": profile.preferred_weight_unit,
            "peptides": profile.peptides or [],
            "custom_peptides": profile.custom_peptides or [],
            "other_medications": profile.other_medications,
            "workout_days_per_week": profile.workout_days_per_week,
            "goals": profile.goals or [],
            "custom_goal": profile.custom_goal,
            "healthkit": None if profile.healthkit_requested is None else {
                "requested": profile.healthkit_requested,
                "last_sync_at": profile.healthkit_last_sync_at,
            },
            "notifications": None if profile.notifications_authorized is None else {
                "authorized": profile.notifications_authorized,
            },
            "updated_at": profile.updated_at,
        }

    def _apply_payload(self, profile: OnboardingProfile, payload: dict[str, Any], replace: bool) -> None:
        fields = [
            "schema_version", "age", "height_cm", "preferred_height_unit",
            "weight_kg", "preferred_weight_unit", "peptides", "custom_peptides",
            "other_medications", "workout_days_per_week", "goals", "custom_goal",
        ]
        for field in fields:
            if field in payload or replace:
                setattr(profile, field, payload.get(field, [] if field in {"peptides", "custom_peptides", "goals"} else None))
        if "healthkit" in payload or replace:
            healthkit = payload.get("healthkit")
            profile.healthkit_requested = None if healthkit is None else healthkit.get("requested")
            profile.healthkit_last_sync_at = None if healthkit is None else healthkit.get("last_sync_at")
        if "notifications" in payload or replace:
            notifications = payload.get("notifications")
            profile.notifications_authorized = None if notifications is None else notifications.get("authorized")

    def _fill_empty_fields(self, profile: OnboardingProfile, payload: dict[str, Any]) -> None:
        for field in ["age", "height_cm", "preferred_height_unit", "weight_kg", "preferred_weight_unit", "other_medications", "workout_days_per_week", "custom_goal"]:
            if getattr(profile, field) is None and payload.get(field) is not None:
                setattr(profile, field, payload[field])
        for field in ["peptides", "custom_peptides", "goals"]:
            if not getattr(profile, field) and payload.get(field):
                setattr(profile, field, payload[field])
```

- [ ] **Step 6: Implement profile routes**

Create `backend/app/api/routes/profile.py`:

```python
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.database import get_db
from app.services.profile import OnboardingProfileService
from app.api.schemas.profile import (
    OnboardingProfilePayload,
    OnboardingProfilePatch,
    OnboardingProfileAttach,
    OnboardingProfileResponse,
)

router = APIRouter()


@router.get("/onboarding", response_model=OnboardingProfileResponse)
async def get_onboarding_profile(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = OnboardingProfileService(db)
    profile = await service.get_for_user(current_user.id)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Onboarding profile not found")
    return service.to_payload(profile)


@router.put("/onboarding", response_model=OnboardingProfileResponse)
async def put_onboarding_profile(
    payload: OnboardingProfilePayload,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = OnboardingProfileService(db)
    profile = await service.put_profile(current_user.id, payload.model_dump())
    return service.to_payload(profile)


@router.patch("/onboarding", response_model=OnboardingProfileResponse)
async def patch_onboarding_profile(
    payload: OnboardingProfilePatch,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = OnboardingProfileService(db)
    profile = await service.patch_profile(
        current_user.id,
        payload.model_dump(exclude_unset=True),
    )
    return service.to_payload(profile)


@router.post("/onboarding/attach", response_model=OnboardingProfileResponse, status_code=status.HTTP_201_CREATED)
async def attach_onboarding_profile(
    payload: OnboardingProfileAttach,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    service = OnboardingProfileService(db)
    profile = await service.attach_profile(
        user_id=current_user.id,
        draft_id=payload.draft_id,
        draft_created_at=payload.draft_created_at,
        draft_updated_at=payload.draft_updated_at,
        is_complete=payload.is_complete,
        current_step=payload.current_step,
        profile_payload=payload.profile.model_dump(),
    )
    return service.to_payload(profile)
```

Modify `backend/app/main.py`:

```python
from app.api.routes import auth, protocols, checkins, labs, insights, health, wearables, notifications, waitlist, feedback, profile
app.include_router(profile.router, prefix="/api/v1/profile", tags=["profile"])
```

- [ ] **Step 7: Add Alembic migration**

Create a migration under `backend/alembic/versions/` that creates `onboarding_profiles` with the columns from `OnboardingProfile`, a unique user index, and a foreign key to `users.id`.

- [ ] **Step 8: Run focused profile tests**

Run:

```bash
cd backend
pytest tests/test_profile_service.py tests/test_profile_routes.py -q
```

Expected: all profile tests pass.

## Task 2: Backend Pending Starter Protocol State

**Files:**
- Modify: `backend/app/models/protocol.py`
- Modify: `backend/app/api/schemas/protocol.py`
- Modify: `backend/app/services/protocol.py`
- Modify: `backend/app/api/routes/protocols.py`
- Modify: `backend/alembic/versions/b4c5d6e7f8a9_onboarding_profile_dashboard_slice.py`
- Test: `backend/tests/test_protocol_service.py`
- Test: `backend/tests/test_protocol_routes.py`

- [ ] **Step 1: Write failing protocol setup tests**

Add to `backend/tests/test_protocol_service.py`:

```python
async def test_create_pending_starter_protocol_from_peptides(service, user):
    protocol = await service.create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide", "BPC-157"],
        goals=["track_protocols"],
    )

    assert protocol.setup_status == "pending_setup"
    assert protocol.is_active is False
    assert protocol.name == "Starter protocol"
    assert [compound.name for compound in protocol.compounds] == ["Retatrutide", "BPC-157"]
    assert all(compound.dose_mg == 0 for compound in protocol.compounds)


async def test_activate_pending_protocol_requires_complete_compounds(service, user):
    protocol = await service.create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=[],
    )

    with pytest.raises(ValueError, match="Dose, frequency, route, and start date are required"):
        await service.activate_pending_protocol(protocol)
```

- [ ] **Step 2: Run protocol tests and verify failure**

Run:

```bash
cd backend
pytest tests/test_protocol_service.py::TestProtocolService::test_create_pending_starter_protocol_from_peptides tests/test_protocol_service.py::TestProtocolService::test_activate_pending_protocol_requires_complete_compounds -q
```

Expected: failure because `create_pending_starter` and `setup_status` do not exist.

- [ ] **Step 3: Add setup status columns**

Modify `backend/app/models/protocol.py`:

```python
    setup_status = Column(String(30), default="active", nullable=False, index=True)
    is_starter = Column(Boolean, default=False, nullable=False)
```

Keep `is_active` for current app behavior. Pending setup protocols use
`is_active=False` and `setup_status="pending_setup"`.

Add these columns to the Alembic migration:

```python
op.add_column("protocols", sa.Column("setup_status", sa.String(length=30), nullable=False, server_default="active"))
op.add_column("protocols", sa.Column("is_starter", sa.Boolean(), nullable=False, server_default=sa.text("0")))
op.create_index(op.f("ix_protocols_setup_status"), "protocols", ["setup_status"], unique=False)
```

- [ ] **Step 4: Update protocol schemas**

Modify `backend/app/api/schemas/protocol.py`:

```python
class ProtocolSetupStatus(str, Enum):
    PENDING_SETUP = "pending_setup"
    ACTIVE = "active"
    INACTIVE = "inactive"


class PendingCompoundResponse(BaseModel):
    id: UUID
    name: str
    dose_mg: float
    dose_unit: str
    frequency: str
    administration_route: str
    notes: Optional[str]

    class Config:
        from_attributes = True
```

Add to `ProtocolResponse`:

```python
    setup_status: str = "active"
    is_starter: bool = False
```

- [ ] **Step 5: Implement pending starter methods**

Add to `ProtocolService`:

```python
    async def get_pending_starter(self, user_id: UUID) -> Optional[Protocol]:
        result = await self.db.execute(
            select(Protocol)
            .options(selectinload(Protocol.compounds))
            .where(
                and_(
                    Protocol.user_id == user_id,
                    Protocol.is_starter == True,
                    Protocol.setup_status == "pending_setup",
                )
            )
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def create_pending_starter(
        self,
        user_id: UUID,
        peptide_names: list[str],
        goals: list[str],
    ) -> Protocol:
        existing = await self.get_pending_starter(user_id)
        if existing:
            return existing
        protocol = Protocol(
            user_id=user_id,
            name="Starter protocol",
            start_date=date.today(),
            is_active=False,
            is_starter=True,
            setup_status="pending_setup",
            notes="Created from onboarding selections.",
        )
        for name in peptide_names:
            protocol.compounds.append(
                Compound(
                    name=name,
                    dose_mg=0,
                    dose_unit="mg",
                    frequency="",
                    administration_route="",
                    notes=None,
                )
            )
        self.db.add(protocol)
        await self.db.commit()
        return await self.get_by_id(protocol.id, user_id)

    async def activate_pending_protocol(self, protocol: Protocol) -> Protocol:
        for compound in protocol.compounds:
            if compound.dose_mg <= 0 or not compound.frequency or not compound.administration_route or not protocol.start_date:
                raise ValueError("Dose, frequency, route, and start date are required")
        await self._deactivate_active_protocols(protocol.user_id)
        protocol.is_active = True
        protocol.setup_status = "active"
        await self.db.commit()
        await self.db.refresh(protocol)
        return await self.get_by_id(protocol.id, protocol.user_id)
```

- [ ] **Step 6: Run focused protocol tests**

Run:

```bash
cd backend
pytest tests/test_protocol_service.py -q
```

Expected: all protocol service tests pass.

## Task 3: Backend Attach Creates Pending Starter Protocol

**Files:**
- Modify: `backend/app/services/profile.py`
- Test: `backend/tests/test_profile_service.py`

- [ ] **Step 1: Add failing attach starter test**

Add to `backend/tests/test_profile_service.py`:

```python
from app.services.protocol import ProtocolService


async def test_attach_profile_creates_one_pending_starter_protocol(db_session, user, profile_payload):
    service = OnboardingProfileService(db_session)
    draft_id = "starter-draft-1"

    await service.attach_profile(
        user_id=user.id,
        draft_id=draft_id,
        draft_created_at=datetime(2026, 6, 30, 12, 0, tzinfo=timezone.utc),
        draft_updated_at=datetime(2026, 6, 30, 12, 5, tzinfo=timezone.utc),
        is_complete=True,
        current_step="notifications",
        profile_payload=profile_payload,
    )
    await service.attach_profile(
        user_id=user.id,
        draft_id=draft_id,
        draft_created_at=datetime(2026, 6, 30, 12, 0, tzinfo=timezone.utc),
        draft_updated_at=datetime(2026, 6, 30, 12, 5, tzinfo=timezone.utc),
        is_complete=True,
        current_step="notifications",
        profile_payload=profile_payload,
    )

    protocols = await ProtocolService(db_session).list_for_user(user.id)
    starters = [protocol for protocol in protocols if protocol.is_starter]
    assert len(starters) == 1
    assert starters[0].setup_status == "pending_setup"
    assert starters[0].compounds[0].name == "Retatrutide"
```

- [ ] **Step 2: Run the attach starter test and verify failure**

Run:

```bash
cd backend
pytest tests/test_profile_service.py::test_attach_profile_creates_one_pending_starter_protocol -q
```

Expected: assertion failure because attach does not create a starter protocol.

- [ ] **Step 3: Call ProtocolService during attach**

Modify `backend/app/services/profile.py`:

```python
from app.services.protocol import ProtocolService
```

At the end of `attach_profile`, before `return profile`:

```python
        peptide_names = list(profile.peptides or []) + list(profile.custom_peptides or [])
        if peptide_names:
            await ProtocolService(self.db).create_pending_starter(
                user_id=user_id,
                peptide_names=peptide_names,
                goals=profile.goals or [],
            )
```

- [ ] **Step 4: Run profile and protocol service tests**

Run:

```bash
cd backend
pytest tests/test_profile_service.py tests/test_protocol_service.py -q
```

Expected: all selected service tests pass.

## Task 4: Backend Dashboard Summary

**Files:**
- Create: `backend/app/api/schemas/dashboard.py`
- Create: `backend/app/services/dashboard.py`
- Create: `backend/app/api/routes/dashboard.py`
- Create: `backend/tests/test_dashboard_service.py`
- Create: `backend/tests/test_dashboard_routes.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: Write dashboard service tests**

Create `backend/tests/test_dashboard_service.py`:

```python
import pytest
from datetime import date, timedelta

from app.services.user import UserService
from app.services.dashboard import DashboardService
from app.services.protocol import ProtocolService
from app.services.checkin import CheckinService


@pytest.fixture
async def user(db_session):
    return await UserService(db_session).create(
        email="dashboard@example.com",
        password="password123",
    )


async def test_dashboard_summary_reports_pending_starter(db_session, user):
    await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["protocol"]["status"] == "pending_setup"
    assert summary["protocol"]["title"] == "Starter protocol"
    assert summary["protocol"]["compounds"] == ["Retatrutide"]


async def test_dashboard_summary_includes_today_and_weight_trend(db_session, user):
    checkins = CheckinService(db_session)
    await checkins.create(user.id, date.today() - timedelta(days=2), weight_kg=75.2, energy_level=6)
    await checkins.create(user.id, date.today(), weight_kg=74.8, energy_level=7, mood=8)

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["today_checkin"]["logged"] is True
    assert summary["response_snapshot"]["weight_trend"][-1]["weight_kg"] == 74.8
    assert summary["response_snapshot"]["latest_energy"] == 7
```

- [ ] **Step 2: Run dashboard service tests and verify failure**

Run:

```bash
cd backend
pytest tests/test_dashboard_service.py -q
```

Expected: import failure because `app.services.dashboard` does not exist.

- [ ] **Step 3: Implement dashboard schemas**

Create `backend/app/api/schemas/dashboard.py`:

```python
from datetime import date, datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel


class DashboardProtocolSummary(BaseModel):
    id: Optional[UUID]
    status: str
    title: str
    compounds: list[str]


class DashboardTodayCheckin(BaseModel):
    logged: bool
    checkin_id: Optional[UUID] = None


class DashboardWeightPoint(BaseModel):
    date: date
    weight_kg: float


class DashboardResponseSnapshot(BaseModel):
    weight_trend: list[DashboardWeightPoint]
    latest_energy: Optional[int] = None
    latest_mood: Optional[int] = None


class DashboardInsightSummary(BaseModel):
    id: Optional[UUID] = None
    title: Optional[str] = None
    severity: Optional[str] = None
    empty_message: Optional[str] = None


class DashboardConnectedContext(BaseModel):
    healthkit_requested: Optional[bool] = None
    has_labs: bool = False
    has_wearables: bool = False


class DashboardSummary(BaseModel):
    generated_at: datetime
    profile_status: str
    protocol: DashboardProtocolSummary
    today_checkin: DashboardTodayCheckin
    response_snapshot: DashboardResponseSnapshot
    insight: DashboardInsightSummary
    connected_context: DashboardConnectedContext
```

- [ ] **Step 4: Implement dashboard service**

Create `backend/app/services/dashboard.py`:

```python
from datetime import datetime, timezone, date, timedelta
from uuid import UUID
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.profile import OnboardingProfile
from app.models.protocol import Protocol
from app.models.checkin import Checkin
from app.models.insight import Insight
from app.models.lab import LabResult
from app.models.wearable import WearableConnection


class DashboardService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def summary_for_user(self, user_id: UUID) -> dict:
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
        result = await self.db.execute(select(OnboardingProfile).where(OnboardingProfile.user_id == user_id))
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

    async def _has_rows(self, model, user_id: UUID) -> bool:
        result = await self.db.execute(select(func.count(model.id)).where(model.user_id == user_id))
        return bool(result.scalar() or 0)

    def _protocol_summary(self, protocol: Protocol | None) -> dict:
        if protocol is None:
            return {"id": None, "status": "missing", "title": "Create your first protocol", "compounds": []}
        return {
            "id": protocol.id,
            "status": protocol.setup_status,
            "title": protocol.name,
            "compounds": [compound.name for compound in protocol.compounds],
        }

    def _insight_summary(self, insight: Insight | None, checkin_count: int) -> dict:
        if insight:
            return {"id": insight.id, "title": insight.title, "severity": insight.severity.value, "empty_message": None}
        if checkin_count < 3:
            return {"id": None, "title": None, "severity": None, "empty_message": "Peppy needs a few check-ins to find useful patterns."}
        return {"id": None, "title": None, "severity": None, "empty_message": "No new insights right now."}
```

- [ ] **Step 5: Implement dashboard route**

Create `backend/app/api/routes/dashboard.py`:

```python
from typing import Annotated
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.database import get_db
from app.api.schemas.dashboard import DashboardSummary
from app.services.dashboard import DashboardService

router = APIRouter()


@router.get("/summary", response_model=DashboardSummary)
async def get_dashboard_summary(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    return await DashboardService(db).summary_for_user(current_user.id)
```

Modify `backend/app/main.py` to include:

```python
from app.api.routes import dashboard
app.include_router(dashboard.router, prefix="/api/v1/dashboard", tags=["dashboard"])
```

- [ ] **Step 6: Run backend dashboard tests**

Run:

```bash
cd backend
pytest tests/test_dashboard_service.py tests/test_dashboard_routes.py -q
```

Expected: all dashboard tests pass.

## Task 5: iOS Network Contracts and Profile Attach Request

**Files:**
- Modify: `ios/peppy/Core/Network/APIModels.swift`
- Modify: `ios/peppy/Core/Network/Endpoint.swift`
- Modify: `ios/peppy/Core/Network/MockAPIClient.swift`
- Modify: `ios/peppy/Features/Onboarding/Models/OnboardingDraft.swift`
- Create: `ios/peppy/peppyTests/ProfileAttachTests.swift`

- [ ] **Step 1: Write failing profile attach mapping tests**

Create `ios/peppy/peppyTests/ProfileAttachTests.swift`:

```swift
import XCTest
@testable import peppy

final class ProfileAttachTests: XCTestCase {
    func testOnboardingDraftBuildsAttachRequestWithServerEnums() {
        var draft = OnboardingDraft()
        draft.age = 32
        draft.heightCentimeters = 172.72
        draft.preferredHeightUnit = .feetAndInches
        draft.weightKilograms = 74.84
        draft.preferredWeightUnit = .pounds
        draft.selectedPeptides = ["Retatrutide"]
        draft.workoutDaysPerWeek = 3
        draft.goals = [.trackProtocols, .seeWhatWorks]
        draft.healthChoice = .requested
        draft.healthOutcome = .requested
        draft.notificationChoice = .requested
        draft.notificationOutcome = .authorized
        draft.isComplete = true

        let request = OnboardingProfileAttachRequest(draft: draft)

        XCTAssertEqual(request.schemaVersion, 1)
        XCTAssertEqual(request.profile.preferredHeightUnit, "ft_in")
        XCTAssertEqual(request.profile.preferredWeightUnit, "lb")
        XCTAssertEqual(request.profile.goals.sorted(), ["see_what_works", "track_protocols"])
        XCTAssertEqual(request.profile.healthkit?.requested, true)
        XCTAssertEqual(request.profile.notifications?.authorized, true)
    }
}
```

- [ ] **Step 2: Run profile attach tests and verify failure**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:peppyTests/ProfileAttachTests test
```

Expected: compile failure because `OnboardingProfileAttachRequest` does not exist.

- [ ] **Step 3: Add iOS profile and dashboard API models**

Modify `ios/peppy/Core/Network/APIModels.swift` with:

```swift
struct OnboardingProfilePayload: Codable, Equatable {
    let schemaVersion: Int
    let age: Int?
    let heightCm: Double?
    let preferredHeightUnit: String?
    let weightKg: Double?
    let preferredWeightUnit: String?
    let peptides: [String]
    let customPeptides: [String]
    let otherMedications: String?
    let workoutDaysPerWeek: Int?
    let goals: [String]
    let customGoal: String?
    let healthkit: HealthKitProfilePayload?
    let notifications: NotificationProfilePayload?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case age
        case heightCm = "height_cm"
        case preferredHeightUnit = "preferred_height_unit"
        case weightKg = "weight_kg"
        case preferredWeightUnit = "preferred_weight_unit"
        case peptides
        case customPeptides = "custom_peptides"
        case otherMedications = "other_medications"
        case workoutDaysPerWeek = "workout_days_per_week"
        case goals
        case customGoal = "custom_goal"
        case healthkit
        case notifications
    }
}

struct HealthKitProfilePayload: Codable, Equatable {
    let requested: Bool
    let lastSyncAt: Date?

    enum CodingKeys: String, CodingKey {
        case requested
        case lastSyncAt = "last_sync_at"
    }
}

struct NotificationProfilePayload: Codable, Equatable {
    let authorized: Bool
}

struct OnboardingProfileAttachRequest: Encodable {
    let schemaVersion: Int
    let draftId: String
    let draftCreatedAt: Date
    let draftUpdatedAt: Date
    let isComplete: Bool
    let currentStep: String
    let profile: OnboardingProfilePayload

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case draftId = "draft_id"
        case draftCreatedAt = "draft_created_at"
        case draftUpdatedAt = "draft_updated_at"
        case isComplete = "is_complete"
        case currentStep = "current_step"
        case profile
    }
}
```

- [ ] **Step 4: Add draft mapping initializer**

Add in `APIModels.swift`:

```swift
extension OnboardingProfileAttachRequest {
    init(draft: OnboardingDraft) {
        self.schemaVersion = draft.schemaVersion
        self.draftId = draft.draftID.uuidString.lowercased()
        self.draftCreatedAt = draft.createdAt
        self.draftUpdatedAt = draft.updatedAt
        self.isComplete = draft.isComplete
        self.currentStep = draft.currentStep.serverValue
        self.profile = OnboardingProfilePayload(draft: draft)
    }
}

extension OnboardingProfilePayload {
    init(draft: OnboardingDraft) {
        self.schemaVersion = draft.schemaVersion
        self.age = draft.age
        self.heightCm = draft.heightCentimeters
        self.preferredHeightUnit = draft.heightCentimeters == nil ? nil : draft.preferredHeightUnit.serverValue
        self.weightKg = draft.weightKilograms
        self.preferredWeightUnit = draft.weightKilograms == nil ? nil : draft.preferredWeightUnit.serverValue
        self.peptides = draft.selectedPeptides
        self.customPeptides = draft.customPeptides
        self.otherMedications = draft.otherMedications
        self.workoutDaysPerWeek = draft.workoutDaysPerWeek
        self.goals = draft.goals.map(\.serverValue).sorted()
        self.customGoal = draft.customGoal
        self.healthkit = draft.healthChoice == .notAsked ? nil : HealthKitProfilePayload(requested: draft.healthChoice == .requested, lastSyncAt: nil)
        self.notifications = draft.notificationChoice == .notAsked ? nil : NotificationProfilePayload(authorized: draft.notificationOutcome == .authorized)
    }
}
```

Modify `OnboardingDraft` to include stable draft ID:

```swift
var draftID = UUID()
```

Add server mapping extensions:

```swift
extension HeightUnit {
    var serverValue: String { self == .feetAndInches ? "ft_in" : "cm" }
}

extension WeightUnit {
    var serverValue: String { self == .pounds ? "lb" : "kg" }
}

extension OnboardingGoal {
    var serverValue: String {
        switch self {
        case .trackProtocols: "track_protocols"
        case .understandBody: "understand_body"
        case .buildHabits: "build_habits"
        case .seeWhatWorks: "see_what_works"
        case .optimizeRecovery: "optimize_recovery"
        case .feelInControl: "feel_in_control"
        }
    }
}

extension OnboardingStep {
    var serverValue: String { String(describing: self) }
}
```

- [ ] **Step 5: Add endpoints**

Modify `Endpoint`:

```swift
case attachOnboardingProfile(OnboardingProfileAttachRequest)
case getDashboardSummary
```

Add paths:

```swift
case .attachOnboardingProfile:
    return "/profile/onboarding/attach"
case .getDashboardSummary:
    return "/dashboard/summary"
```

Add methods and bodies:

```swift
case .attachOnboardingProfile:
    return .post

case .attachOnboardingProfile(let request):
    return request
```

- [ ] **Step 6: Run iOS profile attach tests**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:peppyTests/ProfileAttachTests test
```

Expected: tests pass.

## Task 6: iOS Auth Handoff Attaches Profile Without Blocking Dashboard

**Files:**
- Modify: `ios/peppy/App/AppFlowCoordinator.swift`
- Modify: `ios/peppy/Features/Auth/Views/LoginView.swift`
- Modify: `ios/peppy/Features/Auth/Views/RegisterView.swift`
- Test: `ios/peppy/peppyTests/AppFlowCoordinatorTests.swift`
- Test: `ios/peppy/peppyTests/ProfileAttachTests.swift`

- [ ] **Step 1: Add coordinator attach-failure state test**

Add to `AppFlowCoordinatorTests.swift`:

```swift
func testDidAuthenticateAttemptsProfileAttachAndStillRoutesDashboardOnFailure() async {
    let fixture = Fixture()
    let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
    var draft = OnboardingDraft()
    draft.isComplete = true
    draft.selectedPeptides = ["Retatrutide"]
    fixture.store.saveAnonymousDraft(draft)
    fixture.api.setMockError(.serverError, for: "/profile/onboarding/attach")

    await fixture.coordinator.didAuthenticate(user: user)

    XCTAssertEqual(fixture.coordinator.route, .dashboard)
    XCTAssertTrue(fixture.coordinator.hasProfileAttachFailure)
    XCTAssertNotNil(fixture.store.loadAnonymousDraft())
}
```

- [ ] **Step 2: Run the coordinator test and verify failure**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:peppyTests/AppFlowCoordinatorTests/testDidAuthenticateAttemptsProfileAttachAndStillRoutesDashboardOnFailure test
```

Expected: compile failure because `didAuthenticate` is synchronous and `hasProfileAttachFailure` does not exist.

- [ ] **Step 3: Make auth handoff async and attach profile**

Modify `AppFlowCoordinator`:

```swift
var hasProfileAttachFailure = false

func didAuthenticate(user: User) async {
    hasProfileAttachFailure = false
    if let draft = onboardingStore.loadAnonymousDraft(), draft.isComplete {
        do {
            let _: OnboardingProfilePayload = try await api.execute(
                .attachOnboardingProfile(OnboardingProfileAttachRequest(draft: draft))
            )
            onboardingStore.associateAnonymousDraft(with: user.id)
        } catch {
            hasProfileAttachFailure = true
            onboardingStore.hasKnownAccount = true
        }
    } else {
        onboardingStore.associateAnonymousDraft(with: user.id)
    }
    appState.login(user: user)
    authenticationBackStack = []
    route = .dashboard
}
```

Update test call sites to `await`.

- [ ] **Step 4: Update LoginView and RegisterView completion helpers**

Modify static helpers:

```swift
@MainActor
static func completeLogin(user: User, deps: Dependencies) async {
    await deps.flow.didAuthenticate(user: user)
}

@MainActor
static func completeRegistration(user: User, deps: Dependencies) async {
    await deps.flow.didAuthenticate(user: user)
    deps.appState.showSuccess("Welcome to Peppy!")
}
```

Call with `await Self.completeLogin(...)` and `await Self.completeRegistration(...)`.

- [ ] **Step 5: Run auth and profile tests**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:peppyTests/AppFlowCoordinatorTests -only-testing:peppyTests/ProfileAttachTests test
```

Expected: selected tests pass.

## Task 7: iOS Dashboard View Model and Models

**Files:**
- Create: `ios/peppy/Features/Dashboard/Models/DashboardModels.swift`
- Create: `ios/peppy/Features/Dashboard/ViewModels/DashboardViewModel.swift`
- Create: `ios/peppy/peppyTests/DashboardViewModelTests.swift`
- Modify: `ios/peppy/Core/Network/APIModels.swift`

- [ ] **Step 1: Write failing dashboard view model tests**

Create `DashboardViewModelTests.swift`:

```swift
import XCTest
@testable import peppy

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testLoadDashboardSummaryShowsLoadedState() async {
        let api = MockAPIClient()
        let summary = DashboardSummary.mockPendingStarter
        api.setMockResponse(summary, for: "/dashboard/summary")
        let model = DashboardViewModel(api: api, hasProfileAttachFailure: false)

        await model.load()

        XCTAssertEqual(model.state.summary?.protocol.status, "pending_setup")
        XCTAssertFalse(model.state.isLoading)
        XCTAssertNil(model.state.errorMessage)
    }

    func testProfileAttachFailureShowsSyncRecoveryCard() async {
        let api = MockAPIClient()
        api.setMockResponse(DashboardSummary.mockMissingProfile, for: "/dashboard/summary")
        let model = DashboardViewModel(api: api, hasProfileAttachFailure: true)

        await model.load()

        XCTAssertTrue(model.state.showsProfileSyncRecovery)
    }
}
```

- [ ] **Step 2: Run dashboard view model tests and verify failure**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:peppyTests/DashboardViewModelTests test
```

Expected: compile failure because dashboard types do not exist.

- [ ] **Step 3: Implement dashboard models**

Create `DashboardModels.swift`:

```swift
import Foundation

struct DashboardSummary: Codable, Equatable {
    let generatedAt: Date
    let profileStatus: String
    let `protocol`: DashboardProtocolSummary
    let todayCheckin: DashboardTodayCheckin
    let responseSnapshot: DashboardResponseSnapshot
    let insight: DashboardInsightSummary
    let connectedContext: DashboardConnectedContext

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case profileStatus = "profile_status"
        case `protocol`
        case todayCheckin = "today_checkin"
        case responseSnapshot = "response_snapshot"
        case insight
        case connectedContext = "connected_context"
    }
}

struct DashboardProtocolSummary: Codable, Equatable {
    let id: UUID?
    let status: String
    let title: String
    let compounds: [String]
}

struct DashboardTodayCheckin: Codable, Equatable {
    let logged: Bool
    let checkinId: UUID?

    enum CodingKeys: String, CodingKey {
        case logged
        case checkinId = "checkin_id"
    }
}

struct DashboardResponseSnapshot: Codable, Equatable {
    let weightTrend: [DashboardWeightPoint]
    let latestEnergy: Int?
    let latestMood: Int?

    enum CodingKeys: String, CodingKey {
        case weightTrend = "weight_trend"
        case latestEnergy = "latest_energy"
        case latestMood = "latest_mood"
    }
}

struct DashboardWeightPoint: Codable, Equatable {
    let date: Date
    let weightKg: Double

    enum CodingKeys: String, CodingKey {
        case date
        case weightKg = "weight_kg"
    }
}

struct DashboardInsightSummary: Codable, Equatable {
    let id: UUID?
    let title: String?
    let severity: String?
    let emptyMessage: String?

    enum CodingKeys: String, CodingKey {
        case id, title, severity
        case emptyMessage = "empty_message"
    }
}

struct DashboardConnectedContext: Codable, Equatable {
    let healthkitRequested: Bool?
    let hasLabs: Bool
    let hasWearables: Bool

    enum CodingKeys: String, CodingKey {
        case healthkitRequested = "healthkit_requested"
        case hasLabs = "has_labs"
        case hasWearables = "has_wearables"
    }
}
```

- [ ] **Step 4: Add mock summaries**

Add in `DashboardModels.swift`:

```swift
extension DashboardSummary {
    static let mockPendingStarter = DashboardSummary(
        generatedAt: Date(timeIntervalSince1970: 1_788_000_000),
        profileStatus: "present",
        protocol: DashboardProtocolSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            status: "pending_setup",
            title: "Starter protocol",
            compounds: ["Retatrutide"]
        ),
        todayCheckin: DashboardTodayCheckin(logged: false, checkinId: nil),
        responseSnapshot: DashboardResponseSnapshot(
            weightTrend: [
                DashboardWeightPoint(date: Date(timeIntervalSince1970: 1_787_740_800), weightKg: 75.2),
                DashboardWeightPoint(date: Date(timeIntervalSince1970: 1_787_827_200), weightKg: 74.8),
            ],
            latestEnergy: 7,
            latestMood: 8
        ),
        insight: DashboardInsightSummary(id: nil, title: nil, severity: nil, emptyMessage: "Peppy needs a few check-ins to find useful patterns."),
        connectedContext: DashboardConnectedContext(healthkitRequested: true, hasLabs: false, hasWearables: false)
    )

    static let mockMissingProfile = DashboardSummary(
        generatedAt: Date(timeIntervalSince1970: 1_788_000_000),
        profileStatus: "missing",
        protocol: DashboardProtocolSummary(id: nil, status: "missing", title: "Create your first protocol", compounds: []),
        todayCheckin: DashboardTodayCheckin(logged: false, checkinId: nil),
        responseSnapshot: DashboardResponseSnapshot(weightTrend: [], latestEnergy: nil, latestMood: nil),
        insight: DashboardInsightSummary(id: nil, title: nil, severity: nil, emptyMessage: "Peppy needs a few check-ins to find useful patterns."),
        connectedContext: DashboardConnectedContext(healthkitRequested: nil, hasLabs: false, hasWearables: false)
    )
}
```

- [ ] **Step 5: Implement dashboard view model**

Create `DashboardViewModel.swift`:

```swift
import Foundation
import Observation

struct DashboardState: Equatable {
    var isLoading = false
    var summary: DashboardSummary?
    var errorMessage: String?
    var showsProfileSyncRecovery = false
}

@MainActor
@Observable
final class DashboardViewModel {
    private let api: APIClientProtocol
    private let hasProfileAttachFailure: () -> Bool

    var state = DashboardState()

    init(api: APIClientProtocol, hasProfileAttachFailure: @escaping @autoclosure () -> Bool) {
        self.api = api
        self.hasProfileAttachFailure = hasProfileAttachFailure
    }

    func load() async {
        state.isLoading = true
        state.errorMessage = nil
        defer { state.isLoading = false }
        do {
            let summary: DashboardSummary = try await api.execute(.getDashboardSummary)
            state.summary = summary
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        } catch let error as APIError {
            state.errorMessage = error.userMessage
            state.summary = .mockMissingProfile
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        } catch {
            state.errorMessage = error.localizedDescription
            state.summary = .mockMissingProfile
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        }
    }
}
```

- [ ] **Step 6: Run dashboard model tests**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:peppyTests/DashboardViewModelTests test
```

Expected: tests pass.

## Task 8: iOS Dashboard UI

**Files:**
- Create: `ios/peppy/Features/Dashboard/Views/DashboardView.swift`
- Create: `ios/peppy/Features/Dashboard/Views/DashboardCards.swift`
- Modify: `ios/peppy/App/MainTabView.swift`
- Test: `ios/peppy/peppyTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Add view-state display tests**

Add to `DashboardViewModelTests.swift`:

```swift
func testPendingStarterSummaryPrefersFinishSetupAction() async {
    let api = MockAPIClient()
    api.setMockResponse(DashboardSummary.mockPendingStarter, for: "/dashboard/summary")
    let model = DashboardViewModel(api: api, hasProfileAttachFailure: false)

    await model.load()

    XCTAssertEqual(model.state.summary?.protocol.status, "pending_setup")
    XCTAssertEqual(model.state.summary?.protocol.title, "Starter protocol")
}
```

- [ ] **Step 2: Implement dashboard cards**

Create `DashboardCards.swift` with small reusable SwiftUI cards:

```swift
import SwiftUI

struct DashboardProtocolCard: View {
    let summary: DashboardProtocolSummary
    let finishSetup: () -> Void

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(summary.status == "pending_setup" ? "Starter protocol" : "Active protocol", systemImage: "pills.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)
                    Spacer()
                    PepBadge(text: summary.status == "pending_setup" ? "Needs setup" : "Active", type: summary.status == "pending_setup" ? .warning : .success)
                }
                Text(summary.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.pepTextPrimary)
                if !summary.compounds.isEmpty {
                    Text(summary.compounds.joined(separator: ", "))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pepTextSecondary)
                }
                PepButton(
                    title: summary.status == "pending_setup" ? "Finish setup" : "View protocol",
                    style: .primary,
                    action: finishSetup
                )
            }
        }
    }
}

struct DashboardTodayCard: View {
    let today: DashboardTodayCheckin
    let logCheckin: () -> Void

    var body: some View {
        PepCard {
            HStack(spacing: 14) {
                Image(systemName: today.logged ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(today.logged ? "Today's check-in is saved" : "How are you today?")
                        .font(.system(size: 17, weight: .semibold))
                    Text(today.logged ? "You can update it anytime." : "Log weight, energy, mood, and symptoms.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                }
                Spacer()
                Button(action: logCheckin) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.pepTextTertiary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(today.logged ? "Update check-in" : "Log check-in")
            }
        }
    }
}
```

- [ ] **Step 3: Implement dashboard screen**

Create `DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    @Environment(\.dependencies) private var deps
    @State private var model: DashboardViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let state = model?.state {
                        if state.showsProfileSyncRecovery {
                            syncRecoveryCard
                        }
                        if let summary = state.summary {
                            DashboardProtocolCard(summary: summary.protocol) {}
                            DashboardTodayCard(today: summary.todayCheckin) {}
                            responseSnapshot(summary.responseSnapshot)
                            insightCard(summary.insight)
                            connectedContextCard(summary.connectedContext)
                        } else if state.isLoading {
                            PepLoadingView(message: "Loading your dashboard")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                if model == nil {
                    model = DashboardViewModel(
                        api: deps.api,
                        hasProfileAttachFailure: deps.flow.hasProfileAttachFailure
                    )
                }
                await model?.load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            PeppyLogo(size: 28, showsWordmark: true)
            Text("Your protocol, understood.")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.pepTextPrimary)
            Text("Track what you take, how you feel, and what is changing.")
                .font(.system(size: 14))
                .foregroundStyle(Color.pepTextSecondary)
        }
        .padding(.top, 8)
    }

    private var syncRecoveryCard: some View {
        PepCard {
            Label("Finish syncing setup", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
        }
    }

    private func responseSnapshot(_ snapshot: DashboardResponseSnapshot) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Response snapshot")
                    .font(.system(size: 17, weight: .semibold))
                Text(snapshot.weightTrend.isEmpty ? "Log a few check-ins to see your trend." : "\(snapshot.weightTrend.count) weight points logged")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
            }
        }
    }

    private func insightCard(_ insight: DashboardInsightSummary) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Insight")
                    .font(.system(size: 17, weight: .semibold))
                Text(insight.title ?? insight.emptyMessage ?? "No new insights right now.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
            }
        }
    }

    private func connectedContextCard(_ context: DashboardConnectedContext) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connected context")
                    .font(.system(size: 17, weight: .semibold))
                Text(context.healthkitRequested == true ? "Apple Health is connected." : "Connect Apple Health or add labs for more context.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
            }
        }
    }
}
```

- [ ] **Step 4: Replace Home temporary screen**

Modify `MainTabView.swift`:

```swift
struct HomeTab: View {
    var body: some View {
        DashboardView()
    }
}
```

- [ ] **Step 5: Build iOS dashboard**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: build succeeds.

## Task 9: iOS Starter Protocol Setup Flow

**Files:**
- Create: `ios/peppy/Features/Protocols/ViewModels/StarterProtocolViewModel.swift`
- Create: `ios/peppy/Features/Protocols/Views/StarterProtocolSetupView.swift`
- Create: `ios/peppy/peppyTests/StarterProtocolViewModelTests.swift`
- Modify: `ios/peppy/Core/Network/APIModels.swift`
- Modify: `ios/peppy/Core/Network/Endpoint.swift`

- [ ] **Step 1: Write starter protocol validation tests**

Create `StarterProtocolViewModelTests.swift`:

```swift
import XCTest
@testable import peppy

@MainActor
final class StarterProtocolViewModelTests: XCTestCase {
    func testActivationRequiresDoseFrequencyRouteAndStartDate() {
        let model = StarterProtocolViewModel(protocolID: UUID(), compounds: ["Retatrutide"], api: MockAPIClient())

        XCTAssertFalse(model.canSave)
        XCTAssertEqual(model.validationMessage, "Dose, frequency, route, and start date are required.")
    }

    func testCompleteCompoundCanSave() {
        let model = StarterProtocolViewModel(protocolID: UUID(), compounds: ["Retatrutide"], api: MockAPIClient())
        model.doseText = "2"
        model.frequency = "weekly"
        model.route = "subcutaneous"
        model.startDate = Date()

        XCTAssertTrue(model.canSave)
        XCTAssertNil(model.validationMessage)
    }
}
```

- [ ] **Step 2: Implement view model**

Create `StarterProtocolViewModel.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class StarterProtocolViewModel {
    let protocolID: UUID
    let compounds: [String]
    private let api: APIClientProtocol

    var doseText = ""
    var frequency = ""
    var route = ""
    var startDate: Date?
    var isSaving = false

    init(protocolID: UUID, compounds: [String], api: APIClientProtocol) {
        self.protocolID = protocolID
        self.compounds = compounds
        self.api = api
    }

    var canSave: Bool {
        Double(doseText).map { $0 > 0 } == true &&
        !frequency.trimmingCharacters(in: .whitespaces).isEmpty &&
        !route.trimmingCharacters(in: .whitespaces).isEmpty &&
        startDate != nil
    }

    var validationMessage: String? {
        canSave ? nil : "Dose, frequency, route, and start date are required."
    }
}
```

- [ ] **Step 3: Add activation endpoint**

Add `Endpoint.activateStarterProtocol(id: UUID, StarterProtocolActivationRequest)` and corresponding `StarterProtocolActivationRequest` model with `dose_mg`, `dose_unit`, `frequency`, `administration_route`, and `start_date`.

- [ ] **Step 4: Implement setup view**

Create `StarterProtocolSetupView.swift` using `PepTextFieldWithLabel`, simple frequency/route fields, a `DatePicker`, and a primary `Save protocol` button disabled until `canSave`.

- [ ] **Step 5: Run starter protocol tests**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:peppyTests/StarterProtocolViewModelTests test
```

Expected: tests pass.

## Task 10: Verification and Review

**Files:**
- Review all changed backend and iOS files.
- Update `ios/peppy/design-qa.md` only if screenshots or simulator QA are completed during execution.

- [ ] **Step 1: Run backend focused tests**

Run:

```bash
cd backend
pytest tests/test_profile_service.py tests/test_profile_routes.py tests/test_dashboard_service.py tests/test_dashboard_routes.py tests/test_protocol_service.py tests/test_protocol_routes.py -q
```

Expected: all selected backend tests pass.

- [ ] **Step 2: Run iOS focused tests**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:peppyTests/ProfileAttachTests -only-testing:peppyTests/DashboardViewModelTests -only-testing:peppyTests/StarterProtocolViewModelTests -only-testing:peppyTests/AppFlowCoordinatorTests test
```

Expected: all selected iOS tests pass.

- [ ] **Step 3: Run iOS generic build**

Run:

```bash
cd ios/peppy
xcodebuild -project peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run full backend tests**

Run:

```bash
cd backend
pytest -q
```

Expected: full backend suite passes.

- [ ] **Step 5: Check diff hygiene**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors. Only intended files are modified, plus the pre-existing unstaged Xcode UI state file if Xcode touched it.

- [ ] **Step 6: Screenshot review when simulator access is available**

Capture Home dashboard states:

```text
Dashboard with pending starter protocol
Dashboard with no onboarding peptides
Dashboard with check-in logged
Starter protocol setup form
Dashboard with profile sync recovery card
```

Compare them against the relevant Figma frames from `/Users/gabrielcontreras/Downloads/Peppy IOS.fig` for tone, spacing, card density, button hierarchy, and tab behavior.

## Execution Recommendation

Use **subagent-driven development**:

1. Backend profile + starter protocol persistence.
2. Backend dashboard summary.
3. iOS network/auth attach.
4. iOS dashboard UI/view model.
5. iOS starter protocol setup and final verification.

Each task can be reviewed independently while preserving the vertical slice.
