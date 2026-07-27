# Peppy Premium Paywall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working StoreKit 2 Peppy Premium purchase flow shown after account creation, with Insights and Data export locked behind the entitlement on both client and server.

**Architecture:** StoreKit 2 is the client's source of truth so the UI unlocks instantly and works offline; an `EntitlementStore` pushes each signed transaction to a new FastAPI `/subscription` endpoint, which records the tier on `users` and gates `/insights/*` and `/profile/export` with HTTP 402. A 402 from any route downgrades the client and presents the paywall, so client and server self-heal when they disagree.

**Tech Stack:** SwiftUI (iOS 17+), StoreKit 2, Swift Testing/XCTest via `xcodebuild test`, FastAPI, SQLAlchemy async, Alembic, pytest.

**Spec:** `ios/peppy/docs/superpowers/specs/2026-07-26-peppy-premium-paywall-design.md`

## Global Constraints

- **Never run `git commit`.** Gabriel commits his own work. Every task ends by staging with `git add` and printing a suggested commit message for him. Never add `Co-Authored-By`.
- **Never drive the simulator to verify UI.** Builds, unit tests, and backend curl checks are fine; launching the app and reading screenshots is not. UI verification is handed off via the checklist in Task 18.
- **Every `xcodebuild`/`swift` invocation must be prefixed** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` — the active developer dir is CommandLineTools and bare invocations fail with "requires Xcode". SourceKit will also emit bogus "Cannot find type/module" diagnostics in the IDE; ignore them and trust `xcodebuild`.
- **Simulator destination is `platform=iOS Simulator,name=iPhone 17 Pro`.** No iPhone 16-family runtimes exist on this machine.
- **`ios/peppy/peppy.xcodeproj` does NOT use filesystem-synchronized groups.** Every new Swift file, the `.storekit` file, and the font resource must be manually registered in `project.pbxproj` (PBXBuildFile + PBXFileReference + group children + the target's Sources or Resources phase). Existing IDs follow the 23-char `49C365..C1F5DE` pattern. A file that compiles in your editor but is missing from the pbxproj will fail the build with "cannot find X in scope".
- **Backend virtualenv is `backend/venv`, not `.venv`.** Run tests with `cd backend && venv/bin/python -m pytest`.
- **Bundle ID is `com.gabriel.peppy`.**
- **Product IDs, verbatim:** `com.gabriel.peppy.premium.yearly`, `com.gabriel.peppy.premium.monthly`, `com.gabriel.peppy.premium.lifetime`.
- **Prices are never hardcoded in a view.** Always `Product.displayPrice` via `PremiumProduct`. The `.storekit` file and App Store Connect are the only places prices live.
- **Paywall feature copy, verbatim:** "Insights, Weekly Summaries, Trend Charts, Confidence Scores, Symptom Patterns, Data Export." Do not add Labs, Wearables, or Full History — those either have no iOS screen or are not gated, and naming them would advertise something a buyer cannot use.
- **The blurred teaser renders synthetic placeholder shapes, never real insight data.**
- **Reuse `ios/peppy/Design` tokens** (`Color.pep*`, `Spacing`, `CornerRadius`, `pepCardShadow()`). Do not introduce new styling abstractions or mutate shared `PepButtonStyle`.

---

## File Structure

**Backend — create**

| File | Responsibility |
|---|---|
| `backend/alembic/versions/f9a0b1c2d3e4_premium_subscription_slice.py` | Adds five `subscription_*` columns to `users` |
| `backend/app/api/schemas/subscription.py` | `SubscriptionResponse`, `AppleTransactionRequest` |
| `backend/app/services/subscription.py` | JWS decode, validation, tier/expiry computation, persistence |
| `backend/app/api/routes/subscription.py` | `GET ""`, `POST "/apple"` |
| `backend/tests/test_subscription.py` | Service + route tests |
| `backend/tests/test_premium_gating.py` | 402 gating across insights/export/dashboard |

**Backend — modify:** `app/models/user.py`, `app/api/deps.py`, `app/config.py`, `app/main.py`, `app/api/routes/insights.py`, `app/api/routes/profile.py`, `app/services/dashboard.py`

**iOS — create**

| File | Responsibility |
|---|---|
| `ios/peppy/Core/Subscriptions/PremiumPlan.swift` | Plan enum, product IDs, display metadata. No StoreKit import. |
| `ios/peppy/Core/Subscriptions/PremiumEntitlement.swift` | Entitlement enum + `isPremium` |
| `ios/peppy/Core/Subscriptions/SubscriptionService.swift` | `SubscriptionServicing` protocol, `PremiumProduct`, `VerifiedPurchase`, `PurchaseOutcome`, live `StoreKitSubscriptionService` |
| `ios/peppy/Core/Subscriptions/MockSubscriptionService.swift` | Scriptable test double |
| `ios/peppy/Core/Subscriptions/EntitlementStore.swift` | Observable entitlement truth, backend sync, transaction listener |
| `ios/peppy/Core/Network/SubscriptionAPIModels.swift` | `SubscriptionResponse`, `AppleTransactionRequest` |
| `ios/peppy/Design/Fonts/Fraunces-Italic.ttf` + `OFL.txt` | Bundled accent face |
| `ios/peppy/Design/PeppyFonts.swift` | Runtime font registration + descriptor resolution |
| `ios/peppy/Features/Paywall/ViewModels/PaywallViewModel.swift` | Products, selection, purchase/restore orchestration |
| `ios/peppy/Features/Paywall/Views/PaywallPlanCard.swift` | One selectable plan row |
| `ios/peppy/Features/Paywall/Views/PaywallView.swift` | The screen |
| `ios/peppy/Features/Paywall/Views/PremiumLockedOverlay.swift` | Blurred teaser lock |
| `ios/peppy/Features/Paywall/Views/PremiumUpsellCard.swift` | Settings status/upsell card |
| `ios/peppy/Peppy.storekit` | Local StoreKit configuration |
| `ios/peppy/peppyTests/PremiumPlanTests.swift`, `EntitlementStoreTests.swift`, `PaywallViewModelTests.swift`, `PremiumGatingTests.swift` | Tests |

**iOS — modify:** `Core/Network/APIError.swift`, `Core/Network/APIClient.swift`, `Core/Network/Endpoint.swift`, `Design/Typography.swift`, `App/Dependencies.swift`, `App/AppFlowCoordinator.swift`, `App/RootView.swift`, `Features/Auth/Views/RegisterView.swift`, `Features/Insights/Views/InsightsListView.swift`, `Features/Dashboard/Views/DashboardView.swift`, `Features/Settings/Views/SettingsRootView.swift`, `Features/Settings/Views/SettingsComponents.swift`, `Features/Settings/Models/SettingsModels.swift`, `peppyTests/AppFlowCoordinatorTests.swift`

---

## Task 1: Backend subscription columns and migration

**Files:**
- Modify: `backend/app/models/user.py`
- Create: `backend/alembic/versions/f9a0b1c2d3e4_premium_subscription_slice.py`
- Test: `backend/tests/test_subscription.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `User.subscription_tier: str` (`"free"`/`"premium"`, never null), `User.subscription_product_id: str | None`, `User.subscription_expires_at: datetime | None`, `User.subscription_original_transaction_id: str | None`, `User.subscription_updated_at: datetime | None`.

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_subscription.py`:

```python
import pytest

from app.models.user import User


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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && venv/bin/python -m pytest tests/test_subscription.py -v`
Expected: FAIL with `AttributeError: 'User' object has no attribute 'subscription_tier'`

- [ ] **Step 3: Add the columns to the model**

In `backend/app/models/user.py`, add to the imports `DateTime` is already imported; keep the existing import line as-is. Insert after the `last_insight_run_at` column:

```python
    # Premium subscription state, synced from StoreKit transactions.
    subscription_tier = Column(
        String(20), default="free", server_default="free", nullable=False
    )
    subscription_product_id = Column(String(100), nullable=True)
    subscription_expires_at = Column(DateTime(timezone=True), nullable=True)
    subscription_original_transaction_id = Column(String(100), nullable=True, index=True)
    subscription_updated_at = Column(DateTime(timezone=True), nullable=True)
