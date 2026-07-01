from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.profile import OnboardingProfile
from app.services.protocol import ProtocolService


class OnboardingProfileService:
    PROFILE_FIELDS = (
        "schema_version",
        "age",
        "height_cm",
        "preferred_height_unit",
        "weight_kg",
        "preferred_weight_unit",
        "peptides",
        "custom_peptides",
        "other_medications",
        "workout_days_per_week",
        "goals",
        "custom_goal",
        "healthkit_requested",
        "healthkit_last_sync_at",
        "notifications_authorized",
    )
    LIST_FIELDS = {"peptides", "custom_peptides", "goals"}

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_for_user(self, user_id: UUID) -> OnboardingProfile | None:
        result = await self.db.execute(
            select(OnboardingProfile).where(OnboardingProfile.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def put_profile(self, user_id: UUID, payload: Any) -> OnboardingProfile:
        profile = await self.get_for_user(user_id)
        if profile is None:
            profile = OnboardingProfile(user_id=user_id)
            self.db.add(profile)

        self._reset_profile_fields(profile)
        self._apply_updates(profile, self._payload_to_updates(payload, exclude_unset=False))

        await self.db.commit()
        await self.db.refresh(profile)
        return profile

    async def patch_profile(self, user_id: UUID, patch: Any) -> OnboardingProfile:
        profile = await self.get_for_user(user_id)
        if profile is None:
            profile = OnboardingProfile(user_id=user_id)
            self.db.add(profile)

        self._apply_updates(profile, self._payload_to_updates(patch, exclude_unset=True))

        await self.db.commit()
        await self.db.refresh(profile)
        return profile

    async def attach_profile(
        self,
        user_id: UUID,
        draft_id: str,
        draft_created_at: datetime | None,
        draft_updated_at: datetime | None,
        is_complete: bool,
        current_step: str | None,
        profile_payload: Any,
    ) -> OnboardingProfile:
        profile = await self.get_for_user(user_id)
        if profile and profile.source_draft_id == draft_id:
            await self._create_pending_starter_if_needed(user_id, profile)
            return profile

        updates = self._payload_to_updates(profile_payload, exclude_unset=True)
        if profile is None:
            profile = OnboardingProfile(user_id=user_id)
            self.db.add(profile)
            self._apply_updates(profile, updates)
        else:
            self._fill_empty_fields(profile, updates)

        profile.source_draft_id = draft_id
        profile.source_draft_created_at = draft_created_at
        profile.source_draft_updated_at = draft_updated_at
        profile.source_current_step = current_step
        profile.source_is_complete = is_complete

        await self.db.commit()
        await self.db.refresh(profile)
        await self._create_pending_starter_if_needed(user_id, profile)
        return profile

    def to_payload(self, profile: OnboardingProfile) -> dict[str, Any]:
        healthkit = None
        if profile.healthkit_requested is not None or profile.healthkit_last_sync_at is not None:
            healthkit = {
                "requested": profile.healthkit_requested,
                "last_sync_at": profile.healthkit_last_sync_at,
            }

        notifications = None
        if profile.notifications_authorized is not None:
            notifications = {"authorized": profile.notifications_authorized}

        return {
            "id": profile.id,
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
            "healthkit": healthkit,
            "notifications": notifications,
            "source_draft_id": profile.source_draft_id,
            "source_draft_created_at": profile.source_draft_created_at,
            "source_draft_updated_at": profile.source_draft_updated_at,
            "source_current_step": profile.source_current_step,
            "source_is_complete": profile.source_is_complete,
            "created_at": profile.created_at,
            "updated_at": profile.updated_at,
        }

    def _payload_to_updates(self, payload: Any, exclude_unset: bool) -> dict[str, Any]:
        if isinstance(payload, BaseModel):
            data = payload.model_dump(exclude_unset=exclude_unset)
        else:
            data = dict(payload or {})

        updates: dict[str, Any] = {}
        for key, value in data.items():
            if key == "healthkit":
                if value is None:
                    updates["healthkit_requested"] = None
                    updates["healthkit_last_sync_at"] = None
                else:
                    if isinstance(value, BaseModel):
                        value = value.model_dump(exclude_unset=exclude_unset)
                    if "requested" in value:
                        updates["healthkit_requested"] = value["requested"]
                    if "last_sync_at" in value:
                        updates["healthkit_last_sync_at"] = value["last_sync_at"]
            elif key == "notifications":
                if value is None:
                    updates["notifications_authorized"] = None
                else:
                    if isinstance(value, BaseModel):
                        value = value.model_dump(exclude_unset=exclude_unset)
                    if "authorized" in value:
                        updates["notifications_authorized"] = value["authorized"]
            elif key in self.PROFILE_FIELDS:
                updates[key] = value
        return updates

    def _apply_updates(self, profile: OnboardingProfile, updates: dict[str, Any]) -> None:
        for key, value in updates.items():
            if key in self.LIST_FIELDS and value is None:
                value = []
            setattr(profile, key, value)

    def _fill_empty_fields(self, profile: OnboardingProfile, updates: dict[str, Any]) -> None:
        for key, value in updates.items():
            if key == "schema_version":
                continue
            if value is None:
                continue
            current_value = getattr(profile, key)
            if key in self.LIST_FIELDS:
                if not current_value and value:
                    setattr(profile, key, value)
            elif current_value in (None, ""):
                setattr(profile, key, value)

    def _reset_profile_fields(self, profile: OnboardingProfile) -> None:
        for key in self.PROFILE_FIELDS:
            if key == "schema_version":
                setattr(profile, key, 1)
            elif key in self.LIST_FIELDS:
                setattr(profile, key, [])
            else:
                setattr(profile, key, None)

    async def _create_pending_starter_if_needed(
        self,
        user_id: UUID,
        profile: OnboardingProfile,
    ) -> None:
        peptide_names = list(profile.peptides or []) + list(profile.custom_peptides or [])
        if not peptide_names:
            return

        await ProtocolService(self.db).create_pending_starter(
            user_id=user_id,
            peptide_names=peptide_names,
            goals=profile.goals or [],
        )
