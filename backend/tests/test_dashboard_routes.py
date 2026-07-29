import pytest


@pytest.fixture
async def auth_headers(client):
    await client.post(
        "/api/v1/auth/register",
        json={"email": "dashboard_route@example.com", "password": "password123"},
    )
    login_response = await client.post(
        "/api/v1/auth/login",
        json={"email": "dashboard_route@example.com", "password": "password123"},
    )
    token = login_response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def test_dashboard_summary_requires_auth(client):
    response = await client.get("/api/v1/dashboard/summary")

    assert response.status_code == 403


async def test_dashboard_summary_returns_attached_pending_starter(client, premium_auth_headers):
    attach_response = await client.post(
        "/api/v1/profile/onboarding/attach",
        headers=premium_auth_headers,
        json={
            "schema_version": 1,
            "draft_id": "dashboard-route-draft",
            "draft_created_at": "2026-06-30T12:00:00Z",
            "draft_updated_at": "2026-06-30T12:05:00Z",
            "is_complete": True,
            "current_step": "summary",
            "profile": {
                "schema_version": 1,
                "peptides": ["Retatrutide"],
                "goals": ["track_protocols"],
                "healthkit": {"requested": True},
            },
        },
    )
    assert attach_response.status_code == 201

    response = await client.get("/api/v1/dashboard/summary", headers=premium_auth_headers)

    assert response.status_code == 200
    data = response.json()
    assert data["profile_status"] == "present"
    assert data["protocol"]["status"] == "pending_setup"
    assert data["protocol"]["title"] == "Starter protocol"
    assert data["protocol"]["compounds"] == ["Retatrutide"]
    assert data["today_checkin"]["logged"] is False
    assert data["connected_context"]["healthkit_requested"] is True
    assert data["protocol"]["start_date"] is not None
    assert data["insight"]["confidence"] is None
    assert data["recent_activity"] == []