```

- [ ] **Step 4: Write the Alembic migration**

Create `backend/alembic/versions/f9a0b1c2d3e4_premium_subscription_slice.py`:

```python
"""Add the premium subscription slice.

Revision ID: f9a0b1c2d3e4
Revises: e8f9a0b1c2d3
Create Date: 2026-07-26 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "f9a0b1c2d3e4"
down_revision: Union[str, None] = "e8f9a0b1c2d3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "subscription_tier",
            sa.String(length=20),
            server_default="free",
            nullable=False,
        ),
    )
    op.add_column(
        "users", sa.Column("subscription_product_id", sa.String(length=100), nullable=True)
    )
    op.add_column(
        "users", sa.Column("subscription_expires_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column(
        "users",
        sa.Column("subscription_original_transaction_id", sa.String(length=100), nullable=True),
    )
    op.add_column(
        "users", sa.Column("subscription_updated_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.create_index(
        "ix_users_subscription_original_transaction_id",
        "users",
        ["subscription_original_transaction_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_users_subscription_original_transaction_id", table_name="users")
    op.drop_column("users", "subscription_updated_at")
    op.drop_column("users", "subscription_original_transaction_id")
    op.drop_column("users", "subscription_expires_at")
    op.drop_column("users", "subscription_product_id")
    op.drop_column("users", "subscription_tier")
```

Confirm `e8f9a0b1c2d3` is still the head before committing to that `down_revision`:
`cd backend && venv/bin/python -m alembic heads`
If it prints something else, use the printed revision instead.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && venv/bin/python -m pytest tests/test_subscription.py -v`
Expected: PASS

- [ ] **Step 6: Stage and hand off**

```bash
git add backend/app/models/user.py backend/alembic/versions/f9a0b1c2d3e4_premium_subscription_slice.py backend/tests/test_subscription.py
```

Suggested message for Gabriel: `feat(backend): add premium subscription columns to users`

---

## Task 2: Backend subscription service

**Files:**
- Modify: `backend/app/config.py`
- Create: `backend/app/services/subscription.py`
- Test: `backend/tests/test_subscription.py` (append)

**Interfaces:**
- Consumes: `User.subscription_*` from Task 1.
- Produces:
  - `PRODUCT_PLANS: dict[str, str]` mapping product ID → `"yearly"`/`"monthly"`/`"lifetime"`
  - `class AppleTransactionError(ValueError)`
  - `decode_apple_transaction(signed_transaction: str) -> dict` — raises `AppleTransactionError`
  - `async def apply_transaction(db: AsyncSession, user: User, payload: dict) -> User`
  - `def current_entitlement(user: User) -> dict` returning `{"tier", "product_id", "expires_at", "is_premium"}`

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_subscription.py`:

```python
import base64
import json
from datetime import datetime, timedelta, timezone

from app.services.subscription import (
    AppleTransactionError,
    apply_transaction,
    current_entitlement,
    decode_apple_transaction,
)


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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && venv/bin/python -m pytest tests/test_subscription.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.subscription'`

- [ ] **Step 3: Add config settings**

In `backend/app/config.py`, insert after the APNs block (before `class Config:`):

```python
    # In-app purchases (StoreKit 2)
    apple_bundle_id: str = "com.gabriel.peppy"
    apple_verify_receipts: bool = False
```

- [ ] **Step 4: Write the service**

Create `backend/app/services/subscription.py`:

```python
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && venv/bin/python -m pytest tests/test_subscription.py -v`
Expected: PASS, 8 tests

- [ ] **Step 6: Stage and hand off**

```bash
git add backend/app/services/subscription.py backend/app/config.py backend/tests/test_subscription.py
```

Suggested message: `feat(backend): decode and persist Apple StoreKit transactions`

---

## Task 3: Backend subscription routes

**Files:**
- Create: `backend/app/api/schemas/subscription.py`, `backend/app/api/routes/subscription.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_subscription.py` (append)

**Interfaces:**
- Consumes: `decode_apple_transaction`, `apply_transaction`, `current_entitlement` from Task 2.
- Produces: `GET /api/v1/subscription` and `POST /api/v1/subscription/apple`, both returning `SubscriptionResponse { tier: str, product_id: str | None, expires_at: datetime | None, is_premium: bool }`. `POST` body is `{ "signed_transaction": str }`.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_subscription.py`. `auth_headers` mirrors the helper used in `backend/tests/test_dashboard_routes.py`; read that file and reuse its registration helper verbatim rather than inventing a new one.

```python
@pytest.mark.anyio
async def test_get_subscription_defaults_to_free(client, auth_headers):
    response = await client.get("/api/v1/subscription", headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert body["tier"] == "free"
    assert body["is_premium"] is False


@pytest.mark.anyio
async def test_post_apple_transaction_grants_premium(client, auth_headers):
    response = await client.post(
        "/api/v1/subscription/apple",
        headers=auth_headers,
        json={"signed_transaction": _jws(_payload())},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["tier"] == "premium"
    assert body["is_premium"] is True
    assert body["product_id"] == "com.gabriel.peppy.premium.yearly"


@pytest.mark.anyio
async def test_post_apple_transaction_rejects_foreign_bundle(client, auth_headers):
    response = await client.post(
        "/api/v1/subscription/apple",
        headers=auth_headers,
        json={"signed_transaction": _jws(_payload(bundleId="com.someone.else"))},
    )

    assert response.status_code == 400


@pytest.mark.anyio
async def test_subscription_requires_auth(client):
    assert (await client.get("/api/v1/subscription")).status_code in (401, 403)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && venv/bin/python -m pytest tests/test_subscription.py -v -k "get_subscription or post_apple or requires_auth"`
Expected: FAIL with 404 responses (routes not registered)

- [ ] **Step 3: Write the schemas**

Create `backend/app/api/schemas/subscription.py`:

```python
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AppleTransactionRequest(BaseModel):
    signed_transaction: str = Field(..., min_length=1)


class SubscriptionResponse(BaseModel):
    tier: str
    product_id: Optional[str] = None
    expires_at: Optional[datetime] = None
    is_premium: bool
```

- [ ] **Step 4: Write the routes**

Create `backend/app/api/routes/subscription.py`:

```python
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.api.schemas.subscription import AppleTransactionRequest, SubscriptionResponse
from app.database import get_db
from app.services.subscription import (
    AppleTransactionError,
    apply_transaction,
    current_entitlement,
    decode_apple_transaction,
)

router = APIRouter()


@router.get("", response_model=SubscriptionResponse)
async def get_subscription(current_user: CurrentUser):
    return current_entitlement(current_user)


@router.post("/apple", response_model=SubscriptionResponse)
async def sync_apple_transaction(
    request: AppleTransactionRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        payload = decode_apple_transaction(request.signed_transaction)
    except AppleTransactionError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc

    user = await apply_transaction(db, current_user, payload)
    return current_entitlement(user)
```

- [ ] **Step 5: Register the router**

In `backend/app/main.py`, add `subscription` to the `from app.api.routes import (...)` block (alphabetically, after `protocols`), then add below the `dashboard` include:

```python
app.include_router(
    subscription.router, prefix="/api/v1/subscription", tags=["subscription"]
)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd backend && venv/bin/python -m pytest tests/test_subscription.py -v`
Expected: PASS, 12 tests

- [ ] **Step 7: Stage and hand off**

```bash
git add backend/app/api/schemas/subscription.py backend/app/api/routes/subscription.py backend/app/main.py backend/tests/test_subscription.py
```

Suggested message: `feat(backend): add subscription entitlement endpoints`

---

## Task 4: Backend premium gating

**Files:**
- Modify: `backend/app/api/deps.py`, `backend/app/api/routes/insights.py`, `backend/app/api/routes/profile.py`, `backend/app/services/dashboard.py`
- Test: `backend/tests/test_premium_gating.py`

**Interfaces:**
- Consumes: `current_entitlement` from Task 2.
- Produces: `PremiumUser = Annotated[User, Depends(require_premium)]` exported from `app.api.deps`, raising `HTTPException(402, detail="premium_required")`.

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_premium_gating.py`. Reuse the registration/auth helper from `backend/tests/test_dashboard_routes.py` and the premium-granting helper shape from `test_subscription.py`:

```python
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
```

Add a `premium_auth_headers` fixture to `backend/tests/conftest.py` that registers a user, posts a valid transaction to `/api/v1/subscription/apple`, and returns the bearer headers. Reuse the existing `auth_headers` fixture's registration logic — read `conftest.py` first and follow its established fixture style.

Check the real `DataExportRequest` schema in `backend/app/api/schemas/export.py` before writing the export test body; `{"format": "csv"}` must match its actual required fields.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && venv/bin/python -m pytest tests/test_premium_gating.py -v`
Expected: FAIL — insights and export return 200 instead of 402

- [ ] **Step 3: Add the dependency**

In `backend/app/api/deps.py`, append after `CurrentUser`:

```python
async def require_premium(
    current_user: Annotated[User, Depends(get_current_active_user)],
) -> User:
    from app.services.subscription import current_entitlement

    if not current_entitlement(current_user)["is_premium"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="premium_required",
        )
    return current_user


PremiumUser = Annotated[User, Depends(require_premium)]
```

The import is function-local to avoid a circular import between `deps` and `services.subscription`.

- [ ] **Step 4: Gate the routes**

In `backend/app/api/routes/insights.py`, change the import `from app.api.deps import CurrentUser` to `from app.api.deps import PremiumUser`, then replace every `current_user: CurrentUser` parameter with `current_user: PremiumUser`. There are routes for list, get, mark read, action, generate, and weekly summary — change all of them. Verify none are missed:

`grep -n "CurrentUser" backend/app/api/routes/insights.py` should return nothing.

In `backend/app/api/routes/profile.py`, add `PremiumUser` to the `from app.api.deps import ...` line and change only the `export_profile_data` handler's parameter to `current_user: PremiumUser`. Leave the onboarding profile routes on `CurrentUser` — profile editing stays free.

- [ ] **Step 5: Null the dashboard insight for free users**

In `backend/app/services/dashboard.py`, find where `summary_for_user` builds the `insight` field. Read the method first. Load the `User` (or accept it as a parameter if the service currently takes only a `user_id` — prefer passing the already-loaded `User` down from the route to avoid a second query) and wrap the insight assignment:

```python
from app.services.subscription import current_entitlement

# ... inside summary_for_user, where the insight block is assembled:
if not current_entitlement(user)["is_premium"]:
    insight = None
```

If the route only has `current_user.id` today, update `backend/app/api/routes/dashboard.py` to pass `current_user` instead, and update the service signature to match. Adjust `backend/tests/test_dashboard_service.py` for the new signature.

- [ ] **Step 6: Run the full backend suite**

Run: `cd backend && venv/bin/python -m pytest -v`
Expected: PASS. Existing insight and dashboard tests that assumed free access will fail — update them to use `premium_auth_headers`. Do not weaken the gate to make an old test pass.

- [ ] **Step 7: Stage and hand off**

```bash
git add backend/app/api/deps.py backend/app/api/routes/insights.py backend/app/api/routes/profile.py backend/app/api/routes/dashboard.py backend/app/services/dashboard.py backend/tests/
```

Suggested message: `feat(backend): gate insights and export behind premium`

---

## Task 5: iOS 402 handling

**Files:**
- Modify: `ios/peppy/Core/Network/APIError.swift`, `ios/peppy/Core/Network/APIClient.swift`
- Test: `ios/peppy/peppyTests/PremiumGatingTests.swift`

**Interfaces:**
- Consumes: the 402 contract from Task 4.
- Produces: `APIError.paymentRequired`, thrown by `APIClient` for HTTP 402 in both `performRequest` and `performDownload`.

- [ ] **Step 1: Write the failing test**

Create `ios/peppy/peppyTests/PremiumGatingTests.swift`:

```swift
import XCTest
@testable import peppy

final class PremiumGatingTests: XCTestCase {
    func testPaymentRequiredHasUserMessage() {
        XCTAssertEqual(
            APIError.paymentRequired.userMessage,
            "Peppy Premium is required for this."
        )
    }

    func testPaymentRequiredIsEquatable() {
        XCTAssertEqual(APIError.paymentRequired, APIError.paymentRequired)
        XCTAssertNotEqual(APIError.paymentRequired, APIError.forbidden)
    }
}
```

Register the new file in `project.pbxproj` against the `peppyTests` target.

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/PremiumGatingTests 2>&1 | tail -25
```
Expected: FAIL to compile — `type 'APIError' has no member 'paymentRequired'`

- [ ] **Step 3: Add the error case**

In `ios/peppy/Core/Network/APIError.swift`, add `case paymentRequired` after `case forbidden`, add to `userMessage`:

```swift
        case .paymentRequired:
            return "Peppy Premium is required for this."
```

and add `(.paymentRequired, .paymentRequired)` to the equality switch's first group alongside `(.forbidden, .forbidden)`.

- [ ] **Step 4: Map HTTP 402**

In `ios/peppy/Core/Network/APIClient.swift`, add to the status switch in `performRequest`, between `case 401:` and `case 403:`:

```swift
        case 402:
            throw APIError.paymentRequired
```

Add the identical case to `performDownload`'s switch — the data export uses the download path, so omitting it there leaves export failing with a generic error instead of the paywall.

- [ ] **Step 5: Run test to verify it passes**

Run the Step 2 command.
Expected: PASS

- [ ] **Step 6: Stage and hand off**

```bash
git add ios/peppy/Core/Network/APIError.swift ios/peppy/Core/Network/APIClient.swift ios/peppy/peppyTests/PremiumGatingTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): map HTTP 402 to a paymentRequired API error`

---

## Task 6: Premium plan and entitlement models

**Files:**
- Create: `ios/peppy/Core/Subscriptions/PremiumPlan.swift`, `ios/peppy/Core/Subscriptions/PremiumEntitlement.swift`
- Test: `ios/peppy/peppyTests/PremiumPlanTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum PremiumPlan: String, CaseIterable, Sendable { case yearly, monthly, lifetime }` with `productID: String`, `title: String`, `subtitleLines: [String]`, `badgeText: String?`, `isRecurring: Bool`, and `static func plan(forProductID:) -> PremiumPlan?`
  - `enum PremiumEntitlement: Equatable, Sendable { case unknown, free, premium(plan: PremiumPlan?, expires: Date?) }` with `var isPremium: Bool` and `var isResolved: Bool`

- [ ] **Step 1: Write the failing tests**

Create `ios/peppy/peppyTests/PremiumPlanTests.swift`:

```swift
import XCTest
@testable import peppy

final class PremiumPlanTests: XCTestCase {
    func testProductIDsMatchStoreKitConfiguration() {
        XCTAssertEqual(PremiumPlan.yearly.productID, "com.gabriel.peppy.premium.yearly")
        XCTAssertEqual(PremiumPlan.monthly.productID, "com.gabriel.peppy.premium.monthly")
        XCTAssertEqual(PremiumPlan.lifetime.productID, "com.gabriel.peppy.premium.lifetime")
    }

    func testPlanLookupByProductID() {
        XCTAssertEqual(
            PremiumPlan.plan(forProductID: "com.gabriel.peppy.premium.monthly"),
            .monthly
        )
        XCTAssertNil(PremiumPlan.plan(forProductID: "com.gabriel.peppy.premium.gold"))
    }

    func testDisplayOrderPutsYearlyFirst() {
        XCTAssertEqual(PremiumPlan.allCases, [.yearly, .monthly, .lifetime])
    }

    func testOnlyYearlyCarriesADiscountBadge() {
        XCTAssertEqual(PremiumPlan.yearly.badgeText, "For You 50% OFF")
        XCTAssertNil(PremiumPlan.monthly.badgeText)
        XCTAssertNil(PremiumPlan.lifetime.badgeText)
    }

    func testLifetimeIsNotRecurring() {
        XCTAssertTrue(PremiumPlan.yearly.isRecurring)
        XCTAssertTrue(PremiumPlan.monthly.isRecurring)
        XCTAssertFalse(PremiumPlan.lifetime.isRecurring)
    }

    func testUnknownEntitlementIsNotPremiumAndNotResolved() {
        XCTAssertFalse(PremiumEntitlement.unknown.isPremium)
        XCTAssertFalse(PremiumEntitlement.unknown.isResolved)
    }

    func testFreeEntitlementIsResolved() {
        XCTAssertFalse(PremiumEntitlement.free.isPremium)
        XCTAssertTrue(PremiumEntitlement.free.isResolved)
    }

    func testPremiumEntitlementIsPremium() {
        let entitlement = PremiumEntitlement.premium(plan: .yearly, expires: nil)
        XCTAssertTrue(entitlement.isPremium)
        XCTAssertTrue(entitlement.isResolved)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/PremiumPlanTests 2>&1 | tail -25
```
Expected: FAIL to compile — `cannot find 'PremiumPlan' in scope`

- [ ] **Step 3: Write PremiumPlan**

Create `ios/peppy/Core/Subscriptions/PremiumPlan.swift`:

```swift
import Foundation

/// The three Peppy Premium products. Pure data — this type deliberately does
/// not import StoreKit so it can be used from views, view models, and tests
/// without a store connection.
///
/// `allCases` order is the paywall's display order.
enum PremiumPlan: String, CaseIterable, Sendable {
    case yearly
    case monthly
    case lifetime

    var productID: String {
        switch self {
        case .yearly: return "com.gabriel.peppy.premium.yearly"
        case .monthly: return "com.gabriel.peppy.premium.monthly"
        case .lifetime: return "com.gabriel.peppy.premium.lifetime"
        }
    }

    var title: String {
        switch self {
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        }
    }

    /// Secondary lines under the plan title on the paywall card.
    var subtitleLines: [String] {
        switch self {
        case .yearly: return ["Includes", "Family Sharing"]
        case .monthly: return []
        case .lifetime: return ["Pay Once, Use Forever", "Includes Family Sharing"]
        }
    }

    var badgeText: String? {
        switch self {
        case .yearly: return "For You 50% OFF"
        case .monthly, .lifetime: return nil
        }
    }

    /// Lifetime is a non-consumable, so "Cancel Anytime" must not be shown
    /// for it and it never carries an expiry.
    var isRecurring: Bool {
        self != .lifetime
    }

    static func plan(forProductID productID: String) -> PremiumPlan? {
        allCases.first { $0.productID == productID }
    }
}
```

- [ ] **Step 4: Write PremiumEntitlement**

Create `ios/peppy/Core/Subscriptions/PremiumEntitlement.swift`:

```swift
import Foundation

/// Whether the current account may use premium features.
///
/// `.unknown` is the pre-resolution state at launch. It is **not** premium for
/// gating purposes, but `isResolved` is false so upsell UI can stay hidden
/// until the real answer arrives — otherwise every launch flashes "locked"
/// at paying customers.
enum PremiumEntitlement: Equatable, Sendable {
    case unknown
    case free
    case premium(plan: PremiumPlan?, expires: Date?)

    var isPremium: Bool {
        if case .premium = self { return true }
        return false
    }

    var isResolved: Bool {
        self != .unknown
    }

    var plan: PremiumPlan? {
        if case .premium(let plan, _) = self { return plan }
        return nil
    }

    var expires: Date? {
        if case .premium(_, let expires) = self { return expires }
        return nil
    }
}
```

- [ ] **Step 5: Register both files in the Xcode project**

Add `PremiumPlan.swift`, `PremiumEntitlement.swift`, and `PremiumPlanTests.swift` to `project.pbxproj` (PBXBuildFile + PBXFileReference + a new `Subscriptions` group under `Core` + the appropriate target's Sources phase). The project has no filesystem-synchronized groups, so this is mandatory.

- [ ] **Step 6: Run tests to verify they pass**

Run the Step 2 command.
Expected: PASS, 8 tests

- [ ] **Step 7: Stage and hand off**

```bash
git add ios/peppy/Core/Subscriptions/ ios/peppy/peppyTests/PremiumPlanTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): add premium plan and entitlement models`

---

## Task 7: Subscription API models and endpoints

**Files:**
- Create: `ios/peppy/Core/Network/SubscriptionAPIModels.swift`
- Modify: `ios/peppy/Core/Network/Endpoint.swift`
- Test: `ios/peppy/peppyTests/PremiumGatingTests.swift` (append)

**Interfaces:**
- Consumes: `PremiumPlan` from Task 6; the route contract from Task 3.
- Produces:
  - `struct SubscriptionResponse: Decodable, Equatable { tier, productID, expiresAt, isPremium }` with `var entitlement: PremiumEntitlement`
  - `struct AppleTransactionRequest: Encodable { signedTransaction: String }`
  - `Endpoint.getSubscription`, `Endpoint.syncAppleTransaction(AppleTransactionRequest)`

- [ ] **Step 1: Write the failing tests**

Append to `ios/peppy/peppyTests/PremiumGatingTests.swift`:

```swift
extension PremiumGatingTests {
    func testSubscriptionEndpointPaths() {
        XCTAssertEqual(Endpoint.getSubscription.path, "/subscription")
        XCTAssertEqual(Endpoint.getSubscription.method, .get)

        let sync = Endpoint.syncAppleTransaction(
            AppleTransactionRequest(signedTransaction: "abc")
        )
        XCTAssertEqual(sync.path, "/subscription/apple")
        XCTAssertEqual(sync.method, .post)
        XCTAssertNotNil(sync.body)
    }

    func testSubscriptionResponseDecodesSnakeCase() throws {
        let json = """
        {
          "tier": "premium",
          "product_id": "com.gabriel.peppy.premium.yearly",
          "expires_at": "2027-07-26T00:00:00Z",
          "is_premium": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(SubscriptionResponse.self, from: json)

        XCTAssertTrue(response.isPremium)
        XCTAssertEqual(response.entitlement.plan, .yearly)
        XCTAssertTrue(response.entitlement.isPremium)
    }

    func testFreeSubscriptionResponseMapsToFreeEntitlement() throws {
        let json = """
        {"tier": "free", "product_id": null, "expires_at": null, "is_premium": false}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SubscriptionResponse.self, from: json)

        XCTAssertEqual(response.entitlement, .free)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/PremiumGatingTests 2>&1 | tail -25
```
Expected: FAIL to compile — `cannot find 'SubscriptionResponse' in scope`

- [ ] **Step 3: Write the API models**

Create `ios/peppy/Core/Network/SubscriptionAPIModels.swift`:

```swift
import Foundation

struct SubscriptionResponse: Decodable, Equatable {
    let tier: String
    let productID: String?
    let expiresAt: Date?
    let isPremium: Bool

    enum CodingKeys: String, CodingKey {
        case tier
        case productID = "product_id"
        case expiresAt = "expires_at"
        case isPremium = "is_premium"
    }

    /// The server's answer, expressed in the client's entitlement vocabulary.
    var entitlement: PremiumEntitlement {
        guard isPremium else { return .free }
        return .premium(
            plan: productID.flatMap(PremiumPlan.plan(forProductID:)),
            expires: expiresAt
        )
    }
}

struct AppleTransactionRequest: Encodable, Equatable {
    let signedTransaction: String

    enum CodingKeys: String, CodingKey {
        case signedTransaction = "signed_transaction"
    }
}
```

- [ ] **Step 4: Add the endpoint cases**

In `ios/peppy/Core/Network/Endpoint.swift`:

Add to the enum after the Dashboard block:
```swift
    // MARK: - Subscription
    case getSubscription
    case syncAppleTransaction(AppleTransactionRequest)
```

Add to `path`:
```swift
        // Subscription
        case .getSubscription: return "/subscription"
        case .syncAppleTransaction: return "/subscription/apple"
```

Add `.syncAppleTransaction` to the `.post` group in `method`.

Add to `body`:
```swift
        case .syncAppleTransaction(let request):
            return request
```

`requiresAuth` defaults to `true`, which is correct for both — no change needed there.

- [ ] **Step 5: Register the new file and run tests**

Add `SubscriptionAPIModels.swift` to `project.pbxproj` against the `peppy` target, then run the Step 2 command.
Expected: PASS

- [ ] **Step 6: Stage and hand off**

```bash
git add ios/peppy/Core/Network/SubscriptionAPIModels.swift ios/peppy/Core/Network/Endpoint.swift ios/peppy/peppyTests/PremiumGatingTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): add subscription API models and endpoints`

---

## Task 8: StoreKit service and configuration

**Files:**
- Create: `ios/peppy/Core/Subscriptions/SubscriptionService.swift`, `ios/peppy/Core/Subscriptions/MockSubscriptionService.swift`, `ios/peppy/Peppy.storekit`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj` and the `peppy` scheme

**Interfaces:**
- Consumes: `PremiumPlan`, `PremiumEntitlement` from Task 6.
- Produces:
  - `struct PremiumProduct: Equatable, Sendable { plan: PremiumPlan, displayPrice: String, originalDisplayPrice: String? }`
  - `struct VerifiedPurchase: Equatable, Sendable { plan: PremiumPlan, signedTransaction: String, expiresAt: Date? }`
  - `enum PurchaseOutcome: Equatable, Sendable { case success(VerifiedPurchase), userCancelled, pending }`
  - `protocol SubscriptionServicing: Sendable` — `loadProducts() async throws -> [PremiumProduct]`, `purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome`, `restore() async throws -> PremiumEntitlement`, `currentEntitlement() async -> PremiumEntitlement`, `transactionUpdates() -> AsyncStream<VerifiedPurchase>`
  - `final class StoreKitSubscriptionService: SubscriptionServicing`
  - `final class MockSubscriptionService: SubscriptionServicing` with settable `products`, `purchaseResult`, `purchaseError`, `entitlement`, and `recordedPurchases: [PremiumPlan]`

No StoreKit type crosses this protocol, so view models and tests never import StoreKit.

- [ ] **Step 1: Write the StoreKit configuration file**

Create `ios/peppy/Peppy.storekit`. This is the file that makes purchases work in the simulator. Product IDs must match `PremiumPlan.productID` exactly.

```json
{
  "identifier" : "A1B2C3D4",
  "nonRenewingSubscriptions" : [],
  "products" : [
    {
      "displayPrice" : "139.99",
      "familyShareable" : true,
      "internalID" : "P0000001",
      "localizations" : [
        {
          "description" : "Pay once, use Peppy Premium forever.",
          "displayName" : "Peppy Premium Lifetime",
          "locale" : "en_US"
        }
      ],
      "productID" : "com.gabriel.peppy.premium.lifetime",
      "referenceName" : "Peppy Premium Lifetime",
      "type" : "NonConsumable"
    }
  ],
  "settings" : {
    "_askToBuyEnabled" : false,
    "_storeKitErrors" : []
  },
  "subscriptionGroups" : [
    {
      "id" : "S0000001",
      "localizations" : [],
      "name" : "Peppy Premium",
      "subscriptions" : [
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "7.99",
          "familyShareable" : false,
          "groupNumber" : 2,
          "internalID" : "S0000003",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Peppy Premium, billed monthly.",
              "displayName" : "Peppy Premium Monthly",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.gabriel.peppy.premium.monthly",
          "recurringSubscriptionPeriod" : "P1M",
          "referenceName" : "Peppy Premium Monthly",
          "subscriptionGroupID" : "S0000001",
          "type" : "RecurringSubscription"
        },
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "24.99",
          "familyShareable" : true,
          "groupNumber" : 1,
          "internalID" : "S0000002",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Peppy Premium, billed yearly.",
              "displayName" : "Peppy Premium Yearly",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.gabriel.peppy.premium.yearly",
          "recurringSubscriptionPeriod" : "P1Y",
          "referenceName" : "Peppy Premium Yearly",
          "subscriptionGroupID" : "S0000001",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : { "major" : 4, "minor" : 0 }
}
```

The struck-through `$49.99` is not derivable from StoreKit here — `originalDisplayPrice` comes from `PremiumPlan` presentation in Task 11, computed as double the yearly `displayPrice` and formatted with the product's own locale, so it stays correct in any currency.

- [ ] **Step 2: Wire the configuration into the scheme**

Add `Peppy.storekit` to `project.pbxproj` as a resource of the `peppy` target, then set it as the scheme's StoreKit configuration: in `ios/peppy/peppy.xcodeproj/xcshareddata/xcschemes/peppy.xcscheme`, add to the `<LaunchAction>` element:

```xml
<StoreKitConfigurationFileReference
   identifier = "../../Peppy.storekit">
</StoreKitConfigurationFileReference>
```

The `identifier` is relative to the `.xcscheme` file. If the scheme is not shared, open Xcode → Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration and select the file; then verify the resulting diff.

- [ ] **Step 3: Write the service protocol and live implementation**

Create `ios/peppy/Core/Subscriptions/SubscriptionService.swift`:

```swift
import Foundation
import StoreKit

/// A product as the paywall needs it: which plan, and what to print.
/// Prices always come from StoreKit so they are correct in every storefront.
struct PremiumProduct: Equatable, Sendable {
    let plan: PremiumPlan
    let displayPrice: String
    /// The struck-through "was" price, when the plan advertises a discount.
    let originalDisplayPrice: String?
}

/// A StoreKit-verified purchase, reduced to what the rest of the app needs:
/// the plan, and the signed payload the backend verifies.
struct VerifiedPurchase: Equatable, Sendable {
    let plan: PremiumPlan
    let signedTransaction: String
    let expiresAt: Date?
}

enum PurchaseOutcome: Equatable, Sendable {
    case success(VerifiedPurchase)
    case userCancelled
    /// Ask-to-Buy or another deferred approval. Entitlement arrives later
    /// through `transactionUpdates()`.
    case pending
}

enum SubscriptionError: Error, Equatable {
    case productUnavailable
    case unverifiedTransaction
    case failed(String)
}

protocol SubscriptionServicing: Sendable {
    func loadProducts() async throws -> [PremiumProduct]
    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome
    func restore() async throws -> PremiumEntitlement
    func currentEntitlement() async -> PremiumEntitlement
    /// Renewals, Ask-to-Buy approvals, and purchases made on other devices.
    func transactionUpdates() -> AsyncStream<VerifiedPurchase>
}

final class StoreKitSubscriptionService: SubscriptionServicing {
    private let cache = ProductCache()

    func loadProducts() async throws -> [PremiumProduct] {
        let identifiers = PremiumPlan.allCases.map(\.productID)
        let products = try await Product.products(for: identifiers)
        await cache.store(products)

        // Preserve PremiumPlan.allCases order rather than StoreKit's.
        return PremiumPlan.allCases.compactMap { plan in
            guard let product = products.first(where: { $0.id == plan.productID }) else {
                return nil
            }
            return PremiumProduct(
                plan: plan,
                displayPrice: product.displayPrice,
                originalDisplayPrice: Self.originalDisplayPrice(for: plan, product: product)
            )
        }
    }

    /// The advertised "was" price. Derived from the live product price and
    /// formatted in the product's own currency, so the discount claim stays
    /// truthful in every storefront instead of hardcoding "$49.99".
    private static func originalDisplayPrice(
        for plan: PremiumPlan,
        product: Product
    ) -> String? {
        guard plan == .yearly else { return nil }
        return product.priceFormatStyle.format(product.price * 2)
    }

    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        guard let product = await cache.product(for: plan.productID) else {
            throw SubscriptionError.productUnavailable
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            return .success(Self.purchase(from: transaction, jws: verification.jwsRepresentation))
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            throw SubscriptionError.failed("Unrecognized purchase result")
        }
    }

    func restore() async throws -> PremiumEntitlement {
        try await AppStore.sync()
        return await currentEntitlement()
    }

    func currentEntitlement() async -> PremiumEntitlement {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result),
                  let plan = PremiumPlan.plan(forProductID: transaction.productID) else {
                continue
            }
            if let revocation = transaction.revocationDate, revocation <= Date() {
                continue
            }
            if let expiry = transaction.expirationDate, expiry <= Date() {
                continue
            }
            return .premium(plan: plan, expires: transaction.expirationDate)
        }
        return .free
    }

    func transactionUpdates() -> AsyncStream<VerifiedPurchase> {
        AsyncStream { continuation in
            let task = Task.detached {
                for await result in Transaction.updates {
                    guard let transaction = try? Self.checkVerified(result) else { continue }
                    await transaction.finish()
                    continuation.yield(
                        Self.purchase(from: transaction, jws: result.jwsRepresentation)
                    )
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            // Never grant entitlement on a transaction StoreKit could not verify.
            throw SubscriptionError.unverifiedTransaction
        }
    }

    private static func purchase(
        from transaction: StoreKit.Transaction,
        jws: String
    ) -> VerifiedPurchase {
        VerifiedPurchase(
            plan: PremiumPlan.plan(forProductID: transaction.productID) ?? .yearly,
            signedTransaction: jws,
            expiresAt: transaction.expirationDate
        )
    }
}

/// Products loaded once and reused, so `purchase` never refetches.
private actor ProductCache {
    private var products: [String: Product] = [:]

    func store(_ loaded: [Product]) {
        for product in loaded {
            products[product.id] = product
        }
    }

    func product(for identifier: String) -> Product? {
        products[identifier]
    }
}
```

- [ ] **Step 4: Write the mock**

Create `ios/peppy/Core/Subscriptions/MockSubscriptionService.swift`:

```swift
import Foundation

/// Deterministic `SubscriptionServicing` for previews and tests. Every
/// outcome the paywall must handle is scriptable without a store connection.
final class MockSubscriptionService: SubscriptionServicing, @unchecked Sendable {
    var products: [PremiumProduct] = [
        PremiumProduct(plan: .yearly, displayPrice: "$24.99", originalDisplayPrice: "$49.99"),
        PremiumProduct(plan: .monthly, displayPrice: "$7.99", originalDisplayPrice: nil),
        PremiumProduct(plan: .lifetime, displayPrice: "$139.99", originalDisplayPrice: nil)
    ]
    var loadProductsError: Error?
    var purchaseError: Error?
    var purchaseResult: PurchaseOutcome?
    var restoreResult: PremiumEntitlement = .free
    var entitlement: PremiumEntitlement = .free

    private(set) var recordedPurchases: [PremiumPlan] = []
    private(set) var restoreCallCount = 0

    private var updatesContinuation: AsyncStream<VerifiedPurchase>.Continuation?

    func loadProducts() async throws -> [PremiumProduct] {
        if let loadProductsError { throw loadProductsError }
        return products
    }

    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        recordedPurchases.append(plan)
        if let purchaseError { throw purchaseError }
        if let purchaseResult { return purchaseResult }
        return .success(
            VerifiedPurchase(
                plan: plan,
                signedTransaction: "mock.jws.\(plan.rawValue)",
                expiresAt: plan.isRecurring ? Date().addingTimeInterval(31_536_000) : nil
            )
        )
    }

    func restore() async throws -> PremiumEntitlement {
        restoreCallCount += 1
        return restoreResult
    }

    func currentEntitlement() async -> PremiumEntitlement {
        entitlement
    }

    func transactionUpdates() -> AsyncStream<VerifiedPurchase> {
        AsyncStream { continuation in
            self.updatesContinuation = continuation
        }
    }

    /// Drives the renewal / Ask-to-Buy path from a test.
    func emit(_ purchase: VerifiedPurchase) {
        updatesContinuation?.yield(purchase)
    }
}
```

- [ ] **Step 5: Register files and build**

Add all three files to `project.pbxproj` (the two Swift files to Sources, `Peppy.storekit` to Resources).

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Stage and hand off**

```bash
git add ios/peppy/Core/Subscriptions/ ios/peppy/Peppy.storekit ios/peppy/peppy.xcodeproj/
```

Suggested message: `feat(ios): add StoreKit 2 subscription service and local configuration`

---

## Task 9: EntitlementStore and dependency wiring

**Files:**
- Create: `ios/peppy/Core/Subscriptions/EntitlementStore.swift`
- Modify: `ios/peppy/App/Dependencies.swift`
- Test: `ios/peppy/peppyTests/EntitlementStoreTests.swift`

**Interfaces:**
- Consumes: `SubscriptionServicing`, `PremiumEntitlement`, `SubscriptionResponse`, `AppleTransactionRequest`, `Endpoint.getSubscription`, `Endpoint.syncAppleTransaction`, `APIError.paymentRequired`.
- Produces: `@MainActor @Observable final class EntitlementStore` with `private(set) var entitlement: PremiumEntitlement`, `var isPremium: Bool`, `private(set) var hasUnsyncedPurchase: Bool`, `func start()`, `func refresh() async`, `func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome`, `func restore() async -> Bool`, `func markFreeFromServer()`, `func resetSession()`. Injected as `Dependencies.entitlements`.

`purchase` returns the full `PurchaseOutcome` rather than a `Bool` because the paywall must tell `.userCancelled` (say nothing) apart from `.pending` (explain the Ask-to-Buy wait). Collapsing them loses that distinction.

- [ ] **Step 1: Write the failing tests**

Create `ios/peppy/peppyTests/EntitlementStoreTests.swift`:

```swift
import XCTest
@testable import peppy

@MainActor
final class EntitlementStoreTests: XCTestCase {
    private func makeStore(
        service: MockSubscriptionService = MockSubscriptionService(),
        api: MockAPIClient = MockAPIClient()
    ) -> (EntitlementStore, MockSubscriptionService, MockAPIClient) {
        (EntitlementStore(service: service, api: api), service, api)
    }

    func testStartsUnknown() {
        let (store, _, _) = makeStore()
        XCTAssertEqual(store.entitlement, .unknown)
        XCTAssertFalse(store.isPremium)
    }

    func testRefreshAdoptsStoreKitPremium() async {
        let service = MockSubscriptionService()
        service.entitlement = .premium(plan: .yearly, expires: nil)
        let (store, _, _) = makeStore(service: service)

        await store.refresh()

        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(store.entitlement.plan, .yearly)
    }

    func testRefreshFallsBackToServerWhenStoreKitHasNothing() async {
        let service = MockSubscriptionService()
        service.entitlement = .free
        let api = MockAPIClient()
        api.setMockResponse(
            SubscriptionResponse(
                tier: "premium",
                productID: PremiumPlan.monthly.productID,
                expiresAt: Date().addingTimeInterval(86_400),
                isPremium: true
            ),
            for: Endpoint.getSubscription
        )
        let (store, _, _) = makeStore(service: service, api: api)

        await store.refresh()

        // A subscription bought on another device is honored even before this
        // device's StoreKit cache catches up.
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(store.entitlement.plan, .monthly)
    }

    func testPurchaseGrantsPremiumAndSyncsToBackend() async throws {
        let service = MockSubscriptionService()
        let (store, _, _) = makeStore(service: service)

        let outcome = try await store.purchase(.yearly)

        guard case .success = outcome else {
            return XCTFail("Expected success, got \(outcome)")
        }
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(service.recordedPurchases, [.yearly])
    }

    func testCancelledPurchaseLeavesEntitlementUnchanged() async throws {
        let service = MockSubscriptionService()
        service.purchaseResult = .userCancelled
        let (store, _, _) = makeStore(service: service)
        await store.refresh()

        let outcome = try await store.purchase(.monthly)

        XCTAssertEqual(outcome, .userCancelled)
        XCTAssertFalse(store.isPremium)
    }

    func testPendingPurchaseIsDistinctFromCancellation() async throws {
        let service = MockSubscriptionService()
        service.purchaseResult = .pending
        let (store, _, _) = makeStore(service: service)
        await store.refresh()

        let outcome = try await store.purchase(.monthly)

        // Ask-to-Buy. Entitlement arrives later via transactionUpdates().
        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(store.isPremium)
    }

    func testPurchaseStaysPremiumWhenBackendSyncFails() async throws {
        let service = MockSubscriptionService()
        let api = MockAPIClient()
        api.setMockError(APIError.networkUnavailable, for: Endpoint.syncAppleTransaction(
            AppleTransactionRequest(signedTransaction: "mock.jws.yearly")
        ))
        let (store, _, _) = makeStore(service: service, api: api)

        let outcome = try await store.purchase(.yearly)

        // StoreKit already took the money and finished the transaction; a
        // failed sync must never cost the user their purchase.
        guard case .success = outcome else {
            return XCTFail("Expected success, got \(outcome)")
        }
        XCTAssertTrue(store.isPremium)
        XCTAssertTrue(store.hasUnsyncedPurchase)
    }

    func testMarkFreeFromServerDowngrades() async {
        let service = MockSubscriptionService()
        service.entitlement = .premium(plan: .yearly, expires: nil)
        let (store, _, _) = makeStore(service: service)
        await store.refresh()
        XCTAssertTrue(store.isPremium)

        store.markFreeFromServer()

        XCTAssertEqual(store.entitlement, .free)
    }

    func testResetSessionReturnsToUnknown() async {
        let service = MockSubscriptionService()
        service.entitlement = .premium(plan: .lifetime, expires: nil)
        let (store, _, _) = makeStore(service: service)
        await store.refresh()

        store.resetSession()

        XCTAssertEqual(store.entitlement, .unknown)
    }

    func testRestoreAdoptsRestoredEntitlement() async {
        let service = MockSubscriptionService()
        service.restoreResult = .premium(plan: .lifetime, expires: nil)
        let (store, _, _) = makeStore(service: service)

        let restored = await store.restore()

        XCTAssertTrue(restored)
        XCTAssertEqual(store.entitlement.plan, .lifetime)
    }

    func testRestoreWithoutPriorPurchaseReportsFalse() async {
        let service = MockSubscriptionService()
        service.restoreResult = .free
        let (store, _, _) = makeStore(service: service)

        let restored = await store.restore()

        XCTAssertFalse(restored)
        XCTAssertEqual(store.entitlement, .free)
    }
}
```

Read `ios/peppy/Core/Network/MockAPIClient.swift` before writing these — confirm `setMockResponse(_:for:)` and whether an error-injection helper exists. If `setMockError(_:for:)` does not exist, add it following the file's existing pattern and keep the signature used above.

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/EntitlementStoreTests 2>&1 | tail -25
```
Expected: FAIL to compile — `cannot find 'EntitlementStore' in scope`

- [ ] **Step 3: Write the store**

Create `ios/peppy/Core/Subscriptions/EntitlementStore.swift`:

```swift
import Foundation
import Observation

/// The app's single answer to "may this account use premium features?".
///
/// StoreKit is the client's source of truth so the UI unlocks instantly and
/// works offline. The backend is the authority for data access, and a 402 from
/// any endpoint downgrades this store — that is the self-healing path when the
/// two disagree.
@MainActor
@Observable
final class EntitlementStore {
    private(set) var entitlement: PremiumEntitlement = .unknown

    var isPremium: Bool { entitlement.isPremium }

    /// A purchase StoreKit completed but the backend has not acknowledged.
    /// Retried on next refresh so a network blip never costs a purchase.
    private(set) var hasUnsyncedPurchase = false

    private let service: SubscriptionServicing
    private let api: APIClientProtocol
    private var pendingTransaction: String?
    private var updatesTask: Task<Void, Never>?

    init(service: SubscriptionServicing, api: APIClientProtocol) {
        self.service = service
        self.api = api
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Begins listening for renewals, Ask-to-Buy approvals, and purchases made
    /// on other devices. Called once at app launch; lives for the process.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let stream = self?.service.transactionUpdates() else { return }
            for await purchase in stream {
                await self?.adopt(purchase)
            }
        }
    }

    func refresh() async {
        if hasUnsyncedPurchase, let pendingTransaction {
            await sync(signedTransaction: pendingTransaction)
        }

        let storeKit = await service.currentEntitlement()
        if storeKit.isPremium {
            entitlement = storeKit
            return
        }

        // StoreKit sees nothing on this device. The server may still know
        // about a purchase made elsewhere, so ask before declaring free.
        do {
            let response: SubscriptionResponse = try await api.execute(.getSubscription)
            entitlement = response.entitlement
        } catch {
            entitlement = storeKit.isResolved ? storeKit : .free
        }
    }

    /// Returns the raw outcome so callers can distinguish a cancellation
    /// (say nothing) from an Ask-to-Buy deferral (explain the wait).
    @discardableResult
    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        let outcome = try await service.purchase(plan)

        if case .success(let purchase) = outcome {
            await adopt(purchase)
        }
        return outcome
    }

    @discardableResult
    func restore() async -> Bool {
        do {
            let restored = try await service.restore()
            entitlement = restored
            return restored.isPremium
        } catch {
            return false
        }
    }

    /// Called when any endpoint answers 402. The server is authoritative for
    /// access, so trust it over the local StoreKit cache.
    func markFreeFromServer() {
        entitlement = .free
    }

    func resetSession() {
        entitlement = .unknown
        hasUnsyncedPurchase = false
        pendingTransaction = nil
    }

    private func adopt(_ purchase: VerifiedPurchase) async {
        entitlement = .premium(plan: purchase.plan, expires: purchase.expiresAt)
        await sync(signedTransaction: purchase.signedTransaction)
    }

    private func sync(signedTransaction: String) async {
        do {
            let response: SubscriptionResponse = try await api.execute(
                .syncAppleTransaction(
                    AppleTransactionRequest(signedTransaction: signedTransaction)
                )
            )
            entitlement = response.entitlement
            hasUnsyncedPurchase = false
            pendingTransaction = nil
        } catch {
            // Keep the local grant. StoreKit already finished the transaction.
            hasUnsyncedPurchase = true
            pendingTransaction = signedTransaction
        }
    }
}
```

- [ ] **Step 4: Wire into Dependencies**

In `ios/peppy/App/Dependencies.swift`:

Add stored properties after `exportFileService`:
```swift
    let subscriptionService: SubscriptionServicing
    let entitlements: EntitlementStore
```

Add matching `init` parameters (after `exportFileService`) and assignments.

In `live()`, before the `flow` construction:
```swift
        let subscriptionService = StoreKitSubscriptionService()
        let entitlements = EntitlementStore(service: subscriptionService, api: api)
```

In `mock()`, the same but with `MockSubscriptionService()`.

In **both** `live()` and `mock()`:
- Add `entitlements` to the `resetSessionData` capture list and call `entitlements?.resetSession()` alongside the other resets.
- In `prepareSessionData`, add `Task { await entitlements.refresh() }` so a fresh sign-in resolves the entitlement.
- Pass `subscriptionService: subscriptionService, entitlements: entitlements` to both `Dependencies(...)` calls.

Because `entitlements` is `@MainActor`, capture it directly rather than weakly inside the `@MainActor` closures, matching how `appLock` is already captured in `prepareSessionData`.

- [ ] **Step 5: Start the listener at launch**

In `ios/peppy/App/RootView.swift`, inside the existing `.task { ... }` that calls `resolveLaunch`, add before the resolve call:

```swift
            deps.entitlements.start()
```

- [ ] **Step 6: Run tests to verify they pass**

Register `EntitlementStore.swift` and `EntitlementStoreTests.swift` in `project.pbxproj`, then run the Step 2 command.
Expected: PASS, 10 tests

- [ ] **Step 7: Run the full iOS suite**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```
Expected: PASS — `Dependencies.mock()` is used by many tests, so a wiring mistake surfaces here.

- [ ] **Step 8: Stage and hand off**

```bash
git add ios/peppy/Core/Subscriptions/EntitlementStore.swift ios/peppy/App/Dependencies.swift ios/peppy/App/RootView.swift ios/peppy/peppyTests/EntitlementStoreTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): add EntitlementStore and wire subscription dependencies`

---

## Task 10: Fraunces accent font

**Files:**
- Create: `ios/peppy/Design/Fonts/Fraunces-Italic.ttf`, `ios/peppy/Design/Fonts/OFL.txt`, `ios/peppy/Design/PeppyFonts.swift`
- Modify: `ios/peppy/Design/Typography.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `Font.peppyPremiumItalic(size: CGFloat) -> Font` and `enum PeppyFonts { static func premiumItalicUIFont(size: CGFloat) -> UIFont }`.

- [ ] **Step 1: Download the font and its licence**

```bash
mkdir -p ios/peppy/Design/Fonts
curl -sL -o ios/peppy/Design/Fonts/Fraunces-Italic.ttf \
  "https://github.com/google/fonts/raw/main/ofl/fraunces/Fraunces-Italic%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf"
curl -sL -o ios/peppy/Design/Fonts/OFL.txt \
  "https://github.com/google/fonts/raw/main/ofl/fraunces/OFL.txt"
file ios/peppy/Design/Fonts/Fraunces-Italic.ttf
```
Expected: `TrueType Font data`, roughly 415 KB. The licence file is not optional — Fraunces ships under the SIL OFL and bundling it requires shipping the licence.

- [ ] **Step 2: Write the font helper**

Create `ios/peppy/Design/PeppyFonts.swift`:

```swift
import CoreText
import SwiftUI
import UIKit

/// Fraunces Italic — the accent face the marketing site uses for emphasis
/// (`font-serif italic font-medium`). Bundled as a variable font and
/// registered at runtime: the app target generates its Info.plist from build
/// settings and has no plist file to add `UIAppFonts` to.
enum PeppyFonts {
    static let premiumFamilyName = "Fraunces"

    private static let registerOnce: Void = {
        guard let url = Bundle.main.url(
            forResource: "Fraunces-Italic",
            withExtension: "ttf"
        ) else {
            assertionFailure("Fraunces-Italic.ttf is missing from the bundle")
            return
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            assertionFailure("Failed to register Fraunces: \(String(describing: error))")
        }
    }()

    /// Weight 500 italic, matching the site's `font-medium`. Falls back to the
    /// system serif italic if registration or descriptor matching fails, so a
    /// bundling mistake degrades instead of rendering nothing.
    static func premiumItalicUIFont(size: CGFloat) -> UIFont {
        _ = registerOnce

        let variationAxisWeight = 2003265652 // 'wght' as a four-char code
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: premiumFamilyName,
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [
                variationAxisWeight: 500
            ]
        ])

        let italic = descriptor.withSymbolicTraits(.traitItalic) ?? descriptor
        let candidate = UIFont(descriptor: italic, size: size)

        guard candidate.familyName == premiumFamilyName else {
            let fallback = UIFont.systemFont(ofSize: size, weight: .medium)
            let serif = fallback.fontDescriptor
                .withDesign(.serif)?
                .withSymbolicTraits(.traitItalic)
            return serif.map { UIFont(descriptor: $0, size: size) } ?? fallback
        }

        return candidate
    }
}

extension Font {
    /// The "Premium" half of the paywall headline.
    static func peppyPremiumItalic(size: CGFloat) -> Font {
        Font(PeppyFonts.premiumItalicUIFont(size: size))
    }
}
```

- [ ] **Step 3: Register the resources**

Add to `project.pbxproj`: `PeppyFonts.swift` to the `peppy` target's Sources phase, and `Fraunces-Italic.ttf` plus `OFL.txt` to its **Resources** (Copy Bundle Resources) phase. A font in Sources instead of Resources will not be in the bundle and the fallback path will silently take over.

- [ ] **Step 4: Verify the font resolves**

Append to `ios/peppy/peppyTests/PremiumGatingTests.swift`:

```swift
extension PremiumGatingTests {
    func testPremiumItalicFontResolvesToFraunces() {
        let font = PeppyFonts.premiumItalicUIFont(size: 40)

        // If this fails the .ttf is missing from Copy Bundle Resources and
        // the headline is silently rendering in the system serif fallback.
        XCTAssertEqual(font.familyName, "Fraunces")
        XCTAssertEqual(font.pointSize, 40)
    }
}
```

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/PremiumGatingTests 2>&1 | tail -25
```
Expected: PASS. If `familyName` is not `Fraunces`, the resource is not in the bundle — fix the pbxproj Resources phase rather than relaxing the assertion.

- [ ] **Step 5: Stage and hand off**

```bash
git add ios/peppy/Design/Fonts/ ios/peppy/Design/PeppyFonts.swift ios/peppy/peppyTests/PremiumGatingTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): bundle Fraunces italic as the premium accent face`

---

## Task 11: PaywallViewModel

**Files:**
- Create: `ios/peppy/Features/Paywall/ViewModels/PaywallViewModel.swift`
- Test: `ios/peppy/peppyTests/PaywallViewModelTests.swift`

**Interfaces:**
- Consumes: `EntitlementStore`, `SubscriptionServicing`, `PremiumProduct`, `PremiumPlan`.
- Produces: `@MainActor @Observable final class PaywallViewModel` with `enum PaywallState: Equatable { case loading, ready, purchasing, loadFailed(String) }`, `private(set) var state`, `private(set) var products: [PremiumProduct]`, `var selectedPlan: PremiumPlan`, `private(set) var errorMessage: String?`, `private(set) var didPurchase: Bool`, `var selectedProduct: PremiumProduct?`, `var showsCancelAnytime: Bool`, `func load() async`, `func select(_:)`, `func purchase() async`, `func restore() async`.

- [ ] **Step 1: Write the failing tests**

Create `ios/peppy/peppyTests/PaywallViewModelTests.swift`:

```swift
import XCTest
@testable import peppy

@MainActor
final class PaywallViewModelTests: XCTestCase {
    private func makeModel(
        service: MockSubscriptionService = MockSubscriptionService()
    ) -> (PaywallViewModel, MockSubscriptionService, EntitlementStore) {
        let store = EntitlementStore(service: service, api: MockAPIClient())
        return (PaywallViewModel(service: service, entitlements: store), service, store)
    }

    func testYearlyIsPreselected() {
        let (model, _, _) = makeModel()
        XCTAssertEqual(model.selectedPlan, .yearly)
    }

    func testLoadPopulatesProductsInDisplayOrder() async {
        let (model, _, _) = makeModel()

        await model.load()

        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.products.map(\.plan), [.yearly, .monthly, .lifetime])
    }

    func testLoadFailureSurfacesRetryableState() async {
        let service = MockSubscriptionService()
        service.loadProductsError = SubscriptionError.productUnavailable
        let (model, _, _) = makeModel(service: service)

        await model.load()

        guard case .loadFailed = model.state else {
            return XCTFail("Expected loadFailed, got \(model.state)")
        }
        XCTAssertTrue(model.products.isEmpty)
    }

    func testSelectedProductFollowsSelection() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.select(.lifetime)

        XCTAssertEqual(model.selectedPlan, .lifetime)
        XCTAssertEqual(model.selectedProduct?.displayPrice, "$139.99")
    }

    func testCancelAnytimeHiddenForLifetime() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.select(.yearly)
        XCTAssertTrue(model.showsCancelAnytime)

        model.select(.lifetime)
        XCTAssertFalse(model.showsCancelAnytime)
    }

    func testSuccessfulPurchaseSetsDidPurchase() async {
        let (model, service, store) = makeModel()
        await model.load()

        await model.purchase()

        XCTAssertTrue(model.didPurchase)
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(service.recordedPurchases, [.yearly])
        XCTAssertEqual(model.state, .ready)
    }

    func testCancelledPurchaseIsSilent() async {
        let service = MockSubscriptionService()
        service.purchaseResult = .userCancelled
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.purchase()

        XCTAssertFalse(model.didPurchase)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.state, .ready)
    }

    func testPendingPurchaseExplainsTheWait() async {
        let service = MockSubscriptionService()
        service.purchaseResult = .pending
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.purchase()

        XCTAssertFalse(model.didPurchase)
        XCTAssertEqual(
            model.errorMessage,
            "Waiting for approval. You'll get Premium as soon as it's approved."
        )
    }

    func testFailedPurchaseShowsErrorAndStaysInteractive() async {
        let service = MockSubscriptionService()
        service.purchaseError = SubscriptionError.failed("Card declined")
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.purchase()

        XCTAssertFalse(model.didPurchase)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.state, .ready)
    }

    func testRestoreWithPurchaseSetsDidPurchase() async {
        let service = MockSubscriptionService()
        service.restoreResult = .premium(plan: .lifetime, expires: nil)
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.restore()

        XCTAssertTrue(model.didPurchase)
    }

    func testRestoreWithoutPurchaseExplainsWhy() async {
        let service = MockSubscriptionService()
        service.restoreResult = .free
        let (model, _, _) = makeModel(service: service)
        await model.load()

        await model.restore()

        XCTAssertFalse(model.didPurchase)
        XCTAssertEqual(model.errorMessage, "No previous purchase found to restore.")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/PaywallViewModelTests 2>&1 | tail -25
```
Expected: FAIL to compile — `cannot find 'PaywallViewModel' in scope`

- [ ] **Step 3: Write the view model**

Create `ios/peppy/Features/Paywall/ViewModels/PaywallViewModel.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class PaywallViewModel {
    enum PaywallState: Equatable {
        case loading
        case ready
        case purchasing
        case loadFailed(String)
    }

    private(set) var state: PaywallState = .loading
    private(set) var products: [PremiumProduct] = []
    private(set) var selectedPlan: PremiumPlan = .yearly
    private(set) var errorMessage: String?
    /// Flips true once the user is entitled, by purchase or restore. The view
    /// observes this to dismiss.
    private(set) var didPurchase = false

    private let service: SubscriptionServicing
    private let entitlements: EntitlementStore

    init(service: SubscriptionServicing, entitlements: EntitlementStore) {
        self.service = service
        self.entitlements = entitlements
    }

    var selectedProduct: PremiumProduct? {
        products.first { $0.plan == selectedPlan }
    }

    /// "Cancel Anytime" would be untrue under a one-time Lifetime purchase.
    var showsCancelAnytime: Bool {
        selectedPlan.isRecurring
    }

    var isPurchasing: Bool {
        state == .purchasing
    }

    func load() async {
        state = .loading
        errorMessage = nil
        do {
            products = try await service.loadProducts()
            guard !products.isEmpty else {
                state = .loadFailed("Plans are unavailable right now.")
                return
            }
            if !products.contains(where: { $0.plan == selectedPlan }) {
                selectedPlan = products[0].plan
            }
            state = .ready
        } catch {
            products = []
            state = .loadFailed("We couldn't load plans. Check your connection and try again.")
        }
    }

    func select(_ plan: PremiumPlan) {
        guard state != .purchasing else { return }
        selectedPlan = plan
        errorMessage = nil
    }

    func purchase() async {
        guard state == .ready else { return }
        state = .purchasing
        errorMessage = nil

        do {
            let outcome = try await entitlements.purchase(selectedPlan)
            state = .ready
            switch outcome {
            case .success:
                didPurchase = true
            case .pending:
                errorMessage =
                    "Waiting for approval. You'll get Premium as soon as it's approved."
            case .userCancelled:
                // The user chose to back out. Saying anything would be noise.
                break
            }
        } catch {
            state = .ready
            errorMessage = "That purchase didn't go through. Please try again."
        }
    }

    func restore() async {
        guard state == .ready else { return }
        state = .purchasing
        errorMessage = nil

        let restored = await entitlements.restore()
        state = .ready

        if restored {
            didPurchase = true
        } else {
            errorMessage = "No previous purchase found to restore."
        }
    }
}
```

`selectedPlan` is `private(set)` and changed only through `select(_:)`, which ignores taps while a purchase is in flight — otherwise the plan could change underneath an in-progress transaction.

- [ ] **Step 4: Register and run tests**

Add `PaywallViewModel.swift` and `PaywallViewModelTests.swift` to `project.pbxproj`, then run the Step 2 command.
Expected: PASS, 11 tests

- [ ] **Step 5: Stage and hand off**

```bash
git add ios/peppy/Features/Paywall/ ios/peppy/peppyTests/PaywallViewModelTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): add paywall view model`

---

## Task 12: PaywallPlanCard

**Files:**
- Create: `ios/peppy/Features/Paywall/Views/PaywallPlanCard.swift`

**Interfaces:**
- Consumes: `PremiumProduct`, `PremiumPlan`, design tokens.
- Produces: `struct PaywallPlanCard: View` — `init(product: PremiumProduct, isSelected: Bool, action: @escaping () -> Void)`.

- [ ] **Step 1: Write the card**

Create `ios/peppy/Features/Paywall/Views/PaywallPlanCard.swift`:

```swift
import SwiftUI

/// One selectable plan on the paywall. The three cards form a radio group;
/// the whole card is the tap target.
struct PaywallPlanCard: View {
    let product: PremiumProduct
    let isSelected: Bool
    let action: () -> Void

    private var plan: PremiumPlan { product.plan }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Spacing.md) {
                selectionIndicator

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)

                    ForEach(plan.subtitleLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.pepTextSecondary)
                    }
                }

                Spacer(minLength: Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceText)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)

                    if let original = product.originalDisplayPrice {
                        Text("\(original)\(plan == .yearly ? "/year" : "")")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.pepTextTertiary)
                            .strikethrough(true, color: .pepTextTertiary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.pepPrimaryMuted : Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(
                        isSelected ? Color.pepPrimary : Color.pepBorderLight,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .pepCardShadow()
            .overlay(alignment: .topTrailing) { badge }
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var priceText: String {
        switch plan {
        case .yearly: return "\(product.displayPrice)/year"
        case .monthly: return "\(product.displayPrice)/month"
        case .lifetime: return product.displayPrice
        }
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.pepPrimary : Color.clear)
                .frame(width: 28, height: 28)

            Circle()
                .stroke(isSelected ? Color.clear : Color.pepBorder, lineWidth: 1.5)
                .frame(width: 28, height: 28)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badge: some View {
        if let text = plan.badgeText {
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.pepPrimary)
                .clipShape(Capsule())
                // Rides the card's top edge, as in the reference.
                .offset(x: -8, y: -14)
                .accessibilityHidden(true)
        }
    }

    private var accessibilityLabel: String {
        var parts = [plan.title, priceText]
        parts.append(contentsOf: plan.subtitleLines)
        if let text = plan.badgeText { parts.append(text) }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    VStack(spacing: 14) {
        PaywallPlanCard(
            product: PremiumProduct(
                plan: .yearly, displayPrice: "$24.99", originalDisplayPrice: "$49.99"
            ),
            isSelected: true,
            action: {}
        )
        PaywallPlanCard(
            product: PremiumProduct(
                plan: .monthly, displayPrice: "$7.99", originalDisplayPrice: nil
            ),
            isSelected: false,
            action: {}
        )
        PaywallPlanCard(
            product: PremiumProduct(
                plan: .lifetime, displayPrice: "$139.99", originalDisplayPrice: nil
            ),
            isSelected: false,
            action: {}
        )
    }
    .padding(20)
    .background(Color.pepBackground)
}
```

- [ ] **Step 2: Register and build**

Add the file to `project.pbxproj`, then run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Stage and hand off**

```bash
git add ios/peppy/Features/Paywall/Views/PaywallPlanCard.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): add paywall plan card`

---

## Task 13: PaywallView

**Files:**
- Create: `ios/peppy/Features/Paywall/Views/PaywallView.swift`

**Interfaces:**
- Consumes: `PaywallViewModel`, `PaywallPlanCard`, `Font.peppyPremiumItalic`, `Dependencies`.
- Produces: `struct PaywallView: View` — `init(onDismiss: @escaping () -> Void)`, reading `subscriptionService` and `entitlements` from `@Environment(\.dependencies)`.

- [ ] **Step 1: Write the view**

Create `ios/peppy/Features/Paywall/Views/PaywallView.swift`:

```swift
import SwiftUI

struct PaywallView: View {
    static let featureRun =
        "Insights, Weekly Summaries, Trend Charts, Confidence Scores, "
        + "Symptom Patterns, Data Export."

    @Environment(\.dependencies) private var deps
    @State private var model: PaywallViewModel?

    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.pepBackground.ignoresSafeArea()

            if let model {
                content(model)
            } else {
                ProgressView().tint(.pepPrimary)
            }
        }
        .task {
            if model == nil {
                let created = PaywallViewModel(
                    service: deps.subscriptionService,
                    entitlements: deps.entitlements
                )
                model = created
                await created.load()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: PaywallViewModel) -> some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headline
                    featureText

                    switch model.state {
                    case .loading:
                        skeletonCards
                    case .loadFailed(let message):
                        loadFailure(message, model: model)
                    case .ready, .purchasing:
                        planCards(model)
                        restoreButton(model)
                    }

                    if let message = model.errorMessage {
                        Text(message)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.pepError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
            }

            footer(model)
        }
        .onChange(of: model.didPurchase) {
            if model.didPurchase { onDismiss() }
        }
    }

    private var topBar: some View {
        ZStack {
            PeppyLogo(size: 30, showsWordmark: true)

            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Color.pepTextPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")

                Spacer()
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
    }

    /// "Peppy" in the app's rounded face, "Premium" in the marketing site's
    /// Fraunces italic accent — the same two-face treatment the web headlines
    /// use.
    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Peppy")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)

            Text("Premium")
                .font(.peppyPremiumItalic(size: 42))
                .foregroundStyle(Color.pepPrimary)
        }
        .minimumScaleFactor(0.7)
        .lineLimit(1)
        .padding(.top, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Peppy Premium")
        .accessibilityAddTraits(.isHeader)
    }

    private var featureText: some View {
        Text(Self.featureRun)
            .font(.system(size: 17, design: .rounded))
            .foregroundStyle(Color.pepTextSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .padding(.horizontal, Spacing.sm)
    }

    private var skeletonCards: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.pepSurfaceElevated)
                    .frame(height: 96)
            }
        }
        .accessibilityLabel("Loading plans")
    }

    private func loadFailure(_ message: String, model: PaywallViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            Text(message)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .multilineTextAlignment(.center)

            PepButton(title: "Retry", style: .secondary) {
                Task { await model.load() }
            }
            .frame(maxWidth: 220)
        }
        .padding(.vertical, Spacing.lg)
    }

    private func planCards(_ model: PaywallViewModel) -> some View {
        VStack(spacing: 14) {
            ForEach(model.products, id: \.plan) { product in
                PaywallPlanCard(
                    product: product,
                    isSelected: product.plan == model.selectedPlan
                ) {
                    model.select(product.plan)
                }
            }
        }
        .padding(.top, Spacing.xs)
    }

    private func restoreButton(_ model: PaywallViewModel) -> some View {
        Button {
            Task { await model.restore() }
        } label: {
            Text("Restore Purchase")
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.pepTextTertiary)
                        .frame(height: 1)
                        .offset(y: 4)
                }
        }
        .buttonStyle(.plain)
        .disabled(model.isPurchasing)
        .padding(.top, Spacing.xs)
    }

    private func footer(_ model: PaywallViewModel) -> some View {
        VStack(spacing: 10) {
            if let product = model.selectedProduct {
                priceRecap(product)
            }

            PaywallPrimaryButton(
                title: "Continue",
                isLoading: model.isPurchasing,
                isDisabled: model.selectedProduct == nil
            ) {
                Task { await model.purchase() }
            }

            if model.showsCancelAnytime {
                Text("Cancel Anytime")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.pepPrimary)
            }

            Text(Self.legalText(for: model.selectedPlan))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.pepTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.sm)
        }
        .padding(.horizontal, 22)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(Color.pepBackground)
    }

    private func priceRecap(_ product: PremiumProduct) -> some View {
        HStack(spacing: Spacing.sm) {
            if let original = product.originalDisplayPrice {
                Text(original)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Color.pepTextTertiary)
                    .strikethrough(true, color: .pepTextTertiary)
            }

            Text(recapPrice(product))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)

            if product.originalDisplayPrice != nil {
                Text("50% OFF")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.pepPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func recapPrice(_ product: PremiumProduct) -> String {
        switch product.plan {
        case .yearly: return "\(product.displayPrice)/year"
        case .monthly: return "\(product.displayPrice)/month"
        case .lifetime: return product.displayPrice
        }
    }

    /// App Store review requires the auto-renewal disclosure for
    /// subscriptions. Absent from the visual reference, non-optional to ship.
    static func legalText(for plan: PremiumPlan) -> String {
        if plan.isRecurring {
            return "Renews automatically until cancelled. Manage or cancel in "
                + "Settings at least 24 hours before the period ends. "
                + "Terms and Privacy Policy apply."
        }
        return "One-time purchase. Terms and Privacy Policy apply."
    }
}

/// The paywall's CTA is coral, while the shared `PepButton` primary is ink.
/// Local to the paywall so the rest of the app's primary buttons are untouched.
private struct PaywallPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView().tint(.white)
                }
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .frame(minHeight: 56)
            .foregroundStyle(Color.white)
            .background(isDisabled ? Color.pepPrimary.opacity(0.5) : Color.pepPrimary)
            .clipShape(Capsule())
        }
        .disabled(isLoading || isDisabled)
    }
}

#Preview {
    PaywallView(onDismiss: {})
        .withDependencies(.mock())
}
```

- [ ] **Step 2: Register and build**

Add the file to `project.pbxproj`, then run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Stage and hand off**

```bash
git add ios/peppy/Features/Paywall/Views/PaywallView.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): add Peppy Premium paywall screen`

---

## Task 14: Post-registration routing

**Files:**
- Modify: `ios/peppy/App/AppFlowCoordinator.swift`, `ios/peppy/App/RootView.swift`, `ios/peppy/Features/Auth/Views/RegisterView.swift`
- Test: `ios/peppy/peppyTests/AppFlowCoordinatorTests.swift`

**Interfaces:**
- Consumes: `PaywallView` from Task 13.
- Produces: `AppRoute.paywall` replacing `.futurePaywall`; `didAuthenticate(user:isNewAccount:)` with `isNewAccount` defaulting to `false`; `dismissPaywall()`. `advancePastFuturePaywall()` is removed.

- [ ] **Step 1: Write the failing tests**

In `ios/peppy/peppyTests/AppFlowCoordinatorTests.swift`, delete the existing future-paywall bypass test (search for `futurePaywall`) and add:

```swift
    func testRegistrationRoutesToPaywall() async {
        let fixture = makeFixture()
        let user = User(
            id: UUID(), email: "new@example.com", displayName: nil, isVerified: false
        )

        await fixture.coordinator.didAuthenticate(user: user, isNewAccount: true)

        XCTAssertEqual(fixture.coordinator.route, .paywall)
    }

    func testSignInSkipsPaywall() async {
        let fixture = makeFixture()
        let user = User(
            id: UUID(), email: "returning@example.com", displayName: nil, isVerified: true
        )

        await fixture.coordinator.didAuthenticate(user: user)

        XCTAssertEqual(fixture.coordinator.route, .dashboard)
    }

    func testDismissingPaywallReachesDashboard() async {
        let fixture = makeFixture()
        let user = User(
            id: UUID(), email: "new@example.com", displayName: nil, isVerified: false
        )
        await fixture.coordinator.didAuthenticate(user: user, isNewAccount: true)

        fixture.coordinator.dismissPaywall()

        XCTAssertEqual(fixture.coordinator.route, .dashboard)
    }

    func testReadySummaryContinuesStraightToRegistration() {
        let fixture = makeFixture()
        fixture.coordinator.showReadySummary()

        fixture.coordinator.continueFromReadySummary()

        XCTAssertEqual(fixture.coordinator.route, .authentication(.register))
    }
```

Match the existing fixture helper's name and shape — read the top of `AppFlowCoordinatorTests.swift` first and reuse it rather than introducing `makeFixture` if the file calls it something else.

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/AppFlowCoordinatorTests 2>&1 | tail -25
```
Expected: FAIL to compile — `type 'AppRoute' has no member 'paywall'`

- [ ] **Step 3: Update the coordinator**

In `ios/peppy/App/AppFlowCoordinator.swift`:

Replace `case futurePaywall` in `AppRoute` with `case paywall`.

In `showRegistration()`, change `case .readySummary, .futurePaywall:` to `case .readySummary:`.

Replace `continueFromReadySummary()` and `advancePastFuturePaywall()` with:

```swift
    func continueFromReadySummary() {
        authenticationBackStack = [.readySummary]
        route = .authentication(.register)
    }

    /// Leaves the post-registration paywall without purchasing. Free accounts
    /// are a real tier — Check-ins and Protocols still work.
    func dismissPaywall() {
        route = .dashboard
    }
```

Change the `didAuthenticate` signature and its final route assignment:

```swift
    func didAuthenticate(user: User, isNewAccount: Bool = false) async {
```

and replace the trailing `route = .dashboard` with:

```swift
        route = isNewAccount ? .paywall : .dashboard
```

- [ ] **Step 4: Render the paywall**

In `ios/peppy/App/RootView.swift`, replace the `.futurePaywall` case with:

```swift
                case .paywall:
                    PaywallView(onDismiss: deps.flow.dismissPaywall)
```

- [ ] **Step 5: Flag new registrations**

In `ios/peppy/Features/Auth/Views/RegisterView.swift:211`, change
`await deps.flow.didAuthenticate(user: user)` to
`await deps.flow.didAuthenticate(user: user, isNewAccount: true)`.

Leave `LoginView.swift:166` unchanged — returning users must not be re-shown the paywall.

- [ ] **Step 6: Run the full iOS suite**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```
Expected: PASS. Any other test referencing `.futurePaywall` must be updated, not deleted.

- [ ] **Step 7: Stage and hand off**

```bash
git add ios/peppy/App/AppFlowCoordinator.swift ios/peppy/App/RootView.swift ios/peppy/Features/Auth/Views/RegisterView.swift ios/peppy/peppyTests/AppFlowCoordinatorTests.swift
```

Suggested message: `feat(ios): show the paywall after account creation`

---

## Task 15: Insights tab gating

**Files:**
- Create: `ios/peppy/Features/Paywall/Views/PremiumLockedOverlay.swift`
- Modify: `ios/peppy/Features/Insights/Views/InsightsListView.swift`
- Test: `ios/peppy/peppyTests/PremiumGatingTests.swift` (append)

**Interfaces:**
- Consumes: `PremiumEntitlement`, design tokens.
- Produces: `struct PremiumLockedOverlay: View` — `init(title: String, message: String, actionTitle: String, action: @escaping () -> Void)`; `enum PremiumGate { static func showsLock(for entitlement: PremiumEntitlement) -> Bool }`.

- [ ] **Step 1: Write the failing test**

Append to `ios/peppy/peppyTests/PremiumGatingTests.swift`:

```swift
extension PremiumGatingTests {
    func testLockIsHiddenUntilEntitlementResolves() {
        // Showing a lock at launch would flash "locked" at paying customers.
        XCTAssertFalse(PremiumGate.showsLock(for: .unknown))
    }

    func testLockShownForFreeAccounts() {
        XCTAssertTrue(PremiumGate.showsLock(for: .free))
    }

    func testLockHiddenForPremiumAccounts() {
        XCTAssertFalse(
            PremiumGate.showsLock(for: .premium(plan: .yearly, expires: nil))
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/PremiumGatingTests 2>&1 | tail -25
```
Expected: FAIL to compile — `cannot find 'PremiumGate' in scope`

- [ ] **Step 3: Write the overlay**

Create `ios/peppy/Features/Paywall/Views/PremiumLockedOverlay.swift`:

```swift
import SwiftUI

enum PremiumGate {
    /// Whether to show locked UI. `.unknown` returns false so nothing flashes
    /// "locked" while the entitlement is still resolving at launch.
    static func showsLock(for entitlement: PremiumEntitlement) -> Bool {
        entitlement.isResolved && !entitlement.isPremium
    }
}

/// The locked-feature treatment: blurred placeholder cards behind a lock and
/// an unlock call to action.
///
/// The blurred shapes are synthetic — never real insight content — so nothing
/// a free account has not paid for is rendered, even out of focus.
struct PremiumLockedOverlay: View {
    let title: String
    let message: String
    var actionTitle: String = "Unlock Insights"
    let action: () -> Void

    var body: some View {
        ZStack {
            teaser
                .blur(radius: 8)
                .opacity(0.55)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(width: 56, height: 56)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.md)

                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, 14)
                        .background(Color.pepPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xs)
            }
            .padding(.vertical, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    /// Placeholder shapes only.
    private var teaser: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { index in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.pepBorder)
                        .frame(width: index == 1 ? 180 : 140, height: 14)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.pepBorderLight)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.pepBorderLight)
                        .frame(width: 220, height: 10)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.pepSurface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
    }
}

#Preview {
    PremiumLockedOverlay(
        title: "Insights are a Premium feature",
        message: "See what your check-ins and doses are telling you.",
        action: {}
    )
    .padding(20)
    .background(Color.pepBackground)
}
```

- [ ] **Step 4: Gate the Insights tab**

In `ios/peppy/Features/Insights/Views/InsightsListView.swift`, add `@State private var showsPaywall = false` alongside the existing `@State` properties.

Replace the body's content branch — currently the `if store.insights.isEmpty && store.isLoading { ... } else if model.showsLearningState { ... } else { insightSections }` chain — so the lock takes precedence:

```swift
                    if PremiumGate.showsLock(for: deps.entitlements.entitlement) {
                        PremiumLockedOverlay(
                            title: "Insights are a Premium feature",
                            message: "See what your check-ins and doses are "
                                + "telling you, every week.",
                            action: { showsPaywall = true }
                        )
                    } else if store.insights.isEmpty && store.isLoading {
```

Keep the rest of the chain as-is. Also guard the header's filter chips and the weekly summary card behind the same condition so a free account does not see filters over a locked surface — wrap `filterChips` and the `if model.showsSummaryCard` block in `if !PremiumGate.showsLock(for: deps.entitlements.entitlement)`.

Guard the data load so a locked tab does not fire a request that returns 402 on every appearance:

```swift
            .task {
                guard !PremiumGate.showsLock(for: deps.entitlements.entitlement) else { return }
                await model.onAppear()
            }
```

Add the sheet to the `NavigationStack`:

```swift
            .sheet(isPresented: $showsPaywall) {
                PaywallView(onDismiss: { showsPaywall = false })
            }
```

- [ ] **Step 5: Register, run tests, build**

Add `PremiumLockedOverlay.swift` to `project.pbxproj`, then run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```
Expected: PASS, including the existing `InsightsListViewModelTests`.

- [ ] **Step 6: Stage and hand off**

```bash
git add ios/peppy/Features/Paywall/Views/PremiumLockedOverlay.swift ios/peppy/Features/Insights/Views/InsightsListView.swift ios/peppy/peppyTests/PremiumGatingTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): lock the insights tab behind premium`

---

## Task 16: Dashboard insight card gating

**Files:**
- Modify: `ios/peppy/Features/Dashboard/Views/DashboardView.swift`

**Interfaces:**
- Consumes: `PremiumGate`, `PaywallView`.
- Produces: no new public API.

- [ ] **Step 1: Read the current card**

Read `ios/peppy/Features/Dashboard/Views/DashboardView.swift:20-140`, specifically the `insightCard(_:)` function at line 109 and its call site at line 30.

- [ ] **Step 2: Add the locked variant**

Add `@State private var showsPaywall = false` to `DashboardView`.

At the call site (around line 30), branch:

```swift
                            if PremiumGate.showsLock(for: deps.entitlements.entitlement) {
                                lockedInsightCard
                            } else {
                                insightCard(summary.insight)
                            }
```

The backend nulls `summary.insight` for free accounts (Task 4), so this branch must not depend on that field being populated. Check whether the enclosing `if let`/`if` binds `summary.insight`; if it does, hoist the locked card outside that binding so it still renders when the field is null.

Add the locked card, matching the surrounding card styling in `DashboardCards.swift` — read that file and reuse its container treatment rather than inventing new padding and corner radii:

```swift
    private var lockedInsightCard: some View {
        Button {
            showsPaywall = true
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Insight")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.pepTextSecondary)

                    Text("Unlock Peppy Premium to see your insights.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pepTextTertiary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.pepBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Insight locked. Unlock Peppy Premium to see your insights.")
    }
```

Attach the sheet to the same view that owns the dashboard's other modifiers:

```swift
        .sheet(isPresented: $showsPaywall) {
            PaywallView(onDismiss: { showsPaywall = false })
        }
```

- [ ] **Step 3: Build and run the dashboard tests**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/DashboardViewModelTests 2>&1 | tail -20
```
Expected: PASS

- [ ] **Step 4: Stage and hand off**

```bash
git add ios/peppy/Features/Dashboard/Views/DashboardView.swift
```

Suggested message: `feat(ios): lock the dashboard insight card behind premium`

---

## Task 17: Settings upsell card and data export lock

**Files:**
- Create: `ios/peppy/Features/Paywall/Views/PremiumUpsellCard.swift`
- Modify: `ios/peppy/Features/Settings/Views/SettingsRootView.swift`, `ios/peppy/Features/Settings/Views/SettingsComponents.swift`, `ios/peppy/Features/Settings/Models/SettingsModels.swift`
- Test: `ios/peppy/peppyTests/PremiumGatingTests.swift` (append)

**Interfaces:**
- Consumes: `PremiumEntitlement`, `PremiumGate`, `PaywallView`.
- Produces: `struct PremiumUpsellCard: View` — `init(entitlement: PremiumEntitlement, action: @escaping () -> Void)`; `SettingsRowModel.isPremiumOnly: Bool` (defaulting `false`); `SettingsRootViewModel.premiumOnlyRoutes: Set<SettingsRoute>`.

- [ ] **Step 1: Write the failing test**

Append to `ios/peppy/peppyTests/PremiumGatingTests.swift`:

```swift
extension PremiumGatingTests {
    func testOnlyDataExportIsPremiumGatedInSettings() {
        XCTAssertEqual(SettingsRootViewModel.premiumOnlyRoutes, [.dataExport])
    }

    func testDataExportRowIsFlaggedPremiumOnly() {
        let row = SettingsRootViewModel.myDataRows.first { $0.route == .dataExport }
        XCTAssertEqual(row?.isPremiumOnly, true)
    }

    func testNotificationsStaysFree() {
        // Dose reminders serve free Protocols; locking them would gut the
        // free tier.
        let row = SettingsRootViewModel.myDataRows.first { $0.route == .notifications }
        XCTAssertEqual(row?.isPremiumOnly, false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:peppyTests/PremiumGatingTests 2>&1 | tail -25
```
Expected: FAIL to compile — `value of type 'SettingsRowModel' has no member 'isPremiumOnly'`

- [ ] **Step 3: Flag the gated row**

In `ios/peppy/Features/Settings/Models/SettingsModels.swift`, add to `SettingsRowModel`:

```swift
    let isPremiumOnly: Bool
```

and give it a default in a memberwise-preserving initializer so existing call sites keep working:

```swift
    init(
        route: SettingsRoute,
        title: String,
        subtitle: String,
        systemImage: String?,
        tone: SettingsRowTone,
        isPremiumOnly: Bool = false
    ) {
        self.route = route
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tone = tone
        self.isPremiumOnly = isPremiumOnly
    }
```

Set `isPremiumOnly: true` on the `.dataExport` row only. Add to `SettingsRootViewModel`:

```swift
    static let premiumOnlyRoutes: Set<SettingsRoute> = [.dataExport]
```

- [ ] **Step 4: Write the upsell card**

Create `ios/peppy/Features/Paywall/Views/PremiumUpsellCard.swift`:

```swift
import SwiftUI

/// Sits above the profile card in More. Upsell for free accounts, status and
/// a management link for paid ones.
struct PremiumUpsellCard: View {
    let entitlement: PremiumEntitlement
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: entitlement.isPremium ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(Color.pepPrimary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)

                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pepTextTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: SettingsFigmaLayout.minimumTapTarget)
            .background(Color.pepPrimaryMuted)
            .clipShape(
                RoundedRectangle(cornerRadius: SettingsFigmaLayout.cardCornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsFigmaLayout.cardCornerRadius)
                    .stroke(Color.pepPrimary.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    private var title: String {
        entitlement.isPremium ? "Peppy Premium" : "Unlock Peppy Premium"
    }

    private var subtitle: String {
        guard entitlement.isPremium else {
            return "Insights, weekly summaries, and data export"
        }
        guard let plan = entitlement.plan else { return "Active" }
        guard plan.isRecurring, let expires = entitlement.expires else {
            return "Lifetime — thank you"
        }
        return "\(plan.title) — renews \(expires.formatted(date: .abbreviated, time: .omitted))"
    }
}

#Preview {
    VStack(spacing: 12) {
        PremiumUpsellCard(entitlement: .free, action: {})
        PremiumUpsellCard(
            entitlement: .premium(plan: .yearly, expires: Date().addingTimeInterval(86_400 * 300)),
            action: {}
        )
        PremiumUpsellCard(entitlement: .premium(plan: .lifetime, expires: nil), action: {})
    }
    .padding(22)
    .background(Color.pepBackground)
}
```

- [ ] **Step 5: Add the lock chip to gated rows**

In `ios/peppy/Features/Settings/Views/SettingsComponents.swift`, give `SettingsSectionCard` a way to know the entitlement and to intercept the tap. Add a stored property and change the row loop:

```swift
struct SettingsSectionCard: View {
    let title: String
    let rows: [SettingsRowModel]
    var lockedRoutes: Set<SettingsRoute> = []
    var onLockedTap: ((SettingsRoute) -> Void)?
```

Inside the `ForEach`, replace the unconditional `NavigationLink` with:

```swift
                    if lockedRoutes.contains(row.route) {
                        Button {
                            onLockedTap?(row.route)
                        } label: {
                            SettingsMenuRow(row: row, isLocked: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: row.route) {
                            SettingsMenuRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
```

In `SettingsMenuRow`, add `var isLocked: Bool = false` and swap the trailing chevron for a lock chip when locked:

```swift
            if isLocked {
                Text("Premium")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.pepPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pepPrimaryMuted)
                    .clipShape(Capsule())
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pepTextTertiary)
                    .accessibilityHidden(true)
            }
```

Extend the accessibility label so the lock is announced:

```swift
        .accessibilityLabel(
            isLocked
                ? "\(row.title), \(row.subtitle), Premium required"
                : "\(row.title), \(row.subtitle)"
        )
```

- [ ] **Step 6: Wire Settings**

In `ios/peppy/Features/Settings/Views/SettingsRootView.swift`, add `@State private var showsPaywall = false`, then insert above `SettingsProfileCard(user: store.user)`:

```swift
                    if dependencies.entitlements.entitlement.isResolved {
                        PremiumUpsellCard(
                            entitlement: dependencies.entitlements.entitlement
                        ) {
                            showsPaywall = true
                        }
                    }
```

Change the "My data" section to pass the gate:

```swift
                    SettingsSectionCard(
                        title: "My data",
                        rows: SettingsRootViewModel.myDataRows,
                        lockedRoutes: PremiumGate.showsLock(
                            for: dependencies.entitlements.entitlement
                        ) ? SettingsRootViewModel.premiumOnlyRoutes : [],
                        onLockedTap: { _ in showsPaywall = true }
                    )
```

Add the sheet next to the existing `.confirmationDialog`:

```swift
        .sheet(isPresented: $showsPaywall) {
            PaywallView(onDismiss: { showsPaywall = false })
        }
```

- [ ] **Step 7: Register, run the full suite**

Add `PremiumUpsellCard.swift` to `project.pbxproj`, then run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```
Expected: PASS. `SettingsNavigationTests` and `SettingsStoreTests` exercise these types — update them for the new `SettingsRowModel` member if they construct rows directly.

- [ ] **Step 8: Stage and hand off**

```bash
git add ios/peppy/Features/Paywall/Views/PremiumUpsellCard.swift ios/peppy/Features/Settings/ ios/peppy/peppyTests/PremiumGatingTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
```

Suggested message: `feat(ios): add premium upsell card and lock data export`

---

## Task 18: Verification and manual QA handoff

**Files:**
- Create: `ios/peppy/docs/superpowers/plans/2026-07-26-premium-paywall-manual-qa.md`
- Modify: `ios/peppy/docs/iOS/iOS_dev.md`

- [ ] **Step 1: Run the full backend suite**

Run: `cd backend && venv/bin/python -m pytest -v 2>&1 | tail -20`
Expected: all PASS. Record the count.

- [ ] **Step 2: Run the full iOS suite**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/peppy/peppy.xcodeproj -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```
Expected: all PASS. Record the count.

- [ ] **Step 3: Verify the gate over HTTP**

Start the backend, register a throwaway account, and confirm the 402:

```bash
cd backend && venv/bin/python -m uvicorn app.main:app --port 8001 &
TOKEN=$(curl -s -X POST localhost:8001/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"gate-check@example.com","password":"Testpass123!"}' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
curl -s -o /dev/null -w '%{http_code}\n' localhost:8001/api/v1/insights \
  -H "Authorization: Bearer $TOKEN"
```
Expected: `402`. Stop the server afterwards.

If the register response key is not `access_token`, read `backend/app/api/schemas/` for the real field name.

- [ ] **Step 4: Write the manual QA checklist**

Create `ios/peppy/docs/superpowers/plans/2026-07-26-premium-paywall-manual-qa.md` covering, each as a "do X, expect Y" line:

1. Fresh install → complete onboarding → register → paywall appears with Yearly preselected, "For You 50% OFF" badge on the yearly card, prices $24.99 / $7.99 / $139.99.
2. "Peppy" renders in the rounded app font and "Premium" in the coral Fraunces italic — compare against the marketing site's emphasis styling.
3. Tap Monthly → selection moves, price recap updates to $7.99/month, discount chip disappears.
4. Tap Lifetime → "Cancel Anytime" disappears, legal line switches to one-time purchase wording.
5. Tap Continue → Apple purchase sheet appears (StoreKit configuration) → confirm → paywall dismisses to the dashboard.
6. Insights tab now shows real insights; Data export row has no Premium chip; More tab card reads "Peppy Premium".
7. Delete the app, reinstall, sign in → Insights blurred with "Unlock Insights", Data export shows the Premium chip, dashboard insight card shows the locked variant.
8. Tap Restore Purchase on the paywall → entitlement returns without paying again.
9. Cancel the purchase sheet → no error banner, cards stay tappable.
10. Sign out and sign in as a returning free user → paywall does NOT auto-appear; check-ins and protocols work normally.
11. Airplane mode → open the paywall → "We couldn't load plans" with a working Retry.

Note at the top that simulator StoreKit purchases require the scheme's StoreKit configuration to be set to `Peppy.storekit`, and that transactions can be reset from Xcode's Debug → StoreKit → Manage Transactions.

- [ ] **Step 5: Update the iOS dev log**

Append a section to `ios/peppy/docs/iOS/iOS_dev.md` following the file's existing format, noting: `.futurePaywall` replaced by a real `.paywall` route shown after registration; StoreKit 2 service and `EntitlementStore`; backend `subscription_*` columns and 402 gating on insights/export; Fraunces bundled as the accent face.

- [ ] **Step 6: Record the pre-launch blocker**

Add to the top of the manual QA doc, under a **Blockers before App Store submission** heading:

1. `APPLE_VERIFY_RECEIPTS` must be `true` in production, and `verify_apple_signature()` in `backend/app/services/subscription.py` must be implemented against Apple's root CA chain. Until then a crafted `POST /api/v1/subscription/apple` can grant premium.
2. The three products must exist in App Store Connect with the exact IDs in `PremiumPlan`, the yearly and monthly ones in one subscription group, Family Sharing enabled on yearly and lifetime to match the card copy.
3. The struck-through "was" price is computed as 2× the live yearly price. If the real App Store Connect list price is not exactly double, replace `originalDisplayPrice(for:product:)` with a configured introductory offer.

- [ ] **Step 7: Stage and hand off**

```bash
git add ios/peppy/docs/
```

Suggested message: `docs: premium paywall QA checklist and dev log`

Report to Gabriel: both suites' pass counts, the 402 curl result, and the three pre-launch blockers.

---

## Self-Review Notes

**Spec coverage:** Payment layer → Tasks 6–8. Entitlement flow → Task 9. Backend → Tasks 1–4. Typography → Task 10. Paywall screen → Tasks 11–13. Gating surfaces → Tasks 14–17 (post-registration, Insights, dashboard, data export, More tab). Error handling → Task 5 (402), Task 9 (unsynced retry), Task 11 (load/purchase states). Testing → per-task plus Task 18.

**Type consistency:** `EntitlementStore.purchase` returns `PurchaseOutcome` in Task 9's interface block, implementation, and tests, and is consumed as `PurchaseOutcome` in Task 11 — no signature drifts between tasks. `PremiumGate.showsLock` is defined in Task 15 and consumed identically in Tasks 15–17. `PremiumProduct`, `VerifiedPurchase`, and `PurchaseOutcome` are defined once in Task 8 and used unchanged thereafter.

**Deliberately not covered:** App Store Server Notifications V2, Android/web paywalls, promotional offers, and grandfathering existing accounts — all listed as non-goals in the spec.
