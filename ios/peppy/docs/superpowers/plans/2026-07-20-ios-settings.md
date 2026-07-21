# Peppy iOS Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the iOS More placeholder with the approved hybrid account-backed Settings experience, including profile editing, reminders and insight push, secure export, optional Face ID, password rotation, account deletion, and web-backed help/legal content.

**Architecture:** The FastAPI backend owns account profile, reminder preferences, export contents, password rotation, and deletion. SwiftUI owns presentation and device-specific effects behind injected services for LocalAuthentication, local notifications, APNs registration, protected export files, and in-app browsing. Existing `APIClientProtocol`, `Dependencies`, stores, navigation, design tokens, and backend services are extended rather than replaced.

**Tech Stack:** Swift 5, SwiftUI, Observation, LocalAuthentication, UserNotifications, UIKit/SafariServices, Foundation, XCTest, Xcode 26.6, iOS 17 minimum; Python 3.11, FastAPI, Pydantic v2, SQLAlchemy async, Alembic, aioapns 4.0, ReportLab 5.0.0, pytest; Next.js 16.2.6, React 19.2.4, TypeScript 5, Tailwind CSS 4, Playwright 1.60.0

## Global Constraints

- The approved design is `ios/peppy/docs/superpowers/specs/2026-07-20-ios-settings-design.md`.
- The exact visual source is `/Users/gabri/Downloads/Peppy IOS (2).fig`, exported 2026-06-12 at 03:10 UTC. Match the More, Profile, Notifications, Data Export, Security & Privacy, and Help & About frames.
- Keep the bottom tab bar visible on Settings detail screens, as shown in the approved Figma frames.
- Omit Labs, Connected Data, Timeline, Active Sessions, Data Permissions, and email editing. Do not add disabled placeholders.
- Full name, measurement preferences, baseline date/weight/height, ordered goals, notification preferences, and reminder times are account-backed.
- Dose and daily check-in notifications are scheduled locally for this release. Insights use APNs. Keep the reminder contract reusable by a future server scheduler.
- Notification content is generic by default. Detailed content requires a separate explicit opt-in after system notification authorization.
- Quiet hours suppress daily check-ins and routine insights. Dose reminders and alert-severity insights bypass quiet hours.
- Export only account/profile/preferences, Protocols and dose logs, Check-ins, and Insights. Do not expose Labs or Wearables selectors.
- Export is an immediate authenticated PDF or CSV ZIP stream. Do not create an export table, object-storage artifact, email, history, or durable server file.
- Face ID is optional. It gates cold launch and resumes after five continuous background minutes; it never causes routine password prompts.
- Password changes invalidate every existing access and refresh token and return the initiating device to sign-in.
- Account deletion requires password reauthentication plus a separate irreversible confirmation and deletes active-system data before returning success.
- Public copy may say that underlying services support HIPAA-eligible configurations only when verified. It must not claim Peppy is HIPAA compliant or has BAAs.
- Public AI copy says `third-party AI processing service`; do not name the provider in iOS or web copy.
- Never log passwords, tokens, health content, notification detail text, export contents, or AI inputs. Use opaque request and record identifiers.
- Keep all iOS networking behind `APIClientProtocol`; every new endpoint and device service needs deterministic mocks.
- Reuse Peppy's existing SwiftUI tokens and components. Do not add a parallel design system or third-party iOS UI dependency.
- Before editing `web/`, read the relevant App Router and client-component guidance in `web/node_modules/next/dist/docs/`, as required by `web/AGENTS.md`.
- Add `NSFaceIDUsageDescription` and the Push Notifications capability through Xcode-supported project settings. Do not hand-edit provisioning profiles.
- Follow TDD: observe a focused failing test before each behavior implementation and run the relevant full suite before staging.
- Before handoff, use Product Design design QA to compare reference and simulator screenshots together at matching viewports, then repeat after fixes.
- Do not run `git commit`. At each checkpoint, stage only that task's files, run `git diff --cached --check`, and report the suggested commit message to Gabriel.

---
### Task 1: Add The Account Settings Persistence Model

**Files:**
- Create: `backend/alembic/versions/e8f9a0b1c2d3_settings_account_slice.py`
- Create: `backend/tests/test_settings_models.py`
- Modify: `backend/app/models/user.py:1-32`
- Modify: `backend/app/models/profile.py:1-59`
- Modify: `backend/app/models/notification.py:1-34`
- Modify: `backend/app/models/protocol.py:18-37`
- Modify: `backend/app/models/__init__.py:1-36`

**Interfaces:**
- Consumes: existing `User`, `OnboardingProfile`, `NotificationPreference`, `DeviceToken`, `Compound`, and Alembic head `d7e8f9a0b1c2`.
- Produces: `User.auth_version`, profile baseline/ordered-goal columns, `DoseReminderSetting`, account-backed reminder fields, and globally unique APNs tokens.

- [ ] **Step 1: Write failing model tests**

Create `backend/tests/test_settings_models.py`:

```python
from datetime import date, time

from sqlalchemy import select

from app.models.notification import DoseReminderSetting, NotificationPreference
from app.models.profile import OnboardingProfile
from app.models.user import User


async def test_settings_models_persist_defaults_and_profile_fields(db_session):
    user = User(email="settings-model@example.com", hashed_password="hash")
    db_session.add(user)
    await db_session.flush()
    profile = OnboardingProfile(
        user_id=user.id,
        baseline_date=date(2026, 7, 20),
        primary_goal="track_protocols",
        secondary_goal="build_habits",
        focus_area="understand_body",
    )
    preferences = NotificationPreference(
        user_id=user.id,
        dose_reminders_enabled=True,
        daily_checkin_reminders_enabled=True,
        daily_checkin_time=time(9, 0),
        detailed_previews_enabled=False,
    )
    db_session.add_all([profile, preferences])
    await db_session.commit()

    saved_user = await db_session.scalar(select(User).where(User.id == user.id))
    saved_profile = await db_session.scalar(
        select(OnboardingProfile).where(OnboardingProfile.user_id == user.id)
    )
    saved_preferences = await db_session.scalar(
        select(NotificationPreference).where(NotificationPreference.user_id == user.id)
    )
    assert saved_user.auth_version == 1
    assert saved_profile.baseline_date == date(2026, 7, 20)
    assert saved_preferences.daily_checkin_time == time(9, 0)
    assert saved_preferences.detailed_previews_enabled is False


async def test_dose_reminder_is_unique_per_user_and_compound(db_session):
    assert DoseReminderSetting.__table__.c.user_id.foreign_keys
    assert DoseReminderSetting.__table__.c.compound_id.foreign_keys
    names = {constraint.name for constraint in DoseReminderSetting.__table__.constraints}
    assert "uq_dose_reminder_user_compound" in names
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run from `backend/`:

```bash
pytest tests/test_settings_models.py -v
```

Expected: collection or attribute failures because the new fields and `DoseReminderSetting` do not exist.

- [ ] **Step 3: Add the SQLAlchemy model fields and relationships**

Add these model contracts:

```python
# backend/app/models/user.py
auth_version = Column(Integer, default=1, server_default="1", nullable=False)
dose_reminder_settings = relationship(
    "DoseReminderSetting", back_populates="user", cascade="all, delete-orphan"
)

# backend/app/models/profile.py
baseline_date = Column(Date, nullable=True)
primary_goal = Column(String(100), nullable=True)
secondary_goal = Column(String(100), nullable=True)
focus_area = Column(String(100), nullable=True)

