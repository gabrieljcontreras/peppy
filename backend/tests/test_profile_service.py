from datetime import datetime, timezone

import pytest

from app.api.schemas.profile import OnboardingProfilePayload
from app.services.profile import OnboardingProfileService
from app.services.protocol import ProtocolService
from app.services.user import UserService


def test_profile_payload_deduplicates_lists_case_insensitively():
    payload = OnboardingProfilePayload(
        peptides=["Retatrutide", " retatrutide "],
        goals=["Track", " track "],
    )

    assert payload.peptides == ["Retatrutide"]
    assert payload.goals == ["Track"]


class TestOnboardingProfileService:
    @pytest.fixture
    async def user(self, db_session):
        service = UserService(db_session)
        return await service.create(
            email="profile_service@example.com",
            password="password123",
        )

    @pytest.fixture
    def service(self, db_session):
        return OnboardingProfileService(db_session)

    async def test_put_profile_creates_profile_with_normalized_payload(self, service, user):
        payload = OnboardingProfilePayload(
            age=42,
            height_cm=180,
            preferred_height_unit="cm",
            weight_kg=91.2,
            preferred_weight_unit="kg",
            peptides=[" retatrutide ", "retatrutide", "bpc-157"],
            custom_peptides=[" custom peptide ", "custom peptide"],
            other_medications="metformin",
            workout_days_per_week=4,
            goals=["weight_loss", " weight_loss ", "energy"],
            custom_goal="Improve recovery",
            healthkit={"requested": True, "last_sync_at": None},
            notifications={"authorized": False},
        )

        profile = await service.put_profile(user.id, payload)
        stored = await service.get_for_user(user.id)
        response = service.to_payload(profile)

        assert stored is not None
        assert stored.id == profile.id
        assert profile.user_id == user.id
        assert profile.schema_version == 1
        assert profile.peptides == ["retatrutide", "bpc-157"]
        assert profile.custom_peptides == ["custom peptide"]
        assert profile.goals == ["weight_loss", "energy"]
        assert response["healthkit"] == {"requested": True, "last_sync_at": None}
        assert response["notifications"] == {"authorized": False}

    async def test_patch_profile_creates_and_updates_only_supplied_fields(self, service, user):
        created = await service.patch_profile(
            user.id,
            OnboardingProfilePayload(
                age=35,
                weight_kg=82.5,
                peptides=["semaglutide"],
                healthkit={"requested": True},
            ),
        )

        patched = await service.patch_profile(
            user.id,
            OnboardingProfilePayload(
                weight_kg=80.1,
                goals=["lean_mass"],
                notifications={"authorized": True},
            ),
        )

        assert patched.id == created.id
        assert patched.age == 35
        assert patched.weight_kg == 80.1
        assert patched.peptides == ["semaglutide"]
        assert patched.goals == ["lean_mass"]
        assert patched.healthkit_requested is True
        assert patched.notifications_authorized is True

    async def test_attach_profile_is_idempotent_for_same_draft(self, service, user):
        draft_created_at = datetime(2026, 6, 1, 14, 30, tzinfo=timezone.utc)
        draft_updated_at = datetime(2026, 6, 2, 15, 45, tzinfo=timezone.utc)

        first = await service.attach_profile(
            user_id=user.id,
            draft_id="draft-123",
            draft_created_at=draft_created_at,
            draft_updated_at=draft_updated_at,
            is_complete=True,
            current_step="summary",
            profile_payload=OnboardingProfilePayload(
                age=39,
                height_cm=175,
                peptides=["tirzepatide"],
            ),
        )
        second = await service.attach_profile(
            user_id=user.id,
            draft_id="draft-123",
            draft_created_at=draft_created_at,
            draft_updated_at=draft_updated_at,
            is_complete=True,
            current_step="summary",
            profile_payload=OnboardingProfilePayload(
                age=41,
                weight_kg=77,
                peptides=["retatrutide"],
            ),
        )

        assert second.id == first.id
        assert second.age == 39
        assert second.weight_kg is None
        assert second.peptides == ["tirzepatide"]
        assert second.source_draft_id == "draft-123"
        assert second.source_is_complete is True
        assert second.source_current_step == "summary"

    async def test_attach_profile_creates_one_pending_starter_protocol(self, service, db_session, user):
        draft_created_at = datetime(2026, 6, 1, 14, 30, tzinfo=timezone.utc)
        draft_updated_at = datetime(2026, 6, 2, 15, 45, tzinfo=timezone.utc)
        payload = OnboardingProfilePayload(
            peptides=["Retatrutide"],
            goals=["track_protocols"],
        )

        await service.attach_profile(
            user_id=user.id,
            draft_id="starter-draft-1",
            draft_created_at=draft_created_at,
            draft_updated_at=draft_updated_at,
            is_complete=True,
            current_step="summary",
            profile_payload=payload,
        )
        await service.attach_profile(
            user_id=user.id,
            draft_id="starter-draft-1",
            draft_created_at=draft_created_at,
            draft_updated_at=draft_updated_at,
            is_complete=True,
            current_step="summary",
            profile_payload=payload,
        )

        protocols = await ProtocolService(db_session).list_for_user(user.id)
        starters = [protocol for protocol in protocols if protocol.is_starter]
        assert len(starters) == 1
        assert starters[0].setup_status == "pending_setup"
        assert starters[0].compounds[0].name == "Retatrutide"

    async def test_attach_profile_with_different_draft_fills_only_empty_fields(
        self,
        service,
        user,
    ):
        original_draft_created_at = datetime(2026, 6, 1, 14, 30)
        original_draft_updated_at = datetime(2026, 6, 2, 15, 45)
        new_draft_created_at = datetime(2026, 6, 3, 10, 15)
        new_draft_updated_at = datetime(2026, 6, 4, 11, 20)

        existing = await service.attach_profile(
            user_id=user.id,
            draft_id="draft-original",
            draft_created_at=original_draft_created_at,
            draft_updated_at=original_draft_updated_at,
            is_complete=False,
            current_step="peptides",
            profile_payload=OnboardingProfilePayload(
                age=37,
                peptides=["Retatrutide"],
            ),
        )

        updated = await service.attach_profile(
            user_id=user.id,
            draft_id="draft-next",
            draft_created_at=new_draft_created_at,
            draft_updated_at=new_draft_updated_at,
            is_complete=True,
            current_step="summary",
            profile_payload=OnboardingProfilePayload(
                age=41,
                height_cm=181,
                peptides=["Semaglutide"],
                goals=["Track"],
            ),
        )

        assert updated.id == existing.id
        assert updated.age == 37
        assert updated.peptides == ["Retatrutide"]
        assert updated.height_cm == 181
        assert updated.goals == ["Track"]
        assert updated.source_draft_id == "draft-next"
        assert updated.source_draft_created_at == new_draft_created_at
        assert updated.source_draft_updated_at == new_draft_updated_at
        assert updated.source_is_complete is True
        assert updated.source_current_step == "summary"
