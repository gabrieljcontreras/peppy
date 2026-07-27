"""Apple StoreKit 2 transaction handling for Peppy Premium.

The iOS client sends the signed JWS transaction StoreKit hands it after a
purchase or restore. We decode the payload, validate it belongs to this app
and to a product we sell, and record the resulting entitlement on the user.
"""

import base64
import binascii
import json
import logging
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.user import User

logger = logging.getLogger(__name__)

TIER_FREE = "free"
TIER_PREMIUM = "premium"

PRODUCT_PLANS: dict[str, str] = {
    "com.gabriel.peppy.premium.yearly": "yearly",
    "com.gabriel.peppy.premium.monthly": "monthly",
    "com.gabriel.peppy.premium.lifetime": "lifetime",
}

LIFETIME_PRODUCT_ID = "com.gabriel.peppy.premium.lifetime"


class AppleTransactionError(ValueError):
    """The signed transaction is malformed, foreign, or for an unknown product."""


def _decode_segment(segment: str) -> dict:
    padding = "=" * (-len(segment) % 4)
    try:
        raw = base64.urlsafe_b64decode(segment + padding)
        return json.loads(raw)
    except (binascii.Error, ValueError) as exc:
        raise AppleTransactionError("Transaction payload is not decodable") from exc


def verify_apple_signature(signed_transaction: str) -> None:
    """Validate the JWS x5c chain against Apple's root CA.

    NOT IMPLEMENTED. Gated behind `apple_verify_receipts`, which must be True
    in production — without it a crafted request can grant premium. See the
    pre-launch blocker in the plan.
    """
    raise NotImplementedError(
        "Apple JWS signature verification is not implemented. "
        "Set APPLE_VERIFY_RECEIPTS=false only in development."
    )


def decode_apple_transaction(signed_transaction: str) -> dict:
    settings = get_settings()

    parts = signed_transaction.split(".")
    if len(parts) != 3:
        raise AppleTransactionError("Transaction is not a well-formed JWS")

    if settings.apple_verify_receipts:
        verify_apple_signature(signed_transaction)
    elif not settings.debug:
        # Unsigned transactions are a development affordance only. Outside DEBUG
        # they are refused rather than trusted, so an unconfigured deployment
        # cannot be talked into granting premium.
        raise AppleTransactionError(
            "Refusing an Apple transaction without signature verification "
            "outside development."
        )
    else:
        logger.warning(
            "Accepting an Apple transaction without signature verification. "
            "APPLE_VERIFY_RECEIPTS must be true in production."
        )

    payload = _decode_segment(parts[1])

    if payload.get("bundleId") != settings.apple_bundle_id:
        raise AppleTransactionError("Transaction belongs to a different app")

    if payload.get("productId") not in PRODUCT_PLANS:
        raise AppleTransactionError("Transaction is for an unknown product")

    return payload


def _expiry_from(payload: dict) -> datetime | None:
    if payload.get("productId") == LIFETIME_PRODUCT_ID:
        return None
    milliseconds = payload.get("expiresDate")
    if milliseconds is None:
        return None
    return datetime.fromtimestamp(milliseconds / 1000, tz=timezone.utc)


async def apply_transaction(db: AsyncSession, user: User, payload: dict) -> User:
    user.subscription_tier = TIER_PREMIUM
    user.subscription_product_id = payload["productId"]
    user.subscription_expires_at = _expiry_from(payload)
    user.subscription_original_transaction_id = payload.get("originalTransactionId")
    user.subscription_updated_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(user)
    return user


def _is_premium(user: User) -> bool:
    if user.subscription_tier != TIER_PREMIUM:
        return False

    expires_at = user.subscription_expires_at
    if expires_at is None:
        return True

    # SQLite round-trips datetimes without tzinfo; treat naive values as UTC
    # so a lapsed subscription is detected on every backend.
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    return expires_at > datetime.now(timezone.utc)


def current_entitlement(user: User) -> dict:
    premium = _is_premium(user)
    return {
        "tier": TIER_PREMIUM if premium else TIER_FREE,
        "product_id": user.subscription_product_id,
        "expires_at": user.subscription_expires_at,
        "is_premium": premium,
    }