# backend/app/models/notification.py
class DoseReminderSetting(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "dose_reminder_settings"
    __table_args__ = (
        UniqueConstraint("user_id", "compound_id", name="uq_dose_reminder_user_compound"),
    )

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    compound_id = Column(GUID(), ForeignKey("compounds.id", ondelete="CASCADE"), nullable=False, index=True)
    local_time = Column(Time, nullable=False)
    enabled = Column(Boolean, default=True, server_default="1", nullable=False)
    user = relationship("User", back_populates="dose_reminder_settings")
    compound = relationship("Compound", back_populates="reminder_settings")
```

Add `dose_reminders_enabled`, `daily_checkin_reminders_enabled`,
`daily_checkin_time`, and `detailed_previews_enabled` to
`NotificationPreference`, all non-null booleans except the nullable time. Add
`Compound.reminder_settings` with `cascade="all, delete-orphan"`. Add a unique
constraint to `DeviceToken.token` so one installation cannot receive pushes for
two accounts. Export `DoseReminderSetting` from `models/__init__.py`.

- [ ] **Step 4: Write the additive migration**

Use revision `e8f9a0b1c2d3` and `down_revision = "d7e8f9a0b1c2"`. The upgrade must:

```python
op.add_column("users", sa.Column("auth_version", sa.Integer(), server_default="1", nullable=False))
op.add_column("onboarding_profiles", sa.Column("baseline_date", sa.Date(), nullable=True))
op.add_column("onboarding_profiles", sa.Column("primary_goal", sa.String(100), nullable=True))
op.add_column("onboarding_profiles", sa.Column("secondary_goal", sa.String(100), nullable=True))
op.add_column("onboarding_profiles", sa.Column("focus_area", sa.String(100), nullable=True))
op.add_column("notification_preferences", sa.Column("dose_reminders_enabled", sa.Boolean(), server_default=sa.false(), nullable=False))
op.add_column("notification_preferences", sa.Column("daily_checkin_reminders_enabled", sa.Boolean(), server_default=sa.false(), nullable=False))
op.add_column("notification_preferences", sa.Column("daily_checkin_time", sa.Time(), nullable=True))
op.add_column("notification_preferences", sa.Column("detailed_previews_enabled", sa.Boolean(), server_default=sa.false(), nullable=False))
```

Create `dose_reminder_settings` with UUID/timestamp mixin columns, cascade FKs,
the named unique constraint, and indexes. Deduplicate existing device tokens by
keeping the most recently updated row before adding `uq_device_tokens_token`.
The downgrade removes the new table, constraint, and columns in reverse order.

- [ ] **Step 5: Verify model tests and the migration round trip**

Run from `backend/` against a disposable local database; never run this
downgrade against shared development, staging, or production data:

```bash
pytest tests/test_settings_models.py -v
alembic upgrade head
alembic downgrade d7e8f9a0b1c2
alembic upgrade head
```

Expected: two model tests pass and all three Alembic commands exit zero.

- [ ] **Step 6: Run the backend suite and stage the checkpoint**

```bash
pytest -q
git add backend/alembic/versions/e8f9a0b1c2d3_settings_account_slice.py backend/app/models backend/tests/test_settings_models.py
git diff --cached --check
```

Expected: zero test failures and no whitespace errors. Suggested commit:
`feat: add settings persistence model`.

---

### Task 2: Add Account And Profile Settings APIs

**Files:**
- Create: `backend/tests/test_settings_profile.py`
- Modify: `backend/app/api/routes/auth.py:13-164`
- Modify: `backend/app/api/routes/profile.py:1-74`
- Modify: `backend/app/api/schemas/profile.py:1-126`
- Modify: `backend/app/services/profile.py:13-210`
- Modify: `backend/app/services/user.py:10-55`

**Interfaces:**
- Consumes: Task 1 fields, `GET /api/v1/auth/me`, and `GET/PATCH /api/v1/profile/onboarding`.
- Produces: `PATCH /api/v1/auth/me`, expanded profile responses, explicit-null clearing for optional goals, and legacy ordered-goal fallback.

- [ ] **Step 1: Write failing route tests for read-only email and profile updates**

Create `backend/tests/test_settings_profile.py` with a registration/login fixture and these cases:

```python
async def test_patch_me_updates_name_and_timezone_but_not_email(client, auth_headers):
    response = await client.patch(
        "/api/v1/auth/me",
        headers=auth_headers,
        json={"display_name": "  Alex Morgan  ", "timezone": "America/New_York"},
    )
    assert response.status_code == 200
    assert response.json()["display_name"] == "Alex Morgan"
    assert response.json()["timezone"] == "America/New_York"

    rejected = await client.patch(
        "/api/v1/auth/me",
        headers=auth_headers,
        json={"email": "changed@example.com"},
    )
    assert rejected.status_code == 422


async def test_profile_patch_creates_record_and_clears_optional_goal(client, auth_headers):
    created = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={
            "baseline_date": "2026-05-01",
            "weight_kg": 84.55,
            "height_cm": 177.8,
            "preferred_weight_unit": "lb",
            "preferred_height_unit": "ft_in",
            "primary_goal": "track_protocols",
            "secondary_goal": "build_habits",
            "focus_area": "understand_body",
        },
    )
    assert created.status_code == 200
    assert created.json()["primary_goal"] == "track_protocols"

    cleared = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"secondary_goal": None, "focus_area": None},
    )
    assert cleared.status_code == 200
    assert cleared.json()["secondary_goal"] is None
    assert cleared.json()["focus_area"] is None

    missing_primary = await client.patch(
        "/api/v1/profile/onboarding",
        headers=auth_headers,
        json={"primary_goal": None},
    )
    assert missing_primary.status_code == 422
```

Add a service test proving a legacy `goals=["track_protocols", "build_habits", "custom"]`
response derives primary/secondary without mutating or dropping the original list.

- [ ] **Step 2: Run the tests and verify endpoint/schema failures**

```bash
pytest tests/test_settings_profile.py -v
```

Expected: 405 for `PATCH /auth/me` and validation/response failures for the new profile fields.

- [ ] **Step 3: Add strict user-update and response schemas**

In `auth.py`, add:

```python
class UserUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    display_name: str | None = Field(default=None, max_length=100)
    timezone: str | None = Field(default=None, max_length=50)

    @field_validator("display_name")
    @classmethod
    def normalize_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @field_validator("timezone")
    @classmethod
    def valid_timezone(cls, value: str | None) -> str | None:
        if value is not None:
            ZoneInfo(value)
        return value
```

Add `timezone` to `UserResponse` and implement `PATCH /me` by passing only
`model_dump(exclude_unset=True)` fields to `UserService.update`.

- [ ] **Step 4: Extend the profile contract without erasing onboarding data**

Add `baseline_date`, `primary_goal`, `secondary_goal`, and `focus_area` to
`OnboardingProfilePayload` and `OnboardingProfileResponse`. Define one shared
backend enum whose values exactly match the six existing iOS
`OnboardingGoal.serverValue` strings. Primary, secondary, and focus all use this
same vocabulary; do not create a Settings-only focus vocabulary. Reject an
explicit-null primary goal while allowing omission for partial updates and
legacy profiles. Add the names to `PROFILE_FIELDS` and return them from
`to_payload`. Resolve ordered goals from supported legacy values only:

```python
legacy_goals = list(profile.goals or [])
supported = [goal for goal in legacy_goals if goal in PROFILE_GOAL_VALUES]
primary_goal = profile.primary_goal or (supported[0] if supported else None)
secondary_goal = profile.secondary_goal or (supported[1] if len(supported) > 1 else None)
```

Do not rewrite `profile.goals` during reads. Keep `patch_profile` based on
`model_dump(exclude_unset=True)` so explicit JSON null clears an optional value
and omitted fields remain unchanged.

- [ ] **Step 5: Run focused and full backend tests**

```bash
pytest tests/test_settings_profile.py tests/test_profile_routes.py tests/test_profile_service.py tests/test_auth.py -v
pytest -q
```

Expected: all focused and full-suite tests pass.

- [ ] **Step 6: Stage the checkpoint**

```bash
git add backend/app/api/routes/auth.py backend/app/api/routes/profile.py backend/app/api/schemas/profile.py backend/app/services/profile.py backend/app/services/user.py backend/tests/test_settings_profile.py
git diff --cached --check
```

Suggested commit: `feat: add account profile settings API`.

---

### Task 3: Rotate Passwords And Invalidate Every Token

**Files:**
- Create: `backend/tests/test_password_rotation.py`
- Modify: `backend/app/services/auth.py:1-38`
- Modify: `backend/app/services/user.py:1-55`
- Modify: `backend/app/api/deps.py:15-70`
- Modify: `backend/app/api/routes/auth.py:1-164`

**Interfaces:**
- Consumes: `User.auth_version` from Task 1 and current register/login/refresh flows.
- Produces: JWT `ver` claim, `POST /api/v1/auth/change-password`, and immediate access/refresh invalidation across devices.

- [ ] **Step 1: Write failing rotation tests**

Create `backend/tests/test_password_rotation.py`:

```python
async def test_password_change_invalidates_old_access_and_refresh_tokens(client):
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "rotate@example.com", "password": "password123"},
    )
    old = registered.json()
    response = await client.post(
        "/api/v1/auth/change-password",
        headers={"Authorization": f"Bearer {old['access_token']}"},
        json={"current_password": "password123", "new_password": "replacement456"},
    )
    assert response.status_code == 204
    assert (await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {old['access_token']}"},
    )).status_code == 401
    assert (await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old["refresh_token"]},
    )).status_code == 401
    assert (await client.post(
        "/api/v1/auth/login",
        json={"email": "rotate@example.com", "password": "replacement456"},
    )).status_code == 200


