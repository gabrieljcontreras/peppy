from datetime import date, timedelta

import pytest
from pydantic import ValidationError

from app.api.routes.auth import UserUpdate
from app.models.profile import OnboardingProfile
from app.models.user import User
from app.services.profile import OnboardingProfileService


@pytest.fixture
async def auth_headers(client):
    await client.post(
        "/api/v1/auth/register",
        json={"email": "settings-profile@example.com", "password": "password123"},
    )
    login_response = await client.post(
        "/api/v1/auth/login",
        json={"email": "settings-profile@example.com", "password": "password123"},
    )
    token = login_response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def test_patch_me_updates_name_and_timezone_but_not_email(client, auth_headers):
    response = await client.patch(
        "/api/v1/auth/me",
        headers=auth_headers,
        json={"display_name": "  Alex Morgan  ", "timezone": "America/New_York"},
    )
    assert response.status_code == 200
    assert response.json()["display_name"] == "Alex Morgan"
    assert response.json()["timezone"] == "America/New_York"

    rejected = await client.patch(
        "/api/v1/auth/me",
        headers=auth_headers,
        json={"email": "changed@example.com"},
    )
    assert rejected.status_code == 422


async def test_patch_me_rejects_invalid_timezone(client, auth_headers):
    response = await client.patch(
        "/api/v1/auth/me",
        headers=auth_headers,
        json={"timezone": "Not/A_Timezone"},
    )

    assert response.status_code == 422


def test_user_update_rejects_explicit_null_timezone():
    with pytest.raises(ValidationError):
        UserUpdate.model_validate({"timezone": None})


async def test_profile_patch_creates_record_and_clears_optional_goal(client, auth_headers):
    created = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={
            "baseline_date": "2026-05-01",
            "weight_kg": 84.55,
            "height_cm": 177.8,
            "preferred_weight_unit": "lb",
            "preferred_height_unit": "ft_in",
            "primary_goal": "track_protocols",
            "secondary_goal": "build_habits",
            "focus_area": "understand_body",
        },
    )
    assert created.status_code == 200
    assert created.json()["primary_goal"] == "track_protocols"

    cleared = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"secondary_goal": None, "focus_area": None},
    )
    assert cleared.status_code == 200
    assert cleared.json()["secondary_goal"] is None
    assert cleared.json()["focus_area"] is None

    missing_primary = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"primary_goal": None},
    )
    assert missing_primary.status_code == 422


async def test_profile_patch_rejects_unsupported_ordered_goal(client, auth_headers):
    response = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"primary_goal": "weight_loss"},
    )

    assert response.status_code == 422


async def test_profile_patch_rejects_future_baseline_date(client, auth_headers):
    response = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"baseline_date": (date.today() + timedelta(days=1)).isoformat()},
    )

    assert response.status_code == 422


async def test_legacy_goals_derive_ordered_goals_without_mutation(db_session):
    user = User(email="legacy-settings-profile@example.com", hashed_password="hash")
    legacy_goals = ["track_protocols", "build_habits", "custom"]
    profile = OnboardingProfile(user=user, goals=list(legacy_goals))
    db_session.add(profile)
    await db_session.commit()
    await db_session.refresh(profile)

    payload = OnboardingProfileService(db_session).to_payload(profile)

    assert payload["primary_goal"] == "track_protocols"
    assert payload["secondary_goal"] == "build_habits"
    assert payload["goals"] == legacy_goals
    assert profile.goals == legacy_goals


async def test_clearing_legacy_secondary_goal_stays_cleared(client, auth_headers):
    legacy_goals = ["track_protocols", "build_habits", "custom"]
    seeded = await client.put(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"goals": legacy_goals},
    )
    assert seeded.status_code == 200
    assert seeded.json()["secondary_goal"] == "build_habits"

    cleared = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"secondary_goal": None},
    )
    fetched = await client.get(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
    )

    assert cleared.status_code == 200
    assert cleared.json()["secondary_goal"] is None
    assert fetched.status_code == 200
    assert fetched.json()["secondary_goal"] is None
    assert fetched.json()["goals"] == legacy_goals


async def test_replacing_legacy_goals_while_clearing_secondary_stays_cleared(
    client,
    auth_headers,
):
    seeded = await client.put(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"goals": ["custom"]},
    )
    assert seeded.status_code == 200

    replacement_goals = ["track_protocols", "build_habits"]
    cleared = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"goals": replacement_goals, "secondary_goal": None},
    )
    fetched = await client.get(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
    )

    assert cleared.status_code == 200
    assert cleared.json()["primary_goal"] == "track_protocols"
    assert cleared.json()["secondary_goal"] is None
    assert fetched.status_code == 200
    assert fetched.json()["secondary_goal"] is None
    assert fetched.json()["goals"] == replacement_goals


async def test_profile_patch_rejects_secondary_without_effective_primary(
    client,
    auth_headers,
):
    response = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"secondary_goal": "build_habits"},
    )

    assert response.status_code == 422


async def test_profile_put_enforces_effective_primary_for_secondary(
    client,
    auth_headers,
):
    rejected = await client.put(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"secondary_goal": "build_habits"},
    )
    assert rejected.status_code == 422

    accepted = await client.put(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={
            "primary_goal": "track_protocols",
            "secondary_goal": "build_habits",
        },
    )
    assert accepted.status_code == 200
    assert accepted.json()["primary_goal"] == "track_protocols"
    assert accepted.json()["secondary_goal"] == "build_habits"


async def test_profile_attach_enforces_effective_primary_for_secondary(
    client,
    auth_headers,
):
    rejected = await client.post(
        "/api/v1/profile/onboarding/attach",
        headers=auth_headers,
        json={
            "draft_id": "invalid-ordered-goals",
            "is_complete": False,
            "profile": {"secondary_goal": "build_habits"},
        },
    )
    assert rejected.status_code == 422

    accepted = await client.post(
        "/api/v1/profile/onboarding/attach",
        headers=auth_headers,
        json={
            "draft_id": "valid-ordered-goals",
            "is_complete": False,
            "profile": {
                "primary_goal": "track_protocols",
                "secondary_goal": "build_habits",
            },
        },
    )
    assert accepted.status_code == 201
    assert accepted.json()["primary_goal"] == "track_protocols"
    assert accepted.json()["secondary_goal"] == "build_habits"
