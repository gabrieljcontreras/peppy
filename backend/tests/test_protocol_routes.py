import pytest
from datetime import date, datetime, timedelta, timezone


class TestProtocolRoutes:
    """Integration tests for protocol API endpoints."""

    @pytest.fixture
    async def auth_headers(self, client):
        """Create a user and return auth headers."""
        await client.post(
            "/api/v1/auth/register",
            json={"email": "proto@example.com", "password": "password123"},
        )
        login_response = await client.post(
            "/api/v1/auth/login",
            json={"email": "proto@example.com", "password": "password123"},
        )
        token = login_response.json()["access_token"]
        return {"Authorization": f"Bearer {token}"}

    @pytest.fixture
    def sample_protocol(self):
        return {
            "name": "Test Protocol",
            "start_date": str(date.today()),
            "compounds": [
                {
                    "name": "Retatrutide",
                    "dose_mg": 2.0,
                    "frequency": "weekly",
                }
            ],
        }

    async def test_create_protocol(self, client, auth_headers, sample_protocol):
        response = await client.post(
            "/api/v1/protocols/",
            json=sample_protocol,
            headers=auth_headers,
        )

        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Test Protocol"
        assert data["is_active"] is True
        assert len(data["compounds"]) == 1
        assert data["compounds"][0]["name"] == "Retatrutide"
        assert data["compounds"][0]["dose_mg"] == 2.0
        assert "id" in data
        assert "created_at" in data

    async def test_create_protocol_unauthorized(self, client, sample_protocol):
        response = await client.post(
            "/api/v1/protocols/",
            json=sample_protocol,
        )
        assert response.status_code == 403

    async def test_create_protocol_no_compounds(self, client, auth_headers):
        response = await client.post(
            "/api/v1/protocols/",
            json={
                "name": "Empty Protocol",
                "start_date": str(date.today()),
                "compounds": [],
            },
            headers=auth_headers,
        )
        assert response.status_code == 422

    async def test_create_protocol_invalid_dates(self, client, auth_headers):
        response = await client.post(
            "/api/v1/protocols/",
            json={
                "name": "Invalid Dates",
                "start_date": str(date.today()),
                "end_date": str(date.today() - timedelta(days=1)),
                "compounds": [{"name": "Test", "dose_mg": 1.0, "frequency": "daily"}],
            },
            headers=auth_headers,
        )
        assert response.status_code == 422

    async def test_create_protocol_with_full_details(self, client, auth_headers):
        response = await client.post(
            "/api/v1/protocols/",
            json={
                "name": "Full Protocol",
                "start_date": str(date.today()),
                "end_date": str(date.today() + timedelta(days=90)),
                "notes": "12-week plan",
                "compounds": [
                    {
                        "name": "Tirzepatide",
                        "dose_mg": 5.0,
                        "dose_unit": "mg",
                        "frequency": "weekly",
                        "administration_route": "subcutaneous",
                        "notes": "Rotate injection sites",
                    }
                ],
            },
            headers=auth_headers,
        )

        assert response.status_code == 201
        data = response.json()
        assert data["notes"] == "12-week plan"
        assert data["compounds"][0]["notes"] == "Rotate injection sites"
        assert data["compounds"][0]["administration_route"] == "subcutaneous"

    async def test_list_protocols_empty(self, client, auth_headers):
        response = await client.get(
            "/api/v1/protocols/",
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert response.json() == []

    async def test_list_protocols(self, client, auth_headers, sample_protocol):
        # Create two protocols
        await client.post("/api/v1/protocols/", json=sample_protocol, headers=auth_headers)
        sample_protocol["name"] = "Second Protocol"
        await client.post("/api/v1/protocols/", json=sample_protocol, headers=auth_headers)

        response = await client.get("/api/v1/protocols/", headers=auth_headers)
        assert response.status_code == 200
        protocols = response.json()
        assert len(protocols) == 2

    async def test_list_protocols_exclude_inactive(self, client, auth_headers, sample_protocol):
        # Create first (will become inactive)
        first = await client.post("/api/v1/protocols/", json=sample_protocol, headers=auth_headers)
        first_id = first.json()["id"]

        # Create second (active)
        sample_protocol["name"] = "Active Protocol"
        await client.post("/api/v1/protocols/", json=sample_protocol, headers=auth_headers)

        # List all
        all_response = await client.get(
            "/api/v1/protocols/?include_inactive=true",
            headers=auth_headers,
        )
        assert len(all_response.json()) == 2

        # List active only
        active_response = await client.get(
            "/api/v1/protocols/?include_inactive=false",
            headers=auth_headers,
        )
        assert len(active_response.json()) == 1
        assert active_response.json()[0]["name"] == "Active Protocol"

    async def test_get_active_protocol(self, client, auth_headers, sample_protocol):
        await client.post("/api/v1/protocols/", json=sample_protocol, headers=auth_headers)

        response = await client.get("/api/v1/protocols/active", headers=auth_headers)
        assert response.status_code == 200
        assert response.json()["name"] == "Test Protocol"
        assert response.json()["is_active"] is True

    async def test_get_active_protocol_none(self, client, auth_headers):
        response = await client.get("/api/v1/protocols/active", headers=auth_headers)
        assert response.status_code == 200
        assert response.json() is None

    async def test_get_protocol_by_id(self, client, auth_headers, sample_protocol):
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        protocol_id = create_response.json()["id"]

        response = await client.get(f"/api/v1/protocols/{protocol_id}", headers=auth_headers)
        assert response.status_code == 200
        assert response.json()["id"] == protocol_id
        assert response.json()["name"] == "Test Protocol"

    async def test_get_protocol_not_found(self, client, auth_headers):
        fake_id = "00000000-0000-0000-0000-000000000000"
        response = await client.get(f"/api/v1/protocols/{fake_id}", headers=auth_headers)
        assert response.status_code == 404

    async def test_update_protocol(self, client, auth_headers, sample_protocol):
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        protocol_id = create_response.json()["id"]

        response = await client.patch(
            f"/api/v1/protocols/{protocol_id}",
            json={"name": "Updated Name", "notes": "Some notes"},
            headers=auth_headers,
        )

        assert response.status_code == 200
        assert response.json()["name"] == "Updated Name"
        assert response.json()["notes"] == "Some notes"

    async def test_update_protocol_not_found(self, client, auth_headers):
        fake_id = "00000000-0000-0000-0000-000000000000"
        response = await client.patch(
            f"/api/v1/protocols/{fake_id}",
            json={"name": "New Name"},
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_activate_pending_starter_protocol_applies_setup_payload(
        self,
        client,
        auth_headers,
    ):
        await client.post(
            "/api/v1/profile/onboarding/attach",
            json={
                "draft_id": "starter-activation-route",
                "is_complete": True,
                "current_step": "summary",
                "profile": {
                    "age": 38,
                    "peptides": ["Retatrutide"],
                },
            },
            headers=auth_headers,
        )
        protocols_response = await client.get(
            "/api/v1/protocols/",
            headers=auth_headers,
        )
        starter = next(
            protocol
            for protocol in protocols_response.json()
            if protocol["setup_status"] == "pending_setup"
        )

        start_date = datetime(2026, 7, 1, 12, 0, tzinfo=timezone.utc)
        response = await client.post(
            f"/api/v1/protocols/{starter['id']}/activate",
            json={
                "dose_mg": 2.0,
                "dose_unit": "mg",
                "frequency": "weekly",
                "administration_route": "subcutaneous",
                "start_date": start_date.isoformat(),
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["is_active"] is True
        assert data["setup_status"] == "active"
        assert data["start_date"] == "2026-07-01"
        assert data["compounds"][0]["dose_mg"] == 2.0
        assert data["compounds"][0]["dose_unit"] == "mg"
        assert data["compounds"][0]["frequency"] == "weekly"
        assert data["compounds"][0]["administration_route"] == "subcutaneous"

    async def test_replace_compounds(self, client, auth_headers, sample_protocol):
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        protocol_id = create_response.json()["id"]
        original_compound_id = create_response.json()["compounds"][0]["id"]

        response = await client.put(
            f"/api/v1/protocols/{protocol_id}/compounds",
            json={
                "compounds": [
                    {"name": "Tirzepatide", "dose_mg": 5.0, "frequency": "weekly"},
                    {"name": "BPC-157", "dose_mg": 250, "frequency": "daily"},
                ]
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        compounds = response.json()["compounds"]
        assert len(compounds) == 2
        assert all(c["id"] != original_compound_id for c in compounds)
        assert {c["name"] for c in compounds} == {"Tirzepatide", "BPC-157"}

    async def test_add_compound(self, client, auth_headers, sample_protocol):
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        protocol_id = create_response.json()["id"]

        response = await client.post(
            f"/api/v1/protocols/{protocol_id}/compounds",
            json={"name": "BPC-157", "dose_mg": 250, "dose_unit": "mcg", "frequency": "daily"},
            headers=auth_headers,
        )

        assert response.status_code == 201
        assert response.json()["name"] == "BPC-157"
        assert response.json()["dose_unit"] == "mcg"

        # Verify protocol now has 2 compounds
        get_response = await client.get(f"/api/v1/protocols/{protocol_id}", headers=auth_headers)
        assert len(get_response.json()["compounds"]) == 2

    async def test_update_compound(self, client, auth_headers, sample_protocol):
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        compound_id = create_response.json()["compounds"][0]["id"]

        response = await client.patch(
            f"/api/v1/protocols/compounds/{compound_id}",
            json={"dose_mg": 4.0, "notes": "Increased dose"},
            headers=auth_headers,
        )

        assert response.status_code == 200
        assert response.json()["dose_mg"] == 4.0
        assert response.json()["notes"] == "Increased dose"
        assert response.json()["name"] == "Retatrutide"  # unchanged

    async def test_update_compound_not_found(self, client, auth_headers):
        fake_id = "00000000-0000-0000-0000-000000000000"
        response = await client.patch(
            f"/api/v1/protocols/compounds/{fake_id}",
            json={"dose_mg": 5.0},
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_remove_compound(self, client, auth_headers):
        # Create protocol with 2 compounds
        create_response = await client.post(
            "/api/v1/protocols/",
            json={
                "name": "Multi Compound",
                "start_date": str(date.today()),
                "compounds": [
                    {"name": "Semaglutide", "dose_mg": 0.5, "frequency": "weekly"},
                    {"name": "BPC-157", "dose_mg": 250, "frequency": "daily"},
                ],
            },
            headers=auth_headers,
        )
        protocol_id = create_response.json()["id"]
        compounds = create_response.json()["compounds"]
        compound_to_remove = next(c for c in compounds if c["name"] == "BPC-157")

        response = await client.delete(
            f"/api/v1/protocols/compounds/{compound_to_remove['id']}",
            headers=auth_headers,
        )
        assert response.status_code == 204

        # Verify only one compound remains
        get_response = await client.get(f"/api/v1/protocols/{protocol_id}", headers=auth_headers)
        remaining = get_response.json()["compounds"]
        assert len(remaining) == 1
        assert remaining[0]["name"] == "Semaglutide"

    async def test_remove_last_compound_fails(self, client, auth_headers, sample_protocol):
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        compound_id = create_response.json()["compounds"][0]["id"]

        response = await client.delete(
            f"/api/v1/protocols/compounds/{compound_id}",
            headers=auth_headers,
        )
        assert response.status_code == 400
        assert "Cannot remove the last compound" in response.json()["detail"]

    async def test_deactivate_protocol(self, client, auth_headers, sample_protocol):
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        protocol_id = create_response.json()["id"]

        response = await client.post(
            f"/api/v1/protocols/{protocol_id}/deactivate",
            headers=auth_headers,
        )

        assert response.status_code == 200
        assert response.json()["is_active"] is False
        assert response.json()["end_date"] == str(date.today())

    async def test_deactivate_already_inactive_fails(self, client, auth_headers, sample_protocol):
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        protocol_id = create_response.json()["id"]

        # Deactivate once
        await client.post(f"/api/v1/protocols/{protocol_id}/deactivate", headers=auth_headers)

        # Try again
        response = await client.post(
            f"/api/v1/protocols/{protocol_id}/deactivate",
            headers=auth_headers,
        )
        assert response.status_code == 400
        assert "already inactive" in response.json()["detail"]

    async def test_delete_protocol(self, client, auth_headers, sample_protocol):
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        protocol_id = create_response.json()["id"]

        response = await client.delete(
            f"/api/v1/protocols/{protocol_id}",
            headers=auth_headers,
        )
        assert response.status_code == 204

        # Verify deleted
        get_response = await client.get(f"/api/v1/protocols/{protocol_id}", headers=auth_headers)
        assert get_response.status_code == 404

    async def test_delete_protocol_not_found(self, client, auth_headers):
        fake_id = "00000000-0000-0000-0000-000000000000"
        response = await client.delete(
            f"/api/v1/protocols/{fake_id}",
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_protocol_isolation_between_users(self, client, auth_headers, sample_protocol):
        # Create protocol as first user
        create_response = await client.post(
            "/api/v1/protocols/", json=sample_protocol, headers=auth_headers
        )
        protocol_id = create_response.json()["id"]

        # Create second user
        await client.post(
            "/api/v1/auth/register",
            json={"email": "other@example.com", "password": "password123"},
        )
        other_login = await client.post(
            "/api/v1/auth/login",
            json={"email": "other@example.com", "password": "password123"},
        )
        other_headers = {"Authorization": f"Bearer {other_login.json()['access_token']}"}

        # Second user shouldn't see first user's protocol
        response = await client.get(f"/api/v1/protocols/{protocol_id}", headers=other_headers)
        assert response.status_code == 404

        # Second user's list should be empty
        list_response = await client.get("/api/v1/protocols/", headers=other_headers)
        assert list_response.json() == []

    async def test_pagination(self, client, auth_headers):
        # Create 5 protocols
        for i in range(5):
            await client.post(
                "/api/v1/protocols/",
                json={
                    "name": f"Protocol {i}",
                    "start_date": str(date.today() - timedelta(days=i)),
                    "compounds": [{"name": "Test", "dose_mg": 1.0, "frequency": "daily"}],
                },
                headers=auth_headers,
            )

        # Test limit
        response = await client.get("/api/v1/protocols/?limit=2", headers=auth_headers)
        assert len(response.json()) == 2

        # Test offset
        response = await client.get("/api/v1/protocols/?offset=3", headers=auth_headers)
        assert len(response.json()) == 2  # 5 total - 3 skipped = 2

        # Test limit + offset
        response = await client.get("/api/v1/protocols/?limit=2&offset=2", headers=auth_headers)
        assert len(response.json()) == 2