async def test_wrong_current_password_does_not_rotate_tokens(client, authenticated_tokens):
    response = await client.post(
        "/api/v1/auth/change-password",
        headers={"Authorization": f"Bearer {authenticated_tokens['access_token']}"},
        json={"current_password": "wrong-value", "new_password": "replacement456"},
    )
    assert response.status_code == 400
    assert (await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {authenticated_tokens['access_token']}"},
    )).status_code == 200
```

- [ ] **Step 2: Run the focused tests and verify they fail**

```bash
pytest tests/test_password_rotation.py -v
```

Expected: 404 for the change-password route and no `ver` enforcement.

- [ ] **Step 3: Add versioned token creation and validation**

Always call token creation with both claims:

```python
claims = {"sub": str(user.id), "ver": user.auth_version}
access_token = create_access_token(data=claims)
refresh_token = create_refresh_token(data=claims)
```

In `get_current_user` and refresh, accept missing `ver` as version 1 so deployment
does not force every existing user out, then reject mismatches:

```python
if payload.get("ver", 1) != user.auth_version:
    raise HTTPException(status_code=401, detail="Session has been revoked")
```

- [ ] **Step 4: Add the atomic password-change operation**

Define a strict request with current/new password fields, both at least eight
characters. Reject a replacement equal to the current password. Implement:

```python
async def change_password(self, user: User, current_password: str, new_password: str) -> None:
    if not verify_password(current_password, user.hashed_password):
        raise ValueError("Current password is incorrect")
    if verify_password(new_password, user.hashed_password):
        raise ValueError("New password must be different")
    user.hashed_password = hash_password(new_password)
    user.auth_version += 1
    await self.db.commit()
```

The route maps `ValueError` to 400 and returns 204 only after commit.

- [ ] **Step 5: Run auth tests and the full suite**

```bash
pytest tests/test_password_rotation.py tests/test_auth.py tests/test_user_service.py -v
pytest -q
```

Expected: old access and refresh tokens fail, the new password works, and all
existing auth tests pass.

- [ ] **Step 6: Stage the checkpoint**

```bash
git add backend/app/services/auth.py backend/app/services/user.py backend/app/api/deps.py backend/app/api/routes/auth.py backend/tests/test_password_rotation.py
git diff --cached --check
```

Suggested commit: `feat: invalidate sessions on password change`.

---

### Task 4: Permanently Delete Accounts From Active Systems

**Files:**
- Create: `backend/app/services/account.py`
- Create: `backend/tests/test_account_deletion.py`
- Modify: `backend/app/api/routes/auth.py:1-190`

**Interfaces:**
- Consumes: authenticated `CurrentUser`, password verification, all user-owned SQLAlchemy models.
- Produces: `AccountService.delete_account(user, current_password) -> None` and `DELETE /api/v1/auth/account`.

- [ ] **Step 1: Write failing deletion inventory, reauthentication, and rollback tests**

Create users with profile, protocol/compound/dose log, check-in, lab, insight,
weekly summary, wearable connection/data, job, notification preference, device
token, and dose reminder. Assert:

```python
async def test_delete_account_removes_complete_user_inventory(client, populated_account):
    response = await client.request(
        "DELETE",
        "/api/v1/auth/account",
        headers=populated_account.headers,
        json={"current_password": "password123"},
    )
    assert response.status_code == 204
    for model in populated_account.user_owned_models:
        assert await populated_account.count(model) == 0
    assert (await client.get("/api/v1/auth/me", headers=populated_account.headers)).status_code == 401


async def test_delete_account_wrong_password_preserves_every_record(client, populated_account):
    before = await populated_account.counts()
    response = await client.request(
        "DELETE",
        "/api/v1/auth/account",
        headers=populated_account.headers,
        json={"current_password": "wrong-value"},
    )
    assert response.status_code == 400
    assert await populated_account.counts() == before
```

Add a service test that injects a failure before commit, calls rollback, and
asserts the complete count map is unchanged.

- [ ] **Step 2: Run the focused tests and verify they fail**

```bash
pytest tests/test_account_deletion.py -v
```

Expected: missing route/service failures.

- [ ] **Step 3: Implement an explicit deletion inventory**

`AccountService` must verify the password before any delete. Delete relationship
gaps explicitly before the user row, including `WeeklySummary` and
`WearableData`, then delete the user so configured ORM cascades remove owned
children. Keep one transaction:

```python
async def delete_account(self, user: User, current_password: str) -> None:
    if not verify_password(current_password, user.hashed_password):
        raise ValueError("Current password is incorrect")
    try:
        await self.db.execute(delete(WeeklySummary).where(WeeklySummary.user_id == user.id))
        await self.db.execute(delete(WearableData).where(WearableData.user_id == user.id))
        await self.db.delete(user)
        await self.db.commit()
    except Exception:
        await self.db.rollback()
        raise
```

The deletion inventory test must enumerate every current user-owned model. The
service explicitly deletes `WeeklySummary` and `WearableData`; the `User`
relationship cascades delete the remaining enumerated rows. Treat any new
user-owned model without a verified cascade as a failing test and add its
explicit delete inside the same transaction.

- [ ] **Step 4: Add the reauthenticated route**

Define `AccountDeletionRequest(current_password: str)` with `extra="forbid"`.
Map an incorrect password to 400. Return 204 with no body only after the
transaction commits. Do not enqueue asynchronous deletion work.

- [ ] **Step 5: Run deletion, model, and full backend tests**

```bash
pytest tests/test_account_deletion.py tests/test_settings_models.py -v
pytest -q
```

Expected: complete deletion, preserved data on bad password/rollback, and zero
full-suite failures.

- [ ] **Step 6: Stage the checkpoint**

```bash
git add backend/app/services/account.py backend/app/api/routes/auth.py backend/tests/test_account_deletion.py
git diff --cached --check
```

Suggested commit: `feat: add permanent account deletion`.

---

### Task 5: Extend Notification Preferences And Quiet-Hour Semantics

**Files:**
- Create: `backend/tests/test_notification_settings.py`
- Modify: `backend/app/api/schemas/notification.py:1-56`
- Modify: `backend/app/api/routes/notifications.py:1-88`
- Modify: `backend/app/services/notification.py:1-184`

**Interfaces:**
- Consumes: Task 1 notification fields and active `Protocol`/`Compound` ownership.
- Produces: expanded GET/PATCH preference payloads, atomic per-compound schedules, timezone-aware quiet hours, generic/detailed insight selection, and alert bypass.

- [ ] **Step 1: Write failing preference and delivery-policy tests**

Cover atomic schedule replacement, foreign compound rejection, explicit clearing,
overnight quiet hours, routine suppression, and alert bypass:

```python
async def test_patch_preferences_replaces_owned_dose_schedules(client, account_with_protocol):
    compound = account_with_protocol.compound
    response = await client.patch(
        "/api/v1/notifications/preferences",
        headers=account_with_protocol.headers,
        json={
            "dose_reminders_enabled": True,
            "daily_checkin_reminders_enabled": True,
            "daily_checkin_time": "09:00:00",
            "detailed_previews_enabled": False,
            "quiet_hours_start": "22:00:00",
            "quiet_hours_end": "07:00:00",
            "dose_reminders": [{"compound_id": str(compound.id), "local_time": "08:30:00", "enabled": True}],
        },
    )
    assert response.status_code == 200
    assert response.json()["dose_reminders"][0]["compound_id"] == str(compound.id)


async def test_alert_insight_bypasses_quiet_hours(db_session, notification_fixture):
    result = await notification_fixture.service.send_insight_notification(
        user_id=notification_fixture.user.id,
        insight_id=notification_fixture.insight_id,
        title="Sensitive detail",
        body="Sensitive body",
        severity=InsightSeverity.ALERT,
        ios_adapter=notification_fixture.adapter,
        now=datetime(2026, 7, 21, 3, 0, tzinfo=timezone.utc),
    )
    assert result["sent"] == 1
    assert notification_fixture.adapter.sent[0]["body"] == "A Peppy alert needs your attention."
```

- [ ] **Step 2: Run tests and verify schema/service failures**

```bash
pytest tests/test_notification_settings.py -v
```

Expected: new request fields are rejected or absent and alert delivery is skipped
during quiet hours.

- [ ] **Step 3: Add strict notification schemas**

Define:

```python
class DoseReminderSettingPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")
    compound_id: UUID
    local_time: time
    enabled: bool = True


class NotificationPreferenceUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    insights_enabled: bool | None = None
    alert_severity_only: bool | None = None
    dose_reminders_enabled: bool | None = None
    daily_checkin_reminders_enabled: bool | None = None
    daily_checkin_time: time | None = None
    detailed_previews_enabled: bool | None = None
    quiet_hours_start: time | None = None
    quiet_hours_end: time | None = None
    dose_reminders: list[DoseReminderSettingPayload] | None = None
