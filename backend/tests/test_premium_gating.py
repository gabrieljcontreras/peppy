import pytest


@pytest.mark.anyio
async def test_free_user_cannot_list_insights(client, auth_headers):
    response = await client.get("/api/v1/insights", headers=auth_headers)

    assert response.status_code == 402
    assert response.json()["detail"] == "premium_required"


@pytest.mark.anyio
async def test_free_user_cannot_read_weekly_summary(client, auth_headers):
    response = await client.get("/api/v1/insights/summary/weekly", headers=auth_headers)

    assert response.status_code == 402


@pytest.mark.anyio
async def test_free_user_cannot_export_data(client, auth_headers):
    response = await client.post(
        "/api/v1/profile/export", headers=auth_headers, json={"format": "csv"}
    )

    assert response.status_code == 402


@pytest.mark.anyio
async def test_premium_user_can_list_insights(client, premium_auth_headers):
    response = await client.get("/api/v1/insights", headers=premium_auth_headers)

    assert response.status_code == 200


@pytest.mark.anyio
async def test_dashboard_hides_insight_from_free_user(client, auth_headers):
    response = await client.get("/api/v1/dashboard/summary", headers=auth_headers)

    assert response.status_code == 200
    assert response.json()["insight"] is None
