import base64
import json
from datetime import datetime, timedelta, timezone

import pytest

from app.models.user import User
from app.services.subscription import (
    AppleTransactionError,
    apply_transaction,
    current_entitlement,
    decode_apple_transaction,
)


@pytest.mark.anyio
async def test_new_user_defaults_to_free_tier(db_session):
    user = User(email="free@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    assert user.subscription_tier == "free"
    assert user.subscription_product_id is None
    assert user.subscription_expires_at is None
    assert user.subscription_original_transaction_id is None


def _jws(payload: dict) -> str:
    """Build an unsigned JWS-shaped token; only the payload segment is read."""

    def seg(data: dict) -> str:
        raw = json.dumps(data).encode()
        return base64.urlsafe_b64encode(raw).decode().rstrip("=")

    return f"{seg({'alg': 'ES256'})}.{seg(payload)}.signature"


def _payload(**overrides) -> dict:
    expires = datetime.now(timezone.utc) + timedelta(days=365)
    base = {
        "bundleId": "com.gabriel.peppy",
        "productId": "com.gabriel.peppy.premium.yearly",
        "originalTransactionId": "2000000000000001",
        "transactionId": "2000000000000002",
        "type": "Auto-Renewable Subscription",
        "expiresDate": int(expires.timestamp() * 1000),
    }
    base.update(overrides)
    return base


def test_decode_returns_payload():
    decoded = decode_apple_transaction(_jws(_payload()))
    assert decoded["productId"] == "com.gabriel.peppy.premium.yearly"


def test_decode_rejects_foreign_bundle():
    with pytest.raises(AppleTransactionError):
        decode_apple_transaction(_jws(_payload(bundleId="com.someone.else")))


def test_decode_rejects_unknown_product():
    with pytest.raises(AppleTransactionError):
        decode_apple_transaction(_jws(_payload(productId="com.gabriel.peppy.premium.gold")))


def test_decode_rejects_malformed_token():
    with pytest.raises(AppleTransactionError):
        decode_apple_transaction("not-a-jws")


@pytest.mark.anyio
async def test_apply_transaction_grants_premium(db_session):
    user = User(email="buyer@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()

    await apply_transaction(db_session, user, _payload())

    assert user.subscription_tier == "premium"
    assert user.subscription_product_id == "com.gabriel.peppy.premium.yearly"
    assert user.subscription_original_transaction_id == "2000000000000001"
    assert user.subscription_expires_at is not None
    assert current_entitlement(user)["is_premium"] is True


@pytest.mark.anyio
async def test_lifetime_purchase_never_expires(db_session):
    user = User(email="lifer@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()

    payload = _payload(
        productId="com.gabriel.peppy.premium.lifetime",
        type="Non-Consumable",
    )
    payload.pop("expiresDate")
    await apply_transaction(db_session, user, payload)

    assert user.subscription_tier == "premium"
    assert user.subscription_expires_at is None
    assert current_entitlement(user)["is_premium"] is True


@pytest.mark.anyio
async def test_lapsed_subscription_reads_as_free(db_session):
    user = User(email="lapsed@example.com", hashed_password="x")
    db_session.add(user)
    await db_session.commit()

    expired = datetime.now(timezone.utc) - timedelta(days=1)
    await apply_transaction(
        db_session, user, _payload(expiresDate=int(expired.timestamp() * 1000))
    )

    assert current_entitlement(user)["is_premium"] is False