```

Expand the response with all fields plus the ordered dose-reminder array. The
route passes `model_dump(exclude_unset=True)` so explicit null clears time/quiet
hours and omitted fields are preserved.

- [ ] **Step 4: Make preference replacement atomic and ownership-safe**

Change the service contract to:

```python
async def update_preferences(self, user: User, changes: dict[str, Any]) -> NotificationPreference:
```

Validate every supplied compound belongs to the user's active protocol before
mutating anything. Reject duplicate compound IDs. Replace only the supplied
dose-reminder collection; omitting it preserves existing rows. Commit once after
preference and schedule changes.

- [ ] **Step 5: Correct quiet hours and notification privacy**

Use `ZoneInfo(user.timezone)` and an injected UTC `now` for deterministic tests.
Apply policy in this order:

```python
if not pref.insights_enabled:
    return skipped("insights_disabled")
if pref.alert_severity_only and severity != InsightSeverity.ALERT:
    return skipped("alert_only")
if severity != InsightSeverity.ALERT and self._is_quiet_hours(pref, user.timezone, now):
    return skipped("quiet_hours")
title_to_send = title if pref.detailed_previews_enabled else "Peppy"
body_to_send = body if pref.detailed_previews_enabled else (
    "A Peppy alert needs your attention."
    if severity == InsightSeverity.ALERT
    else "A new Peppy insight is ready."
)
```

Keep APNs `data` limited to opaque `insight_id`.

- [ ] **Step 6: Run notification and full backend tests**

```bash
pytest tests/test_notification_settings.py tests/test_insight_generation.py -v
pytest -q
```

Expected: all preference, policy, existing insight-generation, and full-suite
tests pass.

- [ ] **Step 7: Stage the checkpoint**

```bash
git add backend/app/api/schemas/notification.py backend/app/api/routes/notifications.py backend/app/services/notification.py backend/tests/test_notification_settings.py
git diff --cached --check
```

Suggested commit: `feat: add account reminder preferences`.

---

### Task 6: Implement Production APNs Delivery

**Files:**
- Create: `backend/tests/test_apns_adapter.py`
- Modify: `backend/requirements.txt:21-42`
- Modify: `backend/app/config.py:44-54`
- Modify: `backend/app/integrations/push.py:1-57`
- Modify: `backend/app/services/notification.py:1-210`
- Modify: `backend/app/services/insight_generation.py:112-147`

**Interfaces:**
- Consumes: Task 5 delivery policy, existing `PushAdapter`, device-token rows, and alert generation.
- Produces: `PushDeliveryResult`, aioapns-backed `APNsAdapter`, invalid-token cleanup, and configured alert dispatch.

- [ ] **Step 1: Write failing adapter and integration tests**

Use an injected fake aioapns client:

```python
async def test_apns_adapter_builds_alert_payload_without_logging_body(fake_apns):
    adapter = APNsAdapter(fake_apns)
    result = await adapter.send(
        token="abc123",
        title="Peppy",
        body="A new Peppy insight is ready.",
        data={"insight_id": "opaque-id"},
    )
    assert result.success is True
    request = fake_apns.requests[0]
    assert request.message["aps"]["alert"]["title"] == "Peppy"
    assert request.message["insight_id"] == "opaque-id"


async def test_unregistered_apns_token_is_deleted(notification_fixture):
    notification_fixture.adapter.result = PushDeliveryResult(
        success=False, invalid_token=True, reason="Unregistered"
    )
    await notification_fixture.service.send_push(
        notification_fixture.user.id,
        "Peppy",
        "A new Peppy insight is ready.",
        ios_adapter=notification_fixture.adapter,
    )
    assert await notification_fixture.service.list_devices(notification_fixture.user.id) == []
```

Add a generation test proving configured APNs is passed to
`send_insight_notification` after the insight transaction commits.

- [ ] **Step 2: Run tests and verify placeholder failures**

```bash
pytest tests/test_apns_adapter.py tests/test_insight_generation.py -v
```

Expected: missing result type and `NotImplementedError` from the current adapter.

- [ ] **Step 3: Pin the production libraries and configuration**

Add:

```text
aioapns==4.0
```

Add empty-by-default settings: `apns_key`, `apns_key_id`, `apns_team_id`,
`apns_topic` (bundle ID), and `apns_use_sandbox`. Never log the signing key.

- [ ] **Step 4: Implement the adapter with an injectable client**

Use aioapns `APNs`, `NotificationRequest`, and `PushType.ALERT`. Define:

```python
@dataclass(frozen=True)
class PushDeliveryResult:
    success: bool
    invalid_token: bool = False
    reason: str | None = None
```

`APNsAdapter.from_settings(settings)` returns `None` unless every required APNs
value is configured; otherwise it constructs one long-lived aioapns client with
the `.p8` key text, key ID, team ID, topic, and sandbox flag. Map APNs reasons
`BadDeviceToken`, `DeviceTokenNotForTopic`, and `Unregistered` to
`invalid_token=True`. Do not include title/body/token values in logs.

- [ ] **Step 5: Wire delivery and invalid-token cleanup**

Update `NotificationService.send_push` to collect invalid `DeviceToken` rows,
delete them, and commit once after the loop. In `run_generation`, build the APNs
adapter from settings and pass it to `send_insight_notification`; keep push
failure isolated after the insight commit.

- [ ] **Step 6: Run focused, full, and dependency checks**

```bash
python -m pip install -r requirements.txt
pytest tests/test_apns_adapter.py tests/test_notification_settings.py tests/test_insight_generation.py -v
pytest -q
```

Expected: adapter/policy/generation tests pass and the full suite has zero failures.

- [ ] **Step 7: Stage the checkpoint**

```bash
git add backend/requirements.txt backend/app/config.py backend/app/integrations/push.py backend/app/services/notification.py backend/app/services/insight_generation.py backend/tests/test_apns_adapter.py backend/tests/test_insight_generation.py
git diff --cached --check
```

Suggested commit: `feat: deliver insight alerts through APNs`.

---

### Task 7: Generate Immediate PDF And CSV ZIP Exports

**Files:**
- Create: `backend/app/api/schemas/export.py`
- Create: `backend/app/services/export.py`
- Create: `backend/tests/test_data_export.py`
- Modify: `backend/app/api/routes/profile.py:1-80`
- Modify: `backend/requirements.txt:21-42`

**Interfaces:**
- Consumes: authenticated user and existing profile, protocol, compound, dose-log, check-in, and insight models.
- Produces: `POST /api/v1/profile/export`, `DataExportRequest`, `ExportService.generate`, streamed PDF or ZIP bytes, and no durable export record.

- [ ] **Step 1: Write failing content, ownership, filtering, and non-retention tests**

Create `backend/tests/test_data_export.py`:

```python
async def test_csv_export_contains_manifest_and_only_selected_owned_data(client, export_accounts):
    response = await client.post(
        "/api/v1/profile/export",
        headers=export_accounts.primary_headers,
        json={
            "format": "csv",
            "include_protocols": True,
            "include_checkins": False,
            "include_insights": True,
            "start_date": "2026-07-01",
            "end_date": "2026-07-20",
        },
    )
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/zip")
    archive = ZipFile(BytesIO(response.content))
    assert set(archive.namelist()) == {
        "manifest.json", "account.csv", "profile.csv", "preferences.csv",
        "protocols.csv", "compounds.csv", "dose_logs.csv", "insights.csv",
    }
    assert export_accounts.other_email.encode() not in response.content
    assert "checkins.csv" not in archive.namelist()


async def test_pdf_export_is_valid_and_no_export_record_is_persisted(client, export_accounts):
    before_tables = set(Base.metadata.tables)
    response = await client.post(
        "/api/v1/profile/export",
        headers=export_accounts.primary_headers,
        json={"format": "pdf", "include_protocols": False, "include_checkins": False, "include_insights": False},
    )
    assert response.status_code == 200
    assert response.content.startswith(b"%PDF")
    assert set(Base.metadata.tables) == before_tables
    assert "exports" not in Base.metadata.tables
```

Add tests for inclusive dates, invalid ranges, account-only output, UTF-8 notes,
CSV cells beginning with `=`, `+`, `-`, or `@`, and unauthenticated requests.

- [ ] **Step 2: Run tests and verify the route is missing**

```bash
pytest tests/test_data_export.py -v
```

Expected: 404 for the export route.

- [ ] **Step 3: Define a strict export request**

Create `api/schemas/export.py`:

```python
class ExportFormat(str, Enum):
    PDF = "pdf"
    CSV = "csv"


class DataExportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    format: ExportFormat
    include_protocols: bool = True
    include_checkins: bool = True
    include_insights: bool = True
    start_date: date | None = None
    end_date: date | None = None

    @model_validator(mode="after")
    def valid_range(self):
        if self.start_date and self.end_date and self.start_date > self.end_date:
            raise ValueError("start_date must not be after end_date")
        if self.end_date and self.end_date > date.today():
            raise ValueError("end_date must not be in the future")
        return self
```

- [ ] **Step 4: Implement ownership-filtered collection and generators**

`ExportService.collect(user, request)` always returns account/profile/preferences
and conditionally returns protocols/compounds/dose logs, check-ins, and insights.
Every query includes `user_id == user.id`; date filters are inclusive.

Use `tempfile.SpooledTemporaryFile(max_size=8 * 1024 * 1024, mode="w+b")`.
Use stdlib `csv`, `json`, and `zipfile` for CSV ZIP; prefix formula-leading CSV
cells with a single quote. Use ReportLab 5.0.0 `SimpleDocTemplate`, tables, and
paragraphs for PDF, omitting empty optional sections and charts. Add
`reportlab==5.0.0` to requirements.

Return:

```python
@dataclass
class GeneratedExport:
    stream: BinaryIO
    filename: str
    media_type: str
```

No model, row, job, object key, or external storage call is permitted.

- [ ] **Step 5: Stream and close request-lifetime bytes**

The route creates the export and returns `StreamingResponse` over a generator
that reads 64 KiB chunks and closes the spooled file in `finally`. Set quoted
`Content-Disposition: attachment; filename="peppy-export-YYYY-MM-DD.ext"` and
`Cache-Control: no-store`.

- [ ] **Step 6: Run export, full backend, and dependency tests**

```bash
python -m pip install -r requirements.txt
pytest tests/test_data_export.py -v
pytest -q
```

Expected: valid PDF/ZIP output, no cross-user bytes, no formula injection, no
export table, and zero full-suite failures.

- [ ] **Step 7: Stage the checkpoint**

```bash
git add backend/app/api/schemas/export.py backend/app/services/export.py backend/app/api/routes/profile.py backend/requirements.txt backend/tests/test_data_export.py
git diff --cached --check
```

Suggested commit: `feat: stream secure account exports`.

---
### Task 8: Add Typed iOS Settings And Download Contracts

**Files:**
- Create: `ios/peppy/Core/Network/SettingsAPIModels.swift`
- Create: `ios/peppy/peppyTests/SettingsAPIContractTests.swift`
- Modify: `ios/peppy/Core/Network/APIClient.swift:3-181`
- Modify: `ios/peppy/Core/Network/Endpoint.swift:10-239`
- Modify: `ios/peppy/Core/Network/MockAPIClient.swift:3-64`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Tasks 2-7 HTTP contracts, `APIDateOnly`, `APIClientProtocol`, and `Endpoint.requestID`.
- Produces: typed settings requests/responses, `DownloadedFile`, authenticated download support, and mockable endpoint behavior.

- [ ] **Step 1: Write failing endpoint, encoding, decoding, and download tests**

Create `SettingsAPIContractTests.swift` and assert exact paths/methods, explicit
null encoding, snake-case keys, and a downloaded file returned by the mock:

```swift
func testSettingsEndpointsUseApprovedContracts() {
    XCTAssertEqual(Endpoint.getProfile.path, "/profile/onboarding")
    XCTAssertEqual(Endpoint.getProfile.method, .get)
    XCTAssertEqual(Endpoint.updateCurrentUser(.init(displayName: "Alex", timezone: nil)).method, .patch)
    XCTAssertEqual(Endpoint.changePassword(.init(currentPassword: "old-pass-1", newPassword: "new-pass-2")).path, "/auth/change-password")
    XCTAssertEqual(Endpoint.deleteAccount(.init(currentPassword: "old-pass-1")).method, .delete)
    XCTAssertEqual(Endpoint.createDataExport(.fixture).path, "/profile/export")
}

func testProfileUpdateEncodesNullForClearedOptionalSelections() throws {
    let request = ProfileUpdateRequest.fixture(secondaryGoal: nil, focusArea: nil)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
    XCTAssertTrue(json["secondary_goal"] is NSNull)
    XCTAssertTrue(json["focus_area"] is NSNull)
}

func testMockDownloadReturnsConfiguredFile() async throws {
    let api = MockAPIClient()
    let expected = DownloadedFile(url: URL(fileURLWithPath: "/tmp/export.pdf"), suggestedFilename: "peppy-export.pdf")
    api.setMockDownload(expected, for: .createDataExport(.fixture))
    XCTAssertEqual(try await api.download(.createDataExport(.fixture)), expected)
}
```

- [ ] **Step 2: Run the focused iOS tests and verify compile failures**

```bash
xcodebuild test -project ios/peppy/peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:peppyTests/SettingsAPIContractTests
```

Expected: compile failures for the new types and endpoint cases.

- [ ] **Step 3: Define focused settings models**

`SettingsAPIModels.swift` defines `AccountProfile`, `ProfileUpdateRequest`,
`UpdateCurrentUserRequest`, `DoseReminderPreference`, expanded
`NotificationPreferences`, `UpdateNotificationPreferencesRequest`,
`ChangePasswordRequest`, `DeleteAccountRequest`, `DataExportRequest`,
`DataExportFormat`, and `DownloadedFile`.

Use custom `encode(to:)` for `ProfileUpdateRequest` so `secondary_goal` and
`focus_area` encode explicit null. Use `APIDateOnly` for baseline/export dates.
Keep `DataExportRequest` booleans nonoptional and encode format values `pdf` or
`csv`.

- [ ] **Step 4: Extend endpoints and authenticated file downloads**

Add endpoint cases for `getProfile`, `updateProfile`, `updateCurrentUser`,
`changePassword`, `deleteAccount`, and `createDataExport`. Extend the protocol:

```swift
protocol APIClientProtocol {
    func execute<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func executeVoid(_ endpoint: Endpoint) async throws
    func download(_ endpoint: Endpoint) async throws -> DownloadedFile
}
```

Implement `download` with `URLSession.download(for:)`, the same bearer-token and
single-refresh behavior as JSON requests, 2xx validation, `Content-Disposition`
filename parsing, and no in-memory `Data` conversion. Extend `MockAPIClient` with
method-qualified `mockDownloads` and request logging.

- [ ] **Step 5: Run focused tests and a build**

```bash
xcodebuild test -project ios/peppy/peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:peppyTests/SettingsAPIContractTests
xcodebuild -project ios/peppy/peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: focused tests and build succeed.

- [ ] **Step 6: Stage the checkpoint**

```bash
git add ios/peppy/Core/Network ios/peppy/peppyTests/SettingsAPIContractTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
git diff --cached --check
```

Suggested commit: `feat: add iOS settings API contracts`.

---

### Task 9: Build The Settings Store, Navigation, And More Root

**Files:**
- Create: `ios/peppy/Features/Settings/Models/SettingsModels.swift`
- Create: `ios/peppy/Features/Settings/Stores/SettingsStore.swift`
- Create: `ios/peppy/Features/Settings/Views/SettingsComponents.swift`
- Create: `ios/peppy/Features/Settings/Views/SettingsRootView.swift`
- Create: `ios/peppy/peppyTests/SettingsStoreTests.swift`
- Create: `ios/peppy/peppyTests/SettingsNavigationTests.swift`
- Modify: `ios/peppy/App/Dependencies.swift:3-168`
- Modify: `ios/peppy/App/MainTabView.swift:21-171`
- Modify: `ios/peppy/App/AppFlowCoordinator.swift:26-181`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Task 8 models/endpoints, `AppState.currentUser`, `APIClientProtocol`, and existing Peppy design tokens.
- Produces: `SettingsStore`, `SettingsRoute`, reusable Figma row/section components, and the real More tab root.

- [ ] **Step 1: Write failing cached-first, reset, and route tests**

```swift
@MainActor
func testRefreshFailurePreservesConfirmedSettings() async {
    let api = MockAPIClient()
    let store = SettingsStore(api: api, initialUser: .fixture, cachedProfile: .fixture)
    api.setMockError(.serverError, for: .getProfile)
    await store.refresh()
    XCTAssertEqual(store.profile, .fixture)
    XCTAssertEqual(store.refreshError, .serverError)
}

@MainActor
func testMoreRowsContainOnlyReleaseDestinations() {
    XCTAssertEqual(SettingsRootViewModel.releaseRows.map(\.route), [
        .notifications, .dataExport, .security, .help, .about, .legal,
    ])
}
```

- [ ] **Step 2: Run tests and verify missing-type failures**

Run the two new test classes with `xcodebuild test`; expect compile failures.

