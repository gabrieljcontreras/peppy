import pytest
from app.services.user import UserService


class TestUserService:
    @pytest.mark.asyncio
    async def test_create_user(self, db_session):
        service = UserService(db_session)
        user = await service.create(
            email="test@example.com",
            password="password123",
            display_name="Test User",
        )
        assert user.id is not None
        assert user.email == "test@example.com"
        assert user.display_name == "Test User"
        assert user.is_active is True
        assert user.is_verified is False

    @pytest.mark.asyncio
    async def test_create_user_normalizes_email(self, db_session):
        service = UserService(db_session)
        user = await service.create(
            email="TEST@EXAMPLE.COM",
            password="password123",
        )
        assert user.email == "test@example.com"

    @pytest.mark.asyncio
    async def test_get_by_email(self, db_session):
        service = UserService(db_session)
        created = await service.create(email="find@example.com", password="password123")
        found = await service.get_by_email("find@example.com")
        assert found is not None
        assert found.id == created.id

    @pytest.mark.asyncio
    async def test_get_by_email_case_insensitive(self, db_session):
        service = UserService(db_session)
        await service.create(email="case@example.com", password="password123")
        found = await service.get_by_email("CASE@EXAMPLE.COM")
        assert found is not None

    @pytest.mark.asyncio
    async def test_get_by_email_not_found(self, db_session):
        service = UserService(db_session)
        found = await service.get_by_email("nonexistent@example.com")
        assert found is None

    @pytest.mark.asyncio
    async def test_get_by_id(self, db_session):
        service = UserService(db_session)
        created = await service.create(email="byid@example.com", password="password123")
        found = await service.get_by_id(created.id)
        assert found is not None
        assert found.email == "byid@example.com"

    @pytest.mark.asyncio
    async def test_authenticate_success(self, db_session):
        service = UserService(db_session)
        await service.create(email="auth@example.com", password="password123")
        user = await service.authenticate("auth@example.com", "password123")
        assert user is not None
        assert user.email == "auth@example.com"

    @pytest.mark.asyncio
    async def test_authenticate_wrong_password(self, db_session):
        service = UserService(db_session)
        await service.create(email="auth2@example.com", password="password123")
        user = await service.authenticate("auth2@example.com", "wrongpassword")
        assert user is None

    @pytest.mark.asyncio
    async def test_authenticate_nonexistent_user(self, db_session):
        service = UserService(db_session)
        user = await service.authenticate("nonexistent@example.com", "password123")
        assert user is None

    @pytest.mark.asyncio
    async def test_authenticate_inactive_user(self, db_session):
        service = UserService(db_session)
        created = await service.create(email="inactive@example.com", password="password123")
        await service.deactivate(created)
        user = await service.authenticate("inactive@example.com", "password123")
        assert user is None

    @pytest.mark.asyncio
    async def test_update_user(self, db_session):
        service = UserService(db_session)
        user = await service.create(email="update@example.com", password="password123")
        updated = await service.update(user, display_name="Updated Name")
        assert updated.display_name == "Updated Name"

    @pytest.mark.asyncio
    async def test_deactivate_user(self, db_session):
        service = UserService(db_session)
        user = await service.create(email="deactivate@example.com", password="password123")
        assert user.is_active is True
        deactivated = await service.deactivate(user)
        assert deactivated.is_active is False
