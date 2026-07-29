import base64
import json
import os
from datetime import datetime, timedelta, timezone

os.environ.setdefault("DEBUG", "true")

import pytest
import pytest_asyncio
from sqlalchemy import event
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

from app.main import app
from app.models.base import Base
from app.database import get_db

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture(scope="function")
def anyio_backend():
    return "asyncio"


@pytest_asyncio.fixture(scope="function")
async def engine():
    engine = create_async_engine(
        TEST_DATABASE_URL,
        echo=False,
        connect_args={"check_same_thread": False},
    )

    @event.listens_for(engine.sync_engine, "connect")
    def _set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture(scope="function")
async def db_session(engine):
    async_session = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with async_session() as session:
        yield session


@pytest_asyncio.fixture(scope="function")
async def client(engine):
    async_session = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async def override_get_db():
        async with async_session() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac

    app.dependency_overrides.clear()


async def _register_and_login(client, email: str) -> dict[str, str]:
    await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "password123"},
    )
    login_response = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "password123"},
    )
    token = login_response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _signed_yearly_transaction() -> str:
    """A JWS-shaped StoreKit transaction; only the payload segment is read."""

    def seg(data: dict) -> str:
        return base64.urlsafe_b64encode(json.dumps(data).encode()).decode().rstrip("=")

    expires = datetime.now(timezone.utc) + timedelta(days=365)
    payload = {
        "bundleId": "com.gabriel.peppy",
        "productId": "com.gabriel.peppy.premium.yearly",
        "originalTransactionId": "2000000000000001",
        "transactionId": "2000000000000002",
        "type": "Auto-Renewable Subscription",
        "expiresDate": int(expires.timestamp() * 1000),
    }
    return f"{seg({'alg': 'ES256'})}.{seg(payload)}.signature"


async def grant_premium(client, headers: dict[str, str]) -> dict[str, str]:
    """Put an already-authenticated user on premium so gated routes are reachable.

    Importable by test modules that build their own auth headers:
    `from conftest import grant_premium`.
    """
    response = await client.post(
        "/api/v1/subscription/apple",
        headers=headers,
        json={"signed_transaction": _signed_yearly_transaction()},
    )
    assert response.status_code == 200, response.text
    assert response.json()["is_premium"] is True
    return headers


@pytest.fixture
async def auth_headers(client):
    return await _register_and_login(client, "free_user@example.com")


@pytest.fixture
async def premium_auth_headers(client):
    headers = await _register_and_login(client, "premium_user@example.com")
    return await grant_premium(client, headers)
