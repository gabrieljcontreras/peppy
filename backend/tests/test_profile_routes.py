from datetime import datetime, timezone

import pytest


class TestOnboardingProfileRoutes:
    @pytest.fixture
    async def auth_headers(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "profile_routes@example.com", "password": "password123"},
        )
        login_response = await client.post(
            "/api/v1/auth/login",
            json={"email": "profile_routes@example.com", "password": "password123"},
        )
        token = login_response.json()["access_token"]
        return {"Authorization": f"Bearer {token}"}

    async def test_auth_required(self, client):
        response = await client.get("/api/v1/profile/onboarding")

        assert response.status_code == 403

    async def test_put_and_get_onboarding_profile(self, client, auth_headers):
        payload = {
            "age": 44,
            "height_cm": 182,
            "preferred_height_unit": "cm",
            "weight_kg": 94.5,
            "preferred_weight_unit": "kg",
            "peptides": [" retatrutide ", "retatrutide", "bpc-157"],
            "custom_peptides": ["custom stack"],
            "other_medications": "metformin",
            "workout_days_per_week": 5,
            "goals": ["weight_loss", "weight_loss", "energy"],
            "custom_goal": "Improve recovery",
            "healthkit": {"requested": True, "last_sync_at": None},
            "notifications": {"authorized": False},
        }

        put_response = await client.put(
            "/api/v1/profile/onboarding",
            json=payload,
            headers=auth_headers,
        )
        get_response = await client.get(
            "/api/v1/profile/onboarding",
            headers=auth_headers,
        )

        assert put_response.status_code == 200
        assert get_response.status_code == 200
        data = get_response.json()
        assert data["age"] == 44
        assert data["height_cm"] == 182
        assert data["peptides"] == ["retatrutide", "bpc-157"]
        assert data["goals"] == ["weight_loss", "energy"]
        assert data["healthkit"] == {"requested": True, "last_sync_at": None}
        assert data["notifications"] == {"authorized": False}

    async def test_patch_onboarding_profile(self, client, auth_headers):
        await client.put(
            "/api/v1/profile/onboarding",
            json={"age": 38, "weight_kg": 88, "peptides": ["semaglutide"]},
            headers=auth_headers,
        )

        response = await client.patch(
            "/api/v1/profile/onboarding",
            json={"weight_kg": 86.4, "goals": ["lean_mass"]},
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["age"] == 38
        assert data["weight_kg"] == 86.4
        assert data["peptides"] == ["semaglutide"]
        assert data["goals"] == ["lean_mass"]

    async def test_attach_onboarding_profile_is_idempotent(self, client, auth_headers):
        draft_created_at = datetime(2026, 6, 1, 14, 30, tzinfo=timezone.utc).isoformat()
        draft_updated_at = datetime(2026, 6, 2, 15, 45, tzinfo=timezone.utc).isoformat()
        payload = {
            "draft_id": "draft-route-123",
            "draft_created_at": draft_created_at,
            "draft_updated_at": draft_updated_at,
            "is_complete": True,
            "current_step": "summary",
            "profile": {
                "age": 40,
                "height_cm": 177,
                "peptides": ["tirzepatide"],
            },
        }

        first = await client.post(
            "/api/v1/profile/onboarding/attach",
            json=payload,
            headers=auth_headers,
        )
        second = await client.post(
            "/api/v1/profile/onboarding/attach",
            json={
                **payload,
                "profile": {
                    "age": 41,
                    "weight_kg": 79,
                    "peptides": ["retatrutide"],
                },
            },
            headers=auth_headers,
        )

        assert first.status_code == 201
        assert second.status_code == 201
        first_data = first.json()
        second_data = second.json()
        assert second_data["id"] == first_data["id"]
        assert second_data["age"] == 40
        assert second_data["weight_kg"] is None
        assert second_data["peptides"] == ["tirzepatide"]
        assert second_data["source_draft_id"] == "draft-route-123"
        assert second_data["source_is_complete"] is True

    async def test_attach_rejects_unsupported_top_level_schema_version(
        self,
        client,
        auth_headers,
    ):
        response = await client.post(
            "/api/v1/profile/onboarding/attach",
            json={
                "schema_version": 2,
                "draft_id": "draft-route-version-2",
                "is_complete": False,
                "current_step": "intro",
                "profile": {"age": 40},
            },
            headers=auth_headers,
        )

        assert response.status_code == 422
