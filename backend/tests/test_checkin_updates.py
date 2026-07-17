import pytest


@pytest.fixture
async def auth_headers(client):
    await client.post(
        "/api/v1/auth/register",
        json={"email": "checkin_update@example.com", "password": "password123"},
    )
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "checkin_update@example.com", "password": "password123"},
    )
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def create_checkin(client, auth_headers):
    response = await client.post(
        "/api/v1/checkins",
        headers=auth_headers,
        json={
            "date": "2026-07-17",
            "weight_kg": 74.8,
            "energy_level": 7,
            "mood": 8,
            "notes": "Original note",
        },
    )
    assert response.status_code == 201
    return response.json()


async def test_patch_omitted_fields_preserve_existing_values(client, auth_headers):
    created = await create_checkin(client, auth_headers)

    response = await client.patch(
        f"/api/v1/checkins/{created['id']}",
        headers=auth_headers,
        json={"energy_level": 9},
    )

    assert response.status_code == 200
    assert response.json()["energy_level"] == 9
    assert response.json()["weight_kg"] == 74.8
    assert response.json()["notes"] == "Original note"


async def test_patch_explicit_null_clears_optional_values(client, auth_headers):
    created = await create_checkin(client, auth_headers)

    response = await client.patch(
        f"/api/v1/checkins/{created['id']}",
        headers=auth_headers,
        json={"weight_kg": None, "notes": None, "mood": None},
    )

    assert response.status_code == 200
    assert response.json()["weight_kg"] is None
    assert response.json()["notes"] is None
    assert response.json()["mood"] is None
    assert response.json()["energy_level"] == 7
