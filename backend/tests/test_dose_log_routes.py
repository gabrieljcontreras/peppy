from datetime import date, datetime, timezone

import pytest


class TestDoseLogRoutes:
    @pytest.fixture
    async def auth_headers(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "dose-log-routes@example.com", "password": "password123"},
        )
        login_response = await client.post(
            "/api/v1/auth/login",
            json={"email": "dose-log-routes@example.com", "password": "password123"},
        )
        token = login_response.json()["access_token"]
        return {"Authorization": f"Bearer {token}"}

    async def _create_protocol(self, client, headers, name="Dose Log Protocol"):
        response = await client.post(
            "/api/v1/protocols",
            headers=headers,
            json={
                "name": name,
                "start_date": str(date.today()),
                "compounds": [
                    {
                        "name": "Retatrutide",
                        "dose_mg": 2.0,
                        "frequency": "weekly",
                    }
                ],
            },
        )
        assert response.status_code == 201
        return response.json()

    async def test_create_dose_log(self, client, auth_headers):
        protocol = await self._create_protocol(client, auth_headers)
        compound = protocol["compounds"][0]

        response = await client.post(
            "/api/v1/dose-logs",
            headers=auth_headers,
            json={
                "protocol_id": protocol["id"],
                "compound_id": compound["id"],
                "dose": 2.5,
                "unit": "mg",
                "administered_at": "2026-07-08T14:30:00Z",
                "route": "subcutaneous",
                "notes": None,
            },
        )

        assert response.status_code == 201
        assert response.json()["dose"] == 2.5
        assert response.json()["compound_id"] == compound["id"]

    async def test_create_dose_log_normalizes_offset_timestamp_to_utc(self, client, auth_headers):
        protocol = await self._create_protocol(client, auth_headers)
        compound = protocol["compounds"][0]

        response = await client.post(
            "/api/v1/dose-logs",
            headers=auth_headers,
            json={
                "protocol_id": protocol["id"],
                "compound_id": compound["id"],
                "dose": 2.5,
                "unit": "mg",
                "administered_at": "2026-07-08T10:30:00-04:00",
                "route": "subcutaneous",
                "notes": None,
            },
        )

        assert response.status_code == 201
        administered_at = datetime.fromisoformat(response.json()["administered_at"].replace("Z", "+00:00"))
        assert administered_at == datetime(2026, 7, 8, 14, 30, tzinfo=timezone.utc)

    async def test_list_protocol_dose_logs(self, client, auth_headers):
        protocol = await self._create_protocol(client, auth_headers)
        compound = protocol["compounds"][0]

        first = await client.post(
            "/api/v1/dose-logs",
            headers=auth_headers,
            json={
                "protocol_id": protocol["id"],
                "compound_id": compound["id"],
                "dose": 2.0,
                "unit": "mg",
                "administered_at": "2026-07-08T08:30:00Z",
                "route": "subcutaneous",
                "notes": None,
            },
        )
        assert first.status_code == 201

        second = await client.post(
            "/api/v1/dose-logs",
            headers=auth_headers,
            json={
                "protocol_id": protocol["id"],
                "compound_id": compound["id"],
                "dose": 3.0,
                "unit": "mg",
                "administered_at": "2026-07-08T16:30:00Z",
                "route": "subcutaneous",
                "notes": "Evening dose",
            },
        )
        assert second.status_code == 201

        response = await client.get(
            f"/api/v1/protocols/{protocol['id']}/dose-logs",
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert [log["dose"] for log in data] == [3.0, 2.0]

    async def test_create_dose_log_invalid_dose(self, client, auth_headers):
        protocol = await self._create_protocol(client, auth_headers)
        compound = protocol["compounds"][0]

        response = await client.post(
            "/api/v1/dose-logs",
            headers=auth_headers,
            json={
                "protocol_id": protocol["id"],
                "compound_id": compound["id"],
                "dose": 0,
                "unit": "mg",
                "administered_at": "2026-07-08T14:30:00Z",
                "route": "subcutaneous",
                "notes": None,
            },
        )

        assert response.status_code == 422

    async def test_create_dose_log_rejects_naive_administered_at(self, client, auth_headers):
        protocol = await self._create_protocol(client, auth_headers)
        compound = protocol["compounds"][0]

        response = await client.post(
            "/api/v1/dose-logs",
            headers=auth_headers,
            json={
                "protocol_id": protocol["id"],
                "compound_id": compound["id"],
                "dose": 2.5,
                "unit": "mg",
                "administered_at": "2026-07-08T14:30:00",
                "route": "subcutaneous",
                "notes": None,
            },
        )

        assert response.status_code == 422

    async def test_create_dose_log_mismatched_compound(self, client, auth_headers):
        first_protocol = await self._create_protocol(client, auth_headers, name="First Dose Log Protocol")
        second_protocol = await self._create_protocol(client, auth_headers, name="Second Dose Log Protocol")

        response = await client.post(
            "/api/v1/dose-logs",
            headers=auth_headers,
            json={
                "protocol_id": first_protocol["id"],
                "compound_id": second_protocol["compounds"][0]["id"],
                "dose": 2.5,
                "unit": "mg",
                "administered_at": "2026-07-08T14:30:00Z",
                "route": "subcutaneous",
                "notes": None,
            },
        )

        assert response.status_code == 400

    async def test_create_dose_log_foreign_protocol(self, client, auth_headers):
        protocol = await self._create_protocol(client, auth_headers)

        await client.post(
            "/api/v1/auth/register",
            json={"email": "dose-log-routes-other@example.com", "password": "password123"},
        )
        other_login = await client.post(
            "/api/v1/auth/login",
            json={"email": "dose-log-routes-other@example.com", "password": "password123"},
        )
        other_headers = {
            "Authorization": f"Bearer {other_login.json()['access_token']}",
        }

        response = await client.post(
            "/api/v1/dose-logs",
            headers=other_headers,
            json={
                "protocol_id": protocol["id"],
                "compound_id": protocol["compounds"][0]["id"],
                "dose": 2.5,
                "unit": "mg",
                "administered_at": "2026-07-08T14:30:00Z",
                "route": "subcutaneous",
                "notes": None,
            },
        )

        assert response.status_code == 404

    async def test_create_dose_log_missing_auth_uses_app_wide_403(self, client):
        response = await client.post(
            "/api/v1/dose-logs",
            json={
                "protocol_id": "00000000-0000-0000-0000-000000000000",
                "compound_id": "00000000-0000-0000-0000-000000000000",
                "dose": 2.5,
                "unit": "mg",
                "administered_at": "2026-07-08T14:30:00Z",
                "route": "subcutaneous",
                "notes": None,
            },
        )

        assert response.status_code == 403

    async def test_create_dose_log_invalid_token_returns_401(self, client):
        response = await client.post(
            "/api/v1/dose-logs",
            headers={"Authorization": "Bearer invalid"},
            json={
                "protocol_id": "00000000-0000-0000-0000-000000000000",
                "compound_id": "00000000-0000-0000-0000-000000000000",
                "dose": 2.5,
                "unit": "mg",
                "administered_at": "2026-07-08T14:30:00Z",
                "route": "subcutaneous",
                "notes": None,
            },
        )

        assert response.status_code == 401