- [ ] **Step 3: Implement store and route boundaries**

Define:

```swift
enum SettingsRoute: Hashable {
    case profile, notifications, dataExport, security, help
    case about, legal
}

@MainActor @Observable
final class SettingsStore {
    private(set) var user: User?
    private(set) var profile: AccountProfile?
    private(set) var notificationPreferences: NotificationPreferences?
    var isRefreshing = false
    var refreshError: APIError?

    func refresh() async
    func updateProfile(user: UpdateCurrentUserRequest, profile: ProfileUpdateRequest) async throws
    func updateNotifications(_ request: UpdateNotificationPreferencesRequest) async throws
    func resetSession()
}
```

`refresh` loads profile and preferences concurrently, retains each last confirmed
value on an individual failure, and treats a profile 404 as an empty editable
profile. Mutations replace cache only with server responses.

- [ ] **Step 4: Replace the placeholder with the exact release root**

Build `SettingsRootView` with the Figma profile card, My Data and Account & App
groups, dynamic `CFBundleShortVersionString`/`CFBundleVersion`, and Log Out.
Render only Notifications/Data Export and Security/Help/About/Legal. Use
`NavigationStack(path:)` inside the existing tab so the tab bar remains visible.
Register `SettingsStore` in live/mock dependencies and reset it through
`resetSessionData`.

- [ ] **Step 5: Run focused tests and build**

```bash
xcodebuild test -project ios/peppy/peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:peppyTests/SettingsStoreTests -only-testing:peppyTests/SettingsNavigationTests
xcodebuild -project ios/peppy/peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 6: Stage the checkpoint**

Stage the new Settings foundation, three modified App files, tests, and project
file; run `git diff --cached --check`. Suggested commit:
`feat: replace More placeholder with settings root`.

---

### Task 10: Implement Account-Backed Profile Editing

**Files:**
- Create: `ios/peppy/Features/Settings/ViewModels/ProfileSettingsViewModel.swift`
- Create: `ios/peppy/Features/Settings/Views/ProfileSettingsView.swift`
- Create: `ios/peppy/Features/Settings/Views/ProfileEditorSheets.swift`
- Create: `ios/peppy/peppyTests/ProfileSettingsViewModelTests.swift`
- Modify: `ios/peppy/Features/Onboarding/Models/OnboardingDraft.swift:3-131`
- Modify: `ios/peppy/Core/Storage/WeightUnitPreferenceStore.swift:22-50`
- Modify: `ios/peppy/App/Dependencies.swift`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Task 9 store, existing `HeightUnit`, `WeightUnit`, `OnboardingGoal`, and Figma Profile frame.
- Produces: `ProfileDraft`, shared onboarding-goal selection, unit conversion helpers, staged validation, save/discard behavior, and account-aware measurement preference propagation.

- [ ] **Step 1: Write failing draft, conversion, validation, and save tests**

Cover read-only email, required primary goal, optional clearing, feet/inches and
pounds conversion, unchanged-save disabling, retained edits on failure, and
discard confirmation. Assert successful save calls both update endpoints and
updates `WeightUnitPreferences` only after both succeed.

- [ ] **Step 2: Run `ProfileSettingsViewModelTests` and verify failures**

Use the focused `xcodebuild test` form from Task 9; expect missing-type failures.

- [ ] **Step 3: Centralize profile options and conversions**

Reuse `OnboardingGoal.allCases` for primary goal, secondary goal, and focus
area. Add a single failable initializer that maps every existing
`OnboardingGoal.serverValue` back to its enum case, and use that mapping in the
settings API model. Do not introduce a Settings-only goal or focus enum.

Add shared height conversion/formatting next to existing weight helpers. Make
`WeightUnitPreferences` user-aware (`activate(userID:serverUnit:)`,
`resetSession()`) so one account's local seed cannot leak into another account.

- [ ] **Step 4: Implement the exact Profile frame and staged save**

Match Figma Account Information, Preferences, Baseline Information, Onboarding
Goals, Save Changes, and footer. Remove the email Edit button and expose a
read-only accessibility value. Present edit sheets/pickers for name, baseline
values, and selections. `hasUnsavedChanges` drives Save and an interactive-dismiss
confirmation. Preserve the draft and inline error on either API failure.

- [ ] **Step 5: Run focused tests, existing check-in preference tests, and build**

```bash
xcodebuild test -project ios/peppy/peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:peppyTests/ProfileSettingsViewModelTests -only-testing:peppyTests/CheckinViewModelTests
xcodebuild -project ios/peppy/peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 6: Stage the checkpoint**

Stage only Profile files, preference/model changes, tests, dependencies, and
project entries; run the cached diff check. Suggested commit:
`feat: add account-backed profile settings`.

---

### Task 11: Implement Local Reminders And APNs Registration

**Files:**
- Create: `ios/peppy/Core/Notifications/DoseScheduleCalculator.swift`
- Create: `ios/peppy/Core/Notifications/LocalNotificationScheduler.swift`
- Create: `ios/peppy/Core/Notifications/PushRegistrationCoordinator.swift`
- Create: `ios/peppy/App/PeppyAppDelegate.swift`
- Create: `ios/peppy/Features/Settings/ViewModels/NotificationSettingsViewModel.swift`
- Create: `ios/peppy/Features/Settings/Views/NotificationSettingsView.swift`
- Create: `ios/peppy/Features/Settings/Views/ReminderSetupSheets.swift`
- Create: `ios/peppy/peppyTests/NotificationSettingsTests.swift`
- Modify: `ios/peppy/Core/Permissions/NotificationPermissionService.swift:3-30`
- Modify: `ios/peppy/Features/Protocols/ViewModels/ProtocolDetailViewModel.swift:258-315`
- Modify: `ios/peppy/App/PeppyApp.swift:3-13`
- Modify: `ios/peppy/App/Dependencies.swift`
- Modify: `ios/peppy/peppy.entitlements`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Task 5 server preferences, Task 8 models, active protocol store, and `UNUserNotificationCenter`.
- Produces: deterministic recurrence dates, idempotent local reconciliation, permission status/open-settings actions, APNs token relay/registration, and the exact Notifications UI.

- [ ] **Step 1: Write failing calculator, privacy, permission, and reconciliation tests**

Test all supported existing frequencies (`daily`, `every other day`, `twice
weekly`, `weekly`, `every 10 days`, `biweekly`, `monthly`), start-date anchoring,
60-dose request ceiling, quiet-hour check-in suppression, dose bypass, stable
identifiers, generic/detailed bodies, denied permission preservation, and obsolete
compound cleanup. Test APNs registration reuses the returned server device ID.

- [ ] **Step 2: Run focused tests and verify missing-type failures**

Run `peppyTests/NotificationSettingsTests`; expect compile failures.

- [ ] **Step 3: Extract recurrence and implement the scheduler**

Move interval parsing from `ProtocolDetailViewModel` into
`DoseScheduleCalculator.intervalDays(for:)`. Generate future dates from protocol
start, not the last log. Define:

```swift
protocol LocalNotificationScheduling {
    func reconcile(preferences: NotificationPreferences, activeProtocol: Protocol?) async throws
    func removeSettingsRequests() async
}
```

Use identifiers `peppy.settings.checkin` and
`peppy.settings.dose.<compound-id>.<yyyyMMdd>`. Remove only the
`peppy.settings.` namespace, then add at most 60 future dose requests plus the
single repeating check-in request. Generic content is default; details use the
saved opt-in. Dose ignores quiet hours; check-in inside quiet hours is omitted.

- [ ] **Step 4: Extend permission and push registration boundaries**

Add `authorizationStatus()` and `openSystemSettings()` to the permission service.
`PeppyAppDelegate` converts APNs bytes to lowercase hex and posts them to an
injected `PushRegistrationCoordinator`; never log the token. After authorization,
call `registerForRemoteNotifications`. Register with the backend only while signed
in; store the returned device record ID for best-effort unregister on logout.
Enable Push Notifications through the entitlement/capability settings.

- [ ] **Step 5: Build the exact screen and setup sheets**

Match Figma toggles, Quiet Hours, dynamic preview, and Save Changes. Dose enable
shows active compounds and per-compound time. No active protocol shows the
Protocols action. Check-in enable shows one time. Ask system permission only after
valid setup; after authorization offer Show Reminder Details. A denied status
keeps the account draft and shows Open iOS Settings. Save backend first, then
reconcile local requests; show a repair action if local scheduling fails.

- [ ] **Step 6: Reconcile on lifecycle/protocol/timezone changes**

Trigger reconciliation after save, protocol revision, app activation, and
`NSSystemTimeZoneDidChange`. Update `users.timezone` when the IANA identifier
changes. Remove local requests and unregister the APNs record during session reset.

