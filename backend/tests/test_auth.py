import pytest
from app.services.auth import hash_password, verify_password, create_access_token, create_refresh_token, decode_token


class TestPasswordHashing:
    def test_hash_password_returns_different_string(self):
        password = "secure_password_123"
        hashed = hash_password(password)
        assert hashed != password

    def test_verify_correct_password(self):
        password = "secure_password_123"
        hashed = hash_password(password)
        assert verify_password(password, hashed) is True

    def test_verify_wrong_password(self):
        password = "secure_password_123"
        hashed = hash_password(password)
        assert verify_password("wrong_password", hashed) is False

    def test_same_password_different_hashes(self):
        password = "secure_password_123"
        hash1 = hash_password(password)
        hash2 = hash_password(password)
        assert hash1 != hash2  # bcrypt uses random salt


class TestTokenCreation:
    def test_create_access_token(self):
        data = {"sub": "user-123"}
        token = create_access_token(data)
        assert token is not None
        assert isinstance(token, str)

    def test_access_token_contains_correct_data(self):
        data = {"sub": "user-123"}
        token = create_access_token(data)
        decoded = decode_token(token)
        assert decoded is not None
        assert decoded["sub"] == "user-123"
        assert decoded["type"] == "access"

    def test_create_refresh_token(self):
        data = {"sub": "user-123"}
        token = create_refresh_token(data)
        decoded = decode_token(token)
        assert decoded is not None
        assert decoded["sub"] == "user-123"
        assert decoded["type"] == "refresh"

    def test_invalid_token_returns_none(self):
        result = decode_token("invalid.token.here")
        assert result is None

    def test_empty_token_returns_none(self):
        result = decode_token("")
        assert result is None


class TestRegisterEndpoint:
    @pytest.mark.asyncio
    async def test_register_success(self, client):
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "test@example.com",
                "password": "password123",
                "display_name": "Test User",
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["email"] == "test@example.com"
        assert data["display_name"] == "Test User"
        assert "id" in data
        assert "is_verified" in data

    @pytest.mark.asyncio
    async def test_register_duplicate_email(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "duplicate@example.com", "password": "password123"},
        )
        response = await client.post(
            "/api/v1/auth/register",
            json={"email": "duplicate@example.com", "password": "password456"},
        )
        assert response.status_code == 400
        assert "already exists" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_register_invalid_email(self, client):
        response = await client.post(
            "/api/v1/auth/register",
            json={"email": "not-an-email", "password": "password123"},
        )
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_register_short_password(self, client):
        response = await client.post(
            "/api/v1/auth/register",
            json={"email": "test2@example.com", "password": "short"},
        )
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_register_email_normalized_to_lowercase(self, client):
        response = await client.post(
            "/api/v1/auth/register",
            json={"email": "TEST@EXAMPLE.COM", "password": "password123"},
        )
        assert response.status_code == 201
        assert response.json()["email"] == "test@example.com"


class TestLoginEndpoint:
    @pytest.mark.asyncio
    async def test_login_success(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "login@example.com", "password": "password123"},
        )
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "login@example.com", "password": "password123"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.asyncio
    async def test_login_wrong_password(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "login2@example.com", "password": "password123"},
        )
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "login2@example.com", "password": "wrongpassword"},
        )
        assert response.status_code == 401
        assert "Invalid email or password" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_login_nonexistent_user(self, client):
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "nonexistent@example.com", "password": "password123"},
        )
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_login_case_insensitive_email(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "casetest@example.com", "password": "password123"},
        )
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "CASETEST@EXAMPLE.COM", "password": "password123"},
        )
        assert response.status_code == 200


class TestRefreshEndpoint:
    @pytest.mark.asyncio
    async def test_refresh_success(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "refresh@example.com", "password": "password123"},
        )
        login_response = await client.post(
            "/api/v1/auth/login",
            json={"email": "refresh@example.com", "password": "password123"},
        )
        refresh_token = login_response.json()["refresh_token"]

        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data

    @pytest.mark.asyncio
    async def test_refresh_invalid_token(self, client):
        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "invalid.token.here"},
        )
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_refresh_with_access_token_fails(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "refresh2@example.com", "password": "password123"},
        )
        login_response = await client.post(
            "/api/v1/auth/login",
            json={"email": "refresh2@example.com", "password": "password123"},
        )
        access_token = login_response.json()["access_token"]

        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": access_token},
        )
        assert response.status_code == 401
        assert "Invalid token type" in response.json()["detail"]


class TestMeEndpoint:
    @pytest.mark.asyncio
    async def test_get_me_success(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "me@example.com", "password": "password123", "display_name": "Me User"},
        )
        login_response = await client.post(
            "/api/v1/auth/login",
            json={"email": "me@example.com", "password": "password123"},
        )
        access_token = login_response.json()["access_token"]

        response = await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["email"] == "me@example.com"
        assert data["display_name"] == "Me User"

    @pytest.mark.asyncio
    async def test_get_me_no_token(self, client):
        response = await client.get("/api/v1/auth/me")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_me_invalid_token(self, client):
        response = await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer invalid.token.here"},
        )
        assert response.status_code == 401


class TestLogoutEndpoint:
    @pytest.mark.asyncio
    async def test_logout_success(self, client):
        await client.post(
            "/api/v1/auth/register",
            json={"email": "logout@example.com", "password": "password123"},
        )
        login_response = await client.post(
            "/api/v1/auth/login",
            json={"email": "logout@example.com", "password": "password123"},
        )
        access_token = login_response.json()["access_token"]

        response = await client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert response.status_code == 200
        assert "Successfully logged out" in response.json()["message"]