- [ ] **Step 7: Run focused tests, permission tests, and build**

Run `NotificationSettingsTests`, `PermissionServiceTests`, and
`ProtocolDetailViewModelTests`, then the generic simulator build. Expect all pass.

- [ ] **Step 8: Stage the checkpoint**

Stage notification/app files, entitlement/project changes, and tests; run the
cached diff check. Suggested commit: `feat: add reminders and APNs registration`.

---

### Task 12: Add The Optional Face ID App Lock

**Files:**
- Create: `ios/peppy/Core/Security/AppLockService.swift`
- Create: `ios/peppy/Core/Security/AppLockPreferences.swift`
- Create: `ios/peppy/Core/Security/AppLockCoordinator.swift`
- Create: `ios/peppy/Features/Settings/Views/AppLockCoverView.swift`
- Create: `ios/peppy/peppyTests/AppLockCoordinatorTests.swift`
- Modify: `ios/peppy/App/Dependencies.swift`
- Modify: `ios/peppy/App/RootView.swift:3-60`
- Modify: `ios/peppy/App/PeppyApp.swift:7-13`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `scenePhase`, LocalAuthentication, current user ID, and `AppFlowCoordinator.logout()`.
- Produces: device-local opt-in, immediate privacy cover, cold-launch/five-minute gating, and sign-in fallback.

- [ ] **Step 1: Write failing lifecycle tests with an injected clock/authenticator**

Cover disabled launch, enabled cold launch, four-minute resume without prompt,
five-minute resume with prompt, immediate background cover, success, cancel,
unavailable Face ID, and Use Password Instead clearing the session.

- [ ] **Step 2: Run `AppLockCoordinatorTests` and verify compile failures**

- [ ] **Step 3: Implement injectable security boundaries**

```swift
protocol AppLockAuthenticating {
    func availability() -> AppLockAvailability
    func authenticate(reason: String) async -> Bool
}

@MainActor @Observable
final class AppLockCoordinator {
    static let timeout: TimeInterval = 300
    private(set) var isPrivacyCoverVisible = false
    private(set) var requiresUnlock = false
    func authenticatedSessionBecameVisible(userID: UUID) async
    func scenePhaseChanged(_ phase: ScenePhase) async
    func usePasswordInstead()
}
```

Persist the enable flag per user in `UserDefaults`. Require a successful Face ID
check before turning it on. Never fall back to device passcode under the Face ID
toggle. `usePasswordInstead` invokes normal logout rather than collecting a local
password.

- [ ] **Step 4: Integrate the cover before sensitive content is visible**

Overlay `AppLockCoverView` above `RootView` dashboard content and respond to
`scenePhase`. Background always shows the cover for app-switcher snapshots.
Foreground removes it without auth when elapsed time is under 300 seconds;
otherwise authenticate. Add generated Info.plist key
`NSFaceIDUsageDescription = "Use Face ID to protect your Peppy health information."`.

- [ ] **Step 5: Run focused tests, coordinator tests, and build**

Run `AppLockCoordinatorTests`, `AppFlowCoordinatorTests`, and the generic simulator
build. Expected: all pass.

- [ ] **Step 6: Stage the checkpoint**

Stage security files, App integration, dependencies, tests, and project settings;
run the cached diff check. Suggested commit: `feat: add optional Face ID app lock`.

---

### Task 13: Build Protected Export Downloading And Sharing

**Files:**
- Create: `ios/peppy/Core/Export/ExportFileService.swift`
- Create: `ios/peppy/Features/Settings/ViewModels/DataExportViewModel.swift`
- Create: `ios/peppy/Features/Settings/Views/DataExportView.swift`
- Create: `ios/peppy/Features/Settings/Views/ActivityView.swift`
- Create: `ios/peppy/peppyTests/DataExportViewModelTests.swift`
- Modify: `ios/peppy/App/Dependencies.swift`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Task 8 `download`, backend export endpoint, FileManager, and `UIActivityViewController`.
- Produces: protected temporary export lifecycle, progress/cancel/error state, and exact Data Export UI.

- [ ] **Step 1: Write failing selection, request, protection, and cleanup tests**

Test default selectors, account-only request, presets/custom validation, PDF/CSV
mapping, retained selections on failure, cancellation cleanup, stale-file launch
cleanup, `.complete` file protection, backup exclusion, and share completion cleanup.

- [ ] **Step 2: Run `DataExportViewModelTests` and verify failures**

- [ ] **Step 3: Implement protected transient files**

Define `ExportFileServicing` with `prepare(_ downloaded:)`, `remove(_:)`, and
`removeStaleFiles()`. Move the URLSession file into a unique
`tmp/peppy-exports/` URL, apply `.protectionKey: .complete`, set
`isExcludedFromBackup`, validate the extension from requested format, and delete
partial/stale files. Never place exports in Documents or caches.

- [ ] **Step 4: Implement the exact Data Export flow**

Match the Figma categories, format radio rows, date row, warning, and Create
Export. Omit Labs/Wearables. Keep account/profile/preferences implicit and allow
all visible categories off. Date presets are All Time, 30 Days, 90 Days, Custom.
Create calls `api.download`, protects the result, and presents `ActivityView`.
Cancel/error leaves selections intact; share completion/cancel removes the file.

- [ ] **Step 5: Run focused tests and build**

Run `DataExportViewModelTests`, `SettingsAPIContractTests`, and the generic
simulator build. Expected: all pass.

- [ ] **Step 6: Stage the checkpoint**

Stage export files, dependencies, tests, and project entries; run the cached diff
check. Suggested commit: `feat: add secure iOS data export`.

---

### Task 14: Complete Security, Logout, Help, About, And Legal UI

**Files:**
- Create: `ios/peppy/Core/Browser/InAppBrowserView.swift`
- Create: `ios/peppy/Features/Settings/ViewModels/AccountSecurityViewModel.swift`
- Create: `ios/peppy/Features/Settings/Views/SecurityPrivacyView.swift`
- Create: `ios/peppy/Features/Settings/Views/ChangePasswordView.swift`
- Create: `ios/peppy/Features/Settings/Views/DeleteAccountView.swift`
- Create: `ios/peppy/Features/Settings/Views/HelpAboutView.swift`
- Create: `ios/peppy/Features/Settings/Views/MedicalDisclaimerView.swift`
- Create: `ios/peppy/peppyTests/AccountSecurityViewModelTests.swift`
- Create: `ios/peppy/peppyTests/HelpAboutTests.swift`
- Modify: `ios/peppy/App/AppFlowCoordinator.swift:134-181`
- Modify: `ios/peppy/Features/Settings/Views/SettingsRootView.swift`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Tasks 3-4 security endpoints, Task 11 push unregister, Task 12 lock preference, `SFSafariViewController`, and approved URLs/copy.
- Produces: password change, two-step deletion, best-effort logout cleanup, allow-listed web browsing, native disclaimer, and exact Security/Help frames.

- [ ] **Step 1: Write failing account-action and link tests**

Test password mismatch/client validation, server failure retaining the session,
successful password change logging out, deletion requiring both password and
final confirmation, deletion failure preserving state, successful deletion local
cleanup, logout despite unregister failure, and exact allow-listed URLs.

- [ ] **Step 2: Run the two focused test classes and verify failures**

- [ ] **Step 3: Implement account actions without optimistic destruction**

`AccountSecurityViewModel` validates fields locally, calls the server, and invokes
one `finishSignedOutSession()` cleanup only after password change/deletion success.
Normal logout attempts APNs unregister and `/auth/logout`, but always performs
local cleanup. Cleanup removes tokens, Settings/check-in/protocol/insight caches,
local Settings notifications, app-lock state, and temporary exports.

- [ ] **Step 4: Build the exact Security & Privacy frame**

Render Face ID and Change Password; omit Active Sessions. Render Privacy Policy
and How We Protect Your Data; omit Data Permissions. Delete Account opens password
reauth, then a separate `Delete Permanently` confirmation. Never clear local data
before the server confirms deletion.

- [ ] **Step 5: Build Help & About and allow-listed browsing**

Use `SFSafariViewController` for only:

```swift
help:    https://get-peppy.com/help
contact: https://get-peppy.com/contact
bug:     https://get-peppy.com/feedback/bug
feature: https://get-peppy.com/feedback/feature
about:   https://get-peppy.com/about
terms:   https://get-peppy.com/terms
privacy: https://get-peppy.com/privacy
```

Match the Figma Help & About frame and dynamic version/year. Use the spec's exact
native medical disclaimer. Standard Safari controls provide retry and Open in
Safari; dismiss returns to the unchanged native screen.

- [ ] **Step 6: Run focused/navigation/coordinator tests and build**

Run `AccountSecurityViewModelTests`, `HelpAboutTests`,
`SettingsNavigationTests`, and `AppFlowCoordinatorTests`, then build. Expected:
all pass.

- [ ] **Step 7: Stage the checkpoint**

Stage browser/security/help/root/coordinator files, tests, and project entries;
run the cached diff check. Suggested commit:
`feat: complete settings security and support flows`.

---

### Task 15: Add The Web Help Center And Correct Public Privacy Copy

**Files:**
- Create: `web/src/lib/help-content.ts`
- Create: `web/src/components/HelpSearch.tsx`
- Create: `web/src/app/help/page.tsx`
- Create: `web/scripts/settings-web-smoke.mjs`
- Modify: `web/src/app/privacy/page.tsx:1-100`
- Modify: `web/src/app/about/page.tsx:12-16`
- Modify: `web/src/app/waitlist/page.tsx`
- Modify: `web/src/components/Sections.tsx:460-485`
- Modify: `web/src/app/sitemap.ts:3-43`
- Modify: `web/package.json:5-12`

**Interfaces:**
- Consumes: existing `PageShell`, Peppy web tokens, current support routes, and Playwright.
- Produces: searchable/categorized `/help`, corrected generic AI disclosure, accurate HIPAA-eligible wording, and smoke coverage for all app destinations.

Before Step 1, read `web/AGENTS.md` and the relevant local Next.js App Router,
server/client component, metadata, and testing documentation under
`web/node_modules/next/dist/docs/`. Record any constraint that changes the steps
below in the task checklist before editing source files.

- [ ] **Step 1: Write the failing Playwright smoke script**

`settings-web-smoke.mjs` opens `/help`, asserts a `Help Center` heading, filters
for `notifications`, searches `delete account`, expands the matching answer, and
checks 200/title responses for About, Contact, bug, feature, Terms, and Privacy.
It also asserts Privacy contains `third-party AI processing service`, contains no
AI provider name, contains no BAA claim, and contains no `AES-256`/`TLS 1.3`
claim.

Add `"test:settings": "node scripts/settings-web-smoke.mjs"` to `package.json`.

- [ ] **Step 2: Start Next.js and verify the smoke test fails**

```bash
npm run dev
URL=http://localhost:3000 npm run test:settings
```

Expected: failure because `/help` and corrected privacy copy do not exist. Keep
the dev server running in its own terminal for the following web steps.

- [ ] **Step 3: Add structured FAQ data and accessible search**

`help-content.ts` exports typed entries in Accounts, Protocols & Doses,
Check-ins, Insights, Notifications, Data Export & Privacy, and Troubleshooting.
Include exact answers for notification privacy, denied permissions, password
change sign-out, immediate active-system deletion, exports, and medical-advice
limits. `HelpSearch.tsx` is a client component with a labelled search field,
keyboard-operable category tabs, result count, `<details>` answers, and a no-results
state. It performs case-insensitive search across question, answer, and keywords.

- [ ] **Step 4: Build `/help` in the existing site system**

Use `PageShell`, a compact literal `Help Center` H1, supporting copy, unframed
search/results layout, and mobile-first spacing. Do not create a marketing hero,
decorative illustration, nested cards, or new palette. Add `/help` to sitemap with
monthly change frequency and priority 0.7.

- [ ] **Step 5: Replace unsupported public claims everywhere**

Update Privacy's date and sections to disclose relevant health/wellness data and
free-text notes processed by a `third-party AI processing service`, purpose,
identifier exclusion, informational output, and user controls. Use:

> Peppy uses cloud infrastructure services that support HIPAA-eligible
> configurations. This does not mean Peppy is HIPAA compliant, and Peppy does not
> currently represent that it has Business Associate Agreements covering the
> service.

State that deletion removes active-system data immediately after confirmation
and that limited backup/provider retention follows disclosed operational terms.
Remove unverified AES-256, TLS 1.3, BAA, and universal immediate-backup-deletion
claims from Privacy, About, Waitlist, and home privacy chips. Do not name the AI
provider in public files.

- [ ] **Step 6: Verify web behavior and production build**

```bash
URL=http://localhost:3000 npm run test:settings
npm run lint
npm run type-check
npm run build
```

Expected: smoke script, lint, type check, and production build all pass.

- [ ] **Step 7: Stage the checkpoint**

```bash
git add web/src/lib/help-content.ts web/src/components/HelpSearch.tsx web/src/app/help/page.tsx web/scripts/settings-web-smoke.mjs web/src/app/privacy/page.tsx web/src/app/about/page.tsx web/src/app/waitlist/page.tsx web/src/components/Sections.tsx web/src/app/sitemap.ts web/package.json
git diff --cached --check
```

Suggested commit: `feat: add help center and privacy disclosure`.

---

### Task 16: Run Integrated Settings Verification And Release Gates

**Files:**
- Create: `ios/peppy/docs/superpowers/plans/2026-07-20-ios-settings-manual-qa.md`
- Modify only if verification exposes a defect: files owned by Tasks 1-15

**Interfaces:**
- Consumes: all previous tasks and approved Figma references.
- Produces: verified backend/iOS/web suites, exact-screen comparison evidence, physical-device security/push checks, and an explicit release-gate record.

- [ ] **Step 1: Run clean automated verification**

Run from `backend/`:

```bash
pytest -q
ruff check app tests
```

Run from `web/`:

```bash
npm run lint
npm run type-check
npm run build
```

Run from the repository root:

```bash
xcodebuild test -project ios/peppy/peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
xcodebuild -project ios/peppy/peppy.xcodeproj -scheme peppy -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: every command exits zero. Fix any failure with the systematic-debugging
skill, rerun the focused failing command, then rerun this complete block.

- [ ] **Step 2: Exercise end-to-end API security cases**

Using two test accounts, verify cross-user profile/reminder/export access is
impossible, old tokens fail after password change, deletion removes every
inventoried row, deleted tokens fail, CSV output cannot execute spreadsheet
formulas, and no export artifact remains after response completion.

- [ ] **Step 3: Perform simulator interaction and accessibility QA**

Exercise every visible More row; cached/offline/error/retry states; profile unit
conversion and unsaved discard; denied notification permission; reminder setup;
generic/detailed preview; quiet hours; export cancellation/share cleanup; Face ID
mock states; password/deletion failure and success; support links. Test default,
AX3, and accessibility Dynamic Type plus VoiceOver focus order and 44-point taps.

- [ ] **Step 4: Perform exact visual comparison**

Capture each implemented screen at the reference viewport. For each state, place
the Figma raster and simulator screenshot into one comparison input, inspect
header positions, spacing, type, icon size, border/radius, colors, bottom tab bar,
safe areas, and text fit, fix differences, then capture and compare again. Record
the final screenshot paths and remaining intentional differences (read-only email,
omitted future rows, generic preview) in the manual QA document.

- [ ] **Step 5: Verify physical-device-only behavior**

On a signed development build, verify APNs registration/delivery, invalid-token
cleanup, generic and opted-in detailed payloads, dose/check-in delivery across
timezone changes, Face ID cold launch and five-minute resume, immediate app
switcher cover, protected share file cleanup, and Open iOS Settings behavior.

- [ ] **Step 6: Audit operational/legal release blockers**

Record evidence for APNs production credentials, database/storage encryption and
transport claims, backup retention, deletion behavior, AI-service retention and
training terms, and legal approval. If evidence is absent, mark the corresponding
gate blocked and do not publish stronger copy. Confirm every live URL returns 200
on mobile.

- [ ] **Step 7: Invoke completion verification and stage the QA record**

Use `superpowers:verification-before-completion`, paste the fresh command results
and physical-device outcomes into the QA document, then run:

```bash
git add ios/peppy/docs/superpowers/plans/2026-07-20-ios-settings-manual-qa.md
git diff --cached --check
git status --short
```

Suggested commit: `test: verify iOS settings release flow`.

---
## Dependency Order And Review Gates

1. Task 1 is the persistence foundation.
2. Tasks 2-4 may proceed after Task 1; review each security contract separately.
3. Task 5 follows Task 1; Task 6 follows Task 5. Task 7 follows Task 1 and can run independently of Tasks 2-6.
4. Task 8 begins after backend request/response names are stable.
5. Task 9 follows Task 8. Tasks 10-14 follow Task 9 and their corresponding backend task.
6. Task 15 is independently reviewable after the approved wording is locked.
7. Task 16 runs only after Tasks 1-15 pass their focused checkpoints.

At every gate, review spec compliance first, then behavior/tests, then visual
fidelity for UI tasks. Do not combine unrelated cleanup with these checkpoints.
