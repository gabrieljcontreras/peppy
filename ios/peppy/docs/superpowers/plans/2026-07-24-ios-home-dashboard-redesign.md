# iOS Home Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the iOS Home tab so it matches the Figma `dashboard-with-insight` reference: a personalized greeting, a real next-dose card, a check-in card, a weight-trend chart, wearable stat tiles, an insight card with a confidence badge, and a cross-feature recent-activity feed.

**Architecture:** Additive backend fields (protocol start date, insight confidence, a merged recent-activity list) feed an extended `DashboardSummary`. Next-dose-due math is extracted from `ProtocolDetailViewModel` into a shared, reusable place instead of being duplicated for the dashboard. New SwiftUI card components are added to the Dashboard feature; `DashboardView` is rewritten to assemble them.

**Tech Stack:** FastAPI, SQLAlchemy, Pydantic, pytest (backend); Swift 6, SwiftUI, Observation, Swift Charts, XCTest, URLSession-backed `APIClientProtocol` (iOS).

## Global Constraints

- Design reference: `~/.claude/projects/-Users-gabri-peppy/figma-frames/dashboard-with-insight.png`. Spec: `ios/peppy/docs/superpowers/specs/2026-07-24-ios-home-dashboard-redesign-design.md`.
- All backend schema changes are additive (new `Optional`/defaulted fields only) — no existing field is removed, renamed, or retyped.
- Greeting text is `"Good <morning/afternoon/evening>, <first name>"`, matching the Figma frame exactly (not a static "Hello" — this was explicitly confirmed with the user). Morning = hour 5–11, afternoon = 12–16, evening = everything else. Falls back to "there" when no display name is set.
- Wearable stat tiles and any activity-feed rows for `wearable_synced`/`lab_added` are expected to rarely appear today, because no in-app UI exists yet to connect a wearable or add a lab result. This is intentional and out of scope to fix here.
- Next-dose-due math must not be duplicated: `ProtocolDetailViewModel` and the new dashboard code share one implementation.
- **pbxproj registration:** `ios/peppy/peppy.xcodeproj` does not use filesystem-synchronized groups. Any new Swift file (this plan adds exactly one: `Features/Dashboard/Views/DashboardDataViews.swift`) must be manually registered: add a `PBXBuildFile` entry and a `PBXFileReference` entry, add the file-reference ID to its group's `children` list, and add the build-file ID to the `peppy` target's `PBXSourcesBuildPhase` `files` list. Follow the exact shape of an existing entry (e.g. search the file for `DashboardCards.swift` to see all four places it appears) and use a fresh 24-character uppercase-hex ID not already present (`grep -c <candidate-id>` should return 0 before you use it). Verify afterward with `grep -n "DashboardDataViews.swift" peppy.xcodeproj/project.pbxproj` — expect exactly 4 matches. Everywhere else in this plan, code is added to *existing* files, so this only applies to that one task.
- Backend virtualenv is `backend/venv` (not `.venv`): run tests with `cd backend && venv/bin/python -m pytest ...`.
- iOS builds/tests need `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` prefixed (the active developer directory is CommandLineTools) and must target the `iPhone 17 Pro` simulator (the only iPhone 17-family simulator on this machine), e.g.:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/DashboardViewModelTests test`
- No simulator UI driving/screenshotting by the agent (credit cost) — the final task hands off a manual QA checklist instead of visually verifying in-simulator.

---

## File Structure

Backend (all modifications, no new files):
- `backend/app/api/schemas/dashboard.py` — add `start_date`, `confidence`, `DashboardActivityItem`, `recent_activity`.
- `backend/app/services/dashboard.py` — populate the new fields; new `_recent_activity` merge query.
- `backend/tests/test_dashboard_service.py`, `backend/tests/test_dashboard_routes.py` — coverage for the above.

iOS — the plan deliberately keeps new-file count to **one** (`DashboardDataViews.swift`) given how fragile/manual `project.pbxproj` editing is in this repo; several pieces that would otherwise get their own file are instead added as focused extensions on existing, already-registered files:

- `ios/peppy/Core/Notifications/DoseScheduleCalculator.swift` — modify: extract `nextDueDate(...)`, the shared per-compound due-date calculation.
- `ios/peppy/Features/Protocols/Models/ProtocolModels.swift` — modify: add `Protocol.nextDueCompound(doseLogs:)`, which both Protocol Detail and the Dashboard use.
- `ios/peppy/Features/Protocols/ViewModels/ProtocolDetailViewModel.swift` — modify: use the shared calculator instead of its private copy.
- `ios/peppy/Core/Network/Endpoint.swift` — modify: add `getLatestWearableData(provider:)`; fix `requestID` to disambiguate by query items.
- `ios/peppy/Core/Network/APIModels.swift` — modify: add `WearableDataSnapshot`.
- `ios/peppy/Features/Dashboard/Models/DashboardModels.swift` — modify: add `startDate`, `confidence`, `DashboardActivityItem`, `recentActivity`, `DashboardWearableTiles`; update mock fixtures.
- `ios/peppy/Features/Dashboard/ViewModels/DashboardViewModel.swift` — modify: greeting, next-dose, wearable-tiles, activity wiring.
- `ios/peppy/Features/Dashboard/Views/DashboardCards.swift` — modify: restyle `DashboardProtocolCard`/`DashboardTodayCard`; add `DashboardNextDoseCard`, `DashboardInsightCard`.
- `ios/peppy/Features/Dashboard/Views/DashboardDataViews.swift` — **new**: `DashboardWeightTrendCard`, `DashboardWearableTilesRow`, `DashboardActivityFeed`.
- `ios/peppy/Features/Dashboard/Views/DashboardView.swift` — modify: rewrite body to assemble the full screen.
- `ios/peppy/peppyTests/ProtocolStoreTests.swift` — modify: add `nextDueCompound` coverage (reuses its existing `ProtocolModel.fixture`/`Compound.fixture`, no new test file).
- `ios/peppy/peppyTests/DashboardViewModelTests.swift` — modify: add greeting/next-dose/wearable/activity coverage.

---

### Task 1: Backend — protocol start date on the dashboard summary

**Files:**
- Modify: `backend/app/api/schemas/dashboard.py`
- Modify: `backend/app/services/dashboard.py`
- Test: `backend/tests/test_dashboard_service.py`

**Interfaces:**
- Produces: `DashboardProtocolSummary.start_date: Optional[date]` (JSON key `start_date`), populated from `Protocol.start_date` when a protocol exists, else `None`.

- [x] **Step 1: Write the failing test**

Add to `backend/tests/test_dashboard_service.py`:

```python
async def test_dashboard_summary_includes_protocol_start_date(db_session, user):
    await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["protocol"]["start_date"] == date.today()


async def test_dashboard_summary_start_date_is_none_without_protocol(db_session, user):
    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["protocol"]["start_date"] is None
```

- [x] **Step 2: Run tests to verify they fail**

Run: `cd backend && venv/bin/python -m pytest tests/test_dashboard_service.py -k start_date -q`
Expected: FAIL with `KeyError: 'start_date'`.

- [x] **Step 3: Implement**

In `backend/app/api/schemas/dashboard.py`, update `DashboardProtocolSummary`:

```python
class DashboardProtocolSummary(BaseModel):
    id: Optional[UUID]
    status: str
    title: str
    compounds: list[str]
    start_date: Optional[date] = None
```

In `backend/app/services/dashboard.py`, update `_protocol_summary`:

```python
def _protocol_summary(self, protocol: Protocol | None) -> dict[str, Any]:
    if protocol is None:
        return {
            "id": None,
            "status": "missing",
            "title": "Create your protocol",
            "compounds": [],
            "start_date": None,
        }
    return {
        "id": protocol.id,
        "status": protocol.setup_status,
        "title": protocol.name,
        "compounds": [compound.name for compound in protocol.compounds],
        "start_date": protocol.start_date,
    }
```

- [x] **Step 4: Run tests to verify they pass**

Run: `cd backend && venv/bin/python -m pytest tests/test_dashboard_service.py -q`
Expected: PASS (all tests in the file, including the two new ones).

- [x] **Step 5: Commit**

```bash
git add backend/app/api/schemas/dashboard.py backend/app/services/dashboard.py backend/tests/test_dashboard_service.py
git commit -m "feat: add protocol start date to dashboard summary"
```

---

### Task 2: Backend — insight confidence on the dashboard summary

**Files:**
- Modify: `backend/app/api/schemas/dashboard.py`
- Modify: `backend/app/services/dashboard.py`
- Test: `backend/tests/test_dashboard_service.py`

**Interfaces:**
- Consumes: `Insight.confidence: float` (existing model field).
- Produces: `DashboardInsightSummary.confidence: Optional[float]` (JSON key `confidence`) — the real insight's confidence when one exists, `None` for both empty-state branches.

- [x] **Step 1: Write the failing test**

Add to `backend/tests/test_dashboard_service.py` (add `from app.models.insight import Insight, InsightSeverity, InsightType` to the imports at the top of the file):

```python
async def test_dashboard_summary_includes_insight_confidence(db_session, user):
    await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )
    db_session.add(
        Insight(
            user_id=user.id,
            type=InsightType.TREND,
            severity=InsightSeverity.INFO,
            title="Your weight trend is accelerating",
            description="Your rate of loss increased over the past 7 days.",
            explanation="Computed from your last 10 check-ins.",
            confidence=0.82,
        )
    )
    await db_session.flush()

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["insight"]["confidence"] == 0.82


async def test_dashboard_summary_confidence_is_none_for_empty_insight_state(db_session, user):
    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["insight"]["confidence"] is None
```

- [x] **Step 2: Run tests to verify they fail**

Run: `cd backend && venv/bin/python -m pytest tests/test_dashboard_service.py -k confidence -q`
Expected: FAIL with `KeyError: 'confidence'`.

- [x] **Step 3: Implement**

In `backend/app/api/schemas/dashboard.py`, update `DashboardInsightSummary`:

```python
class DashboardInsightSummary(BaseModel):
    id: Optional[UUID] = None
    title: Optional[str] = None
    severity: Optional[str] = None
    empty_message: Optional[str] = None
    confidence: Optional[float] = None
```

In `backend/app/services/dashboard.py`, update `_insight_summary`:

```python
def _insight_summary(self, insight: Insight | None, checkin_count: int) -> dict[str, Any]:
    if insight:
        severity = insight.severity.value if hasattr(insight.severity, "value") else str(insight.severity)
        return {
            "id": insight.id,
            "title": insight.title,
            "severity": severity,
            "empty_message": None,
            "confidence": insight.confidence,
        }
    if checkin_count < 3:
        return {
            "id": None,
            "title": None,
            "severity": None,
            "empty_message": "Peppy needs a few check-ins to find useful patterns.",
            "confidence": None,
        }
    return {
        "id": None,
        "title": None,
        "severity": None,
        "empty_message": "No new insights right now.",
        "confidence": None,
    }
```

- [x] **Step 4: Run tests to verify they pass**

Run: `cd backend && venv/bin/python -m pytest tests/test_dashboard_service.py -q`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add backend/app/api/schemas/dashboard.py backend/app/services/dashboard.py backend/tests/test_dashboard_service.py
git commit -m "feat: add insight confidence to dashboard summary"
```

---

### Task 3: Backend — recent activity feed

**Files:**
- Modify: `backend/app/api/schemas/dashboard.py`
- Modify: `backend/app/services/dashboard.py`
- Test: `backend/tests/test_dashboard_service.py`
- Test: `backend/tests/test_dashboard_routes.py`

**Interfaces:**
- Produces: `DashboardActivityItem { type: str, title: str, subtitle: str, timestamp: datetime, protocol_id: Optional[UUID], checkin_id: Optional[UUID] }` and `DashboardSummary.recent_activity: list[DashboardActivityItem]` (JSON key `recent_activity`), up to 5 items, merged from dose logs, check-ins, wearable syncs, and lab results, newest first.

- [x] **Step 1: Write the failing tests**

Add to `backend/tests/test_dashboard_service.py`. Extend the imports at the top of the file with:

```python
from datetime import datetime, timezone

from app.models.checkin import Checkin
from app.models.dose_log import DoseLog
from app.models.lab import LabResult
from app.models.wearable import WearableConnection, WearableProvider
```

Then add:

```python
async def test_dashboard_summary_recent_activity_merges_all_event_types(db_session, user):
    protocol = await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )
    compound = protocol.compounds[0]
    now = datetime.now(timezone.utc)

    # Every timestamp is set explicitly (including `created_at`, which
    # overrides the model's server_default) so the expected descending order
    # below is deterministic rather than depending on real wall-clock
    # ordering between separate flush calls.
    checkin = Checkin(
        user_id=user.id,
        date=date.today(),
        weight_kg=74.8,
        energy_level=7,
        mood=8,
        created_at=now - timedelta(hours=2),
    )
    db_session.add_all(
        [
            DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=4.0,
                unit="mg",
                administered_at=now - timedelta(hours=1),
                route="subcutaneous",
            ),
            checkin,
            WearableConnection(
                user_id=user.id,
                provider=WearableProvider.OURA,
                access_token="test-token",
                last_sync_at=now - timedelta(hours=3),
            ),
            LabResult(
                user_id=user.id,
                date=date.today() - timedelta(days=2),
                panel_type="metabolic",
                lab_name="Comprehensive Metabolic Panel",
                created_at=now - timedelta(hours=4),
            ),
        ]
    )
    await db_session.flush()

    summary = await DashboardService(db_session).summary_for_user(user.id)
    activity = summary["recent_activity"]

    assert [item["type"] for item in activity] == [
        "dose_logged",
        "checkin_completed",
        "wearable_synced",
        "lab_added",
    ]
    assert activity[0]["title"] == "Dose logged"
    assert activity[0]["subtitle"] == "Retatrutide • 4 mg"
    assert activity[0]["protocol_id"] == protocol.id
    assert activity[1]["subtitle"] == "Energy, mood, weight"
    assert activity[1]["checkin_id"] == checkin.id
    assert activity[2]["subtitle"] == "Oura"
    assert activity[3]["subtitle"] == "Comprehensive Metabolic Panel"


async def test_dashboard_summary_recent_activity_empty_when_no_events(db_session, user):
    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert summary["recent_activity"] == []


async def test_dashboard_summary_recent_activity_caps_at_five_most_recent(db_session, user):
    protocol = await ProtocolService(db_session).create_pending_starter(
        user_id=user.id,
        peptide_names=["Retatrutide"],
        goals=["track_protocols"],
    )
    compound = protocol.compounds[0]
    now = datetime.now(timezone.utc)
    db_session.add_all(
        [
            DoseLog(
                user_id=user.id,
                protocol_id=protocol.id,
                compound_id=compound.id,
                dose=4.0,
                unit="mg",
                administered_at=now - timedelta(hours=offset),
                route="subcutaneous",
            )
            for offset in range(1, 8)
        ]
    )
    await db_session.flush()

    summary = await DashboardService(db_session).summary_for_user(user.id)

    assert len(summary["recent_activity"]) == 5
    assert summary["recent_activity"][0]["timestamp"] == now - timedelta(hours=1)
```

Add to `backend/tests/test_dashboard_routes.py`, appended to the end of `test_dashboard_summary_returns_attached_pending_starter`:

```python
    assert data["protocol"]["start_date"] is not None
    assert data["insight"]["confidence"] is None
    assert data["recent_activity"] == []
```

- [x] **Step 2: Run tests to verify they fail**

Run: `cd backend && venv/bin/python -m pytest tests/test_dashboard_service.py tests/test_dashboard_routes.py -k "recent_activity or attached_pending_starter" -q`
Expected: FAIL with `KeyError: 'recent_activity'`.

- [x] **Step 3: Implement**

In `backend/app/api/schemas/dashboard.py`, add the new model and field:

```python
class DashboardActivityItem(BaseModel):
    type: str
    title: str
    subtitle: str
    timestamp: datetime
    protocol_id: Optional[UUID] = None
    checkin_id: Optional[UUID] = None


class DashboardSummary(BaseModel):
    generated_at: datetime
    profile_status: str
    protocol: DashboardProtocolSummary
    today_checkin: DashboardTodayCheckin
    response_snapshot: DashboardResponseSnapshot
    insight: DashboardInsightSummary
    connected_context: DashboardConnectedContext
    recent_activity: list[DashboardActivityItem] = []
```

In `backend/app/services/dashboard.py`, update the import line for `Protocol` to also bring in `Compound`:

```python
from app.models.protocol import Compound, Protocol
```

Add `"recent_activity": await self._recent_activity(user_id),` as a new key in the dict returned by `summary_for_user`, alongside the existing keys.

Add the new method and its three small helpers:

```python
async def _recent_activity(self, user_id: UUID) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []

    dose_result = await self.db.execute(
        select(DoseLog, Compound.name)
        .join(Compound, DoseLog.compound_id == Compound.id)
        .where(DoseLog.user_id == user_id)
        .order_by(DoseLog.administered_at.desc())
        .limit(5)
    )
    for dose_log, compound_name in dose_result.all():
        items.append(
            {
                "type": "dose_logged",
                "title": "Dose logged",
                "subtitle": f"{compound_name} • {self._format_dose(dose_log.dose)} {dose_log.unit}",
                "timestamp": dose_log.administered_at,
                "protocol_id": dose_log.protocol_id,
                "checkin_id": None,
            }
        )

    checkin_result = await self.db.execute(
        select(Checkin)
        .where(Checkin.user_id == user_id)
        .order_by(Checkin.created_at.desc())
        .limit(5)
    )
    for checkin in checkin_result.scalars().all():
        items.append(
            {
                "type": "checkin_completed",
                "title": "Check-in completed",
                "subtitle": self._checkin_subtitle(checkin),
                "timestamp": checkin.created_at,
                "protocol_id": None,
                "checkin_id": checkin.id,
            }
        )

    wearable_result = await self.db.execute(
        select(WearableConnection)
        .where(
            WearableConnection.user_id == user_id,
            WearableConnection.last_sync_at.is_not(None),
        )
        .order_by(WearableConnection.last_sync_at.desc())
        .limit(5)
    )
    for connection in wearable_result.scalars().all():
        items.append(
            {
                "type": "wearable_synced",
                "title": "Wearable synced",
                "subtitle": self._provider_label(connection.provider),
                "timestamp": connection.last_sync_at,
                "protocol_id": None,
                "checkin_id": None,
            }
        )

    lab_result = await self.db.execute(
        select(LabResult)
        .where(LabResult.user_id == user_id)
        .order_by(LabResult.created_at.desc())
        .limit(5)
    )
    for lab in lab_result.scalars().all():
        items.append(
            {
                "type": "lab_added",
                "title": "Lab result added",
                "subtitle": lab.lab_name or lab.panel_type.replace("_", " ").title(),
                "timestamp": lab.created_at,
                "protocol_id": None,
                "checkin_id": None,
            }
        )

    items.sort(key=lambda item: item["timestamp"], reverse=True)
    return items[:5]

@staticmethod
def _format_dose(dose: float) -> str:
    return f"{dose:g}"

@staticmethod
def _checkin_subtitle(checkin: Checkin) -> str:
    parts = []
    if checkin.energy_level is not None:
        parts.append("energy")
    if checkin.appetite_level is not None:
        parts.append("appetite")
    if checkin.mood is not None:
        parts.append("mood")
    if checkin.weight_kg is not None:
        parts.append("weight")
    if not parts:
        return "Check-in logged"
    return ", ".join(parts).capitalize()

@staticmethod
def _provider_label(provider: Any) -> str:
    value = provider.value if hasattr(provider, "value") else str(provider)
    return value.replace("_", " ").title()
```

Note: `LabResult` and `WearableConnection` are already imported at the top of `dashboard.py` (used by `_has_rows`) — no new import needed for those two.

- [x] **Step 4: Run tests to verify they pass**

Run: `cd backend && venv/bin/python -m pytest tests/test_dashboard_service.py tests/test_dashboard_routes.py -q`
Expected: PASS.

- [x] **Step 5: Run the full backend suite to confirm no regressions**

Run: `cd backend && venv/bin/python -m pytest -q`
Expected: PASS (same pass count as before this plan, plus the new tests).

- [x] **Step 6: Commit**

```bash
git add backend/app/api/schemas/dashboard.py backend/app/services/dashboard.py backend/tests/test_dashboard_service.py backend/tests/test_dashboard_routes.py
git commit -m "feat: merge dose, check-in, wearable, and lab events into a dashboard activity feed"
```

---

### Task 4: iOS — shared next-dose-due calculation

**Files:**
- Modify: `ios/peppy/Core/Notifications/DoseScheduleCalculator.swift`
- Modify: `ios/peppy/Features/Protocols/Models/ProtocolModels.swift`
- Modify: `ios/peppy/Features/Protocols/ViewModels/ProtocolDetailViewModel.swift`
- Test: `ios/peppy/peppyTests/ProtocolStoreTests.swift`

**Interfaces:**
- Produces: `DoseScheduleCalculator.nextDueDate(frequency:protocolStartDate:doseLogs:for:calendar:) -> Date?` and `Protocol.nextDueCompound(doseLogs:calendar:) -> (compound: Compound, dueDate: Date)?`. `nextDueCompound` is what `DashboardViewModel` will call in Task 7.
- Consumes: existing `DoseScheduleCalculator.recurrence(for:)` / `upcomingDates(...)` (unchanged), existing `DoseLog`/`Compound`/`Protocol` (`ProtocolModel`) types.

This task is a refactor: `ProtocolDetailViewModel.nextDoseDateText(for:in:)` currently contains this exact logic privately. We extract it verbatim into a shared, testable place and make the view model call through to it, so behavior for Protocol Detail is unchanged (verified by its existing passing tests) while the Dashboard gains the same capability for free.

- [x] **Step 1: Write the failing test**

Add to the bottom of `ios/peppy/peppyTests/ProtocolStoreTests.swift`, inside a new `// MARK: - Next dose scheduling (shared with Dashboard)` section, using the file's existing `ProtocolModel.fixture` / `Compound.fixture` (Retatrutide, weekly, dose 2.5mg, start date `1_780_000_000`):

```swift
// MARK: - Next dose scheduling (shared with Dashboard)

final class ProtocolNextDueCompoundTests: XCTestCase {
    func testNextDueCompoundFallsBackToStartDateWithoutLogs() {
        let result = ProtocolModel.fixture.nextDueCompound(doseLogs: [])

        XCTAssertEqual(result?.compound.id, Compound.fixture.id)
        XCTAssertEqual(result?.dueDate, ProtocolModel.fixture.startDate)
    }

    func testNextDueCompoundAdvancesPastLatestLogByFrequency() {
        let latest = Date(timeIntervalSince1970: 1_783_953_000)
        let log = DoseLog(
            id: UUID(),
            protocolID: ProtocolModel.fixture.id,
            compoundID: Compound.fixture.id,
            dose: 2.5,
            unit: "mg",
            administeredAt: latest,
            route: "subcutaneous",
            notes: nil
        )

        let result = ProtocolModel.fixture.nextDueCompound(doseLogs: [log])

        XCTAssertEqual(result?.dueDate, latest.addingTimeInterval(7 * 86_400))
    }

    func testNextDueCompoundPicksEarliestAcrossMultipleCompounds() {
        let secondCompound = Compound(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Semaglutide",
            doseMg: 1.0,
            doseUnit: "mg",
            frequency: "daily",
            administrationRoute: "subcutaneous",
            notes: nil
        )
        let twoCompoundProtocol = ProtocolModel(
            id: ProtocolModel.fixture.id,
            name: ProtocolModel.fixture.name,
            startDate: ProtocolModel.fixture.startDate,
            endDate: nil,
            notes: nil,
            isActive: true,
            setupStatus: "active",
            isStarter: false,
            compounds: [Compound.fixture, secondCompound]
        )
        // Fixture compound (weekly) was last dosed further back than the
        // second compound (daily) was, so its +7-day due date lands later
        // than the second compound's +1-day due date — the second compound
        // should win.
        let fixtureLastDose = Date(timeIntervalSince1970: 1_783_000_000)
        let secondCompoundLastDose = Date(timeIntervalSince1970: 1_783_500_000)
        let logs = [
            DoseLog(
                id: UUID(), protocolID: twoCompoundProtocol.id, compoundID: Compound.fixture.id,
                dose: 2.5, unit: "mg", administeredAt: fixtureLastDose,
                route: "subcutaneous", notes: nil
            ),
            DoseLog(
                id: UUID(), protocolID: twoCompoundProtocol.id, compoundID: secondCompound.id,
                dose: 1.0, unit: "mg", administeredAt: secondCompoundLastDose,
                route: "subcutaneous", notes: nil
            ),
        ]

        let result = twoCompoundProtocol.nextDueCompound(doseLogs: logs)

        XCTAssertEqual(result?.compound.id, secondCompound.id)
        XCTAssertEqual(result?.dueDate, secondCompoundLastDose.addingTimeInterval(86_400))
    }

    func testNextDueCompoundReturnsNilForProtocolWithNoCompounds() {
        let empty = ProtocolModel(
            id: ProtocolModel.fixture.id,
            name: ProtocolModel.fixture.name,
            startDate: ProtocolModel.fixture.startDate,
            endDate: nil,
            notes: nil,
            isActive: true,
            setupStatus: "active",
            isStarter: false,
            compounds: []
        )

        XCTAssertNil(empty.nextDueCompound(doseLogs: []))
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/ProtocolNextDueCompoundTests test`
Expected: FAIL — build error, `value of type 'Protocol' has no member 'nextDueCompound'`.

- [x] **Step 3: Implement**

In `ios/peppy/Core/Notifications/DoseScheduleCalculator.swift`, add a new function inside `enum DoseScheduleCalculator` (after `upcomingDates`, before the private helpers):

```swift
/// The next due date for one compound, given its dose logs so far. Falls
/// back to the protocol's start date when the compound has never been
/// logged; returns `nil` when the frequency string isn't recognized.
static func nextDueDate(
    frequency: String,
    protocolStartDate: Date,
    doseLogs: [DoseLog],
    for compoundID: UUID,
    calendar: Calendar = .current
) -> Date? {
    let compoundLogs = doseLogs.filter { $0.compoundID == compoundID }
    guard let latest = compoundLogs.map(\.administeredAt).max() else {
        return protocolStartDate
    }
    guard let recurrence = recurrence(for: frequency) else {
        return nil
    }
    switch recurrence {
    case .fixedDays(let interval):
        return calendar.date(byAdding: .day, value: interval, to: latest)
    case .twiceWeekly, .monthly:
        return upcomingDates(
            startingAt: protocolStartDate,
            frequency: frequency,
            localTime: calendar.dateComponents([.hour, .minute], from: latest),
            after: latest,
            calendar: calendar,
            limit: 1
        ).first
    }
}
```

In `ios/peppy/Features/Protocols/Models/ProtocolModels.swift`, add an extension after the existing `status` extension:

```swift
extension Protocol {
    /// The compound with the soonest upcoming dose across the whole protocol,
    /// or `nil` if there are no compounds or none has a computable schedule
    /// (e.g. an unrecognized frequency string).
    func nextDueCompound(
        doseLogs: [DoseLog],
        calendar: Calendar = .current
    ) -> (compound: Compound, dueDate: Date)? {
        compounds
            .compactMap { compound -> (Compound, Date)? in
                guard let due = DoseScheduleCalculator.nextDueDate(
                    frequency: compound.frequency,
                    protocolStartDate: startDate,
                    doseLogs: doseLogs,
                    for: compound.id,
                    calendar: calendar
                ) else { return nil }
                return (compound, due)
            }
            .min { $0.1 < $1.1 }
            .map { (compound: $0.0, dueDate: $0.1) }
    }
}
```

In `ios/peppy/Features/Protocols/ViewModels/ProtocolDetailViewModel.swift`, replace the body of the private `nextDoseDateText(for:in:)` method with a call to the shared calculator, keeping the method's signature and its date-formatting responsibility exactly as-is:

```swift
private func nextDoseDateText(for compound: Compound, in protocolValue: ProtocolModel) -> String? {
    guard let next = DoseScheduleCalculator.nextDueDate(
        frequency: compound.frequency,
        protocolStartDate: protocolValue.startDate,
        doseLogs: store.doseLogs,
        for: compound.id
    ) else { return nil }
    return Self.dayDateFormatter.string(from: next)
}
```

- [x] **Step 4: Run tests to verify they pass**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/ProtocolNextDueCompoundTests -only-testing:peppyTests/ProtocolDetailViewModelTests test`
Expected: PASS — including `testNextDoseDerivesFromLatestLogAndFrequency` and `testNextDoseFallsBackToStartDateWithoutLogs`, unchanged and still green after the refactor.

- [x] **Step 5: Commit**

```bash
git add ios/peppy/Core/Notifications/DoseScheduleCalculator.swift ios/peppy/Features/Protocols/Models/ProtocolModels.swift ios/peppy/Features/Protocols/ViewModels/ProtocolDetailViewModel.swift ios/peppy/peppyTests/ProtocolStoreTests.swift
git commit -m "refactor: share next-dose-due calculation between Protocol Detail and Dashboard"
```

---

### Task 5: iOS — wearable latest-data endpoint and request-ID disambiguation

**Files:**
- Modify: `ios/peppy/Core/Network/Endpoint.swift`
- Modify: `ios/peppy/Core/Network/APIModels.swift`
- Test: `ios/peppy/peppyTests/DashboardViewModelTests.swift` (endpoint-shape assertions only in this task; wiring comes in Task 7)

**Interfaces:**
- Produces: `Endpoint.getLatestWearableData(provider: String)` → `GET /wearables/data/latest?provider=<provider>`; `WearableDataSnapshot { sleepHours: Double?, hrvMs: Double?, readinessScore: Double? }` (Codable, matches the existing `WearableDataResponse` backend schema — only the three fields the dashboard tiles need).
- Fixes: `Endpoint.requestID` now includes query items when present, so `MockAPIClient` can hold distinct mock responses for e.g. `provider=oura` vs `provider=whoop`. For every endpoint without query items (the majority), the string is unchanged.

- [x] **Step 1: Write the failing test**

Add to `ios/peppy/peppyTests/DashboardViewModelTests.swift`, as a new top-level test class at the bottom of the file:

```swift
final class WearableEndpointTests: XCTestCase {
    func testGetLatestWearableDataPathAndQuery() {
        let endpoint = Endpoint.getLatestWearableData(provider: "oura")

        XCTAssertEqual(endpoint.path, "/wearables/data/latest")
        XCTAssertEqual(endpoint.queryItems, [URLQueryItem(name: "provider", value: "oura")])
        XCTAssertEqual(endpoint.method, .get)
    }

    func testRequestIDDisambiguatesByProvider() {
        let oura = Endpoint.getLatestWearableData(provider: "oura")
        let whoop = Endpoint.getLatestWearableData(provider: "whoop")

        XCTAssertNotEqual(oura.requestID, whoop.requestID)
    }

    func testRequestIDUnchangedForEndpointsWithoutQueryItems() {
        XCTAssertEqual(Endpoint.getDashboardSummary.requestID, "GET /dashboard/summary")
    }

    func testMockAPIClientHoldsDistinctResponsesPerProvider() async throws {
        let api = MockAPIClient()
        api.setMockResponse(
            WearableDataSnapshot(sleepHours: 7.2, hrvMs: 54, readinessScore: nil),
            for: Endpoint.getLatestWearableData(provider: "oura")
        )
        api.setMockResponse(
            WearableDataSnapshot(sleepHours: nil, hrvMs: nil, readinessScore: 72),
            for: Endpoint.getLatestWearableData(provider: "whoop")
        )

        let oura: WearableDataSnapshot? = try await api.execute(.getLatestWearableData(provider: "oura"))
        let whoop: WearableDataSnapshot? = try await api.execute(.getLatestWearableData(provider: "whoop"))

        XCTAssertEqual(oura?.sleepHours, 7.2)
        XCTAssertEqual(whoop?.readinessScore, 72)
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/WearableEndpointTests test`
Expected: FAIL — build error, `type 'Endpoint' has no member 'getLatestWearableData'`.

- [x] **Step 3: Implement**

In `ios/peppy/Core/Network/Endpoint.swift`, add the case under `// MARK: - Wearables`:

```swift
case getLatestWearableData(provider: String)
```

Add to the `path` switch, under the Wearables section:

```swift
case .getLatestWearableData: return "/wearables/data/latest"
```

Add to the `queryItems` switch, before the `default` case:

```swift
case .getLatestWearableData(let provider):
    return [URLQueryItem(name: "provider", value: provider)]
```

(No change needed to `method` — it already defaults to `.get`, and no change needed to `body`.)

Replace the `requestID` computed property:

```swift
/// Stable request identity for tests and mocks. Paths alone collide when
/// one path serves multiple verbs (e.g. GET vs POST `/protocols`) or, for
/// endpoints with query items, multiple distinct requests (e.g.
/// `?provider=oura` vs `?provider=whoop`).
var requestID: String {
    guard let queryItems, !queryItems.isEmpty else {
        return "\(method.rawValue) \(path)"
    }
    let query = queryItems
        .sorted { $0.name < $1.name }
        .map { "\($0.name)=\($0.value ?? "")" }
        .joined(separator: "&")
    return "\(method.rawValue) \(path)?\(query)"
}
```

In `ios/peppy/Core/Network/APIModels.swift`, add near the existing `WearableConnection` struct (under `// MARK: - Wearable`):

```swift
struct WearableDataSnapshot: Codable, Equatable {
    let sleepHours: Double?
    let hrvMs: Double?
    let readinessScore: Double?

    enum CodingKeys: String, CodingKey {
        case sleepHours = "sleep_hours"
        case hrvMs = "hrv_ms"
        case readinessScore = "readiness_score"
    }
}
```

- [x] **Step 4: Run tests to verify they pass**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/WearableEndpointTests test`
Expected: PASS.

- [x] **Step 5: Run the full iOS test suite to confirm the `requestID` change is safe**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
Expected: PASS, same as before this task (every existing usage of `.requestID` compares two live-computed values rather than a hardcoded string, so widening the format for query-bearing endpoints doesn't break anything).

- [x] **Step 6: Commit**

```bash
git add ios/peppy/Core/Network/Endpoint.swift ios/peppy/Core/Network/APIModels.swift ios/peppy/peppyTests/DashboardViewModelTests.swift
git commit -m "feat: add latest-wearable-data endpoint and disambiguate mock request IDs by query"
```

---

### Task 6: iOS — extend Dashboard models

**Files:**
- Modify: `ios/peppy/Features/Dashboard/Models/DashboardModels.swift`
- Test: `ios/peppy/peppyTests/DashboardViewModelTests.swift`

**Interfaces:**
- Produces: `DashboardProtocolSummary.startDate: Date?`, `DashboardInsightSummary.confidence: Double?`, `DashboardActivityItem { type, title, subtitle, timestamp, protocolID, checkinID }` (`Identifiable` via a synthetic `id`), `DashboardSummary.recentActivity: [DashboardActivityItem]?`, and `DashboardWearableTiles { sleepHours, hrvMs, readinessScore, isEmpty }`.
- Consumes: `APIDateOnly.date(from:)` (existing, `Core/Network/APIModels.swift`) for date-only wire decoding.

- [x] **Step 1: Write the failing test**

Add to `ios/peppy/peppyTests/DashboardViewModelTests.swift`, as a new top-level test class:

```swift
final class DashboardModelDecodingTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testProtocolSummaryDecodesDateOnlyStartDate() throws {
        let json = """
        {"id": null, "status": "active", "title": "Retatrutide Titration", "compounds": [], "start_date": "2026-05-28"}
        """
        let summary = try decoder.decode(DashboardProtocolSummary.self, from: Data(json.utf8))

        XCTAssertEqual(summary.startDate, APIDateOnly.date(from: "2026-05-28"))
    }

    func testProtocolSummaryStartDateDefaultsToNilWhenMissing() throws {
        let json = """
        {"id": null, "status": "missing", "title": "Create your protocol", "compounds": []}
        """
        let summary = try decoder.decode(DashboardProtocolSummary.self, from: Data(json.utf8))

        XCTAssertNil(summary.startDate)
    }

    func testInsightSummaryDecodesConfidence() throws {
        let json = """
        {"id": null, "title": "Trend", "severity": "info", "empty_message": null, "confidence": 0.82}
        """
        let summary = try decoder.decode(DashboardInsightSummary.self, from: Data(json.utf8))

        XCTAssertEqual(summary.confidence, 0.82)
    }

    func testActivityItemDecodesAndIsIdentifiable() throws {
        let json = """
        {"type": "dose_logged", "title": "Dose logged", "subtitle": "Retatrutide \\u2022 4 mg", "timestamp": "2026-07-23T08:02:00Z", "protocol_id": null, "checkin_id": null}
        """
        let item = try decoder.decode(DashboardActivityItem.self, from: Data(json.utf8))

        XCTAssertEqual(item.type, "dose_logged")
        XCTAssertEqual(item.title, "Dose logged")
        XCTAssertFalse(item.id.isEmpty)
    }
}

extension DashboardModelDecodingTests {
    func testWearableTilesReportsEmptyWhenAllFieldsNil() {
        let tiles = DashboardWearableTiles(sleepHours: nil, hrvMs: nil, readinessScore: nil)

        XCTAssertTrue(tiles.isEmpty)
    }

    func testWearableTilesReportsNonEmptyWithAnyValue() {
        let tiles = DashboardWearableTiles(sleepHours: 7.2, hrvMs: nil, readinessScore: nil)

        XCTAssertFalse(tiles.isEmpty)
    }
}
```

- [x] **Step 2: Run tests to verify they fail**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/DashboardModelDecodingTests test`
Expected: FAIL — build errors (`value of type 'DashboardProtocolSummary' has no member 'startDate'`, `cannot find type 'DashboardActivityItem'`, `cannot find type 'DashboardWearableTiles'`).

- [x] **Step 3: Implement**

In `ios/peppy/Features/Dashboard/Models/DashboardModels.swift`, replace `DashboardProtocolSummary` with a version that adds a date-only-aware `startDate`:

```swift
struct DashboardProtocolSummary: Codable, Equatable {
    let id: UUID?
    let status: String
    let title: String
    let compounds: [String]
    let startDate: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, title, compounds
        case startDate = "start_date"
    }

    init(id: UUID?, status: String, title: String, compounds: [String], startDate: Date? = nil) {
        self.id = id
        self.status = status
        self.title = title
        self.compounds = compounds
        self.startDate = startDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        title = try container.decode(String.self, forKey: .title)
        compounds = try container.decode([String].self, forKey: .compounds)
        if let raw = try container.decodeIfPresent(String.self, forKey: .startDate) {
            startDate = APIDateOnly.date(from: raw)
        } else {
            startDate = nil
        }
    }
}
```

Replace `DashboardInsightSummary` to add `confidence`:

```swift
struct DashboardInsightSummary: Codable, Equatable {
    let id: UUID?
    let title: String?
    let severity: String?
    let emptyMessage: String?
    let confidence: Double? = nil

    enum CodingKeys: String, CodingKey {
        case id, title, severity, confidence
        case emptyMessage = "empty_message"
    }
}
```

As with `recentActivity` below, the inline `= nil` is required, not cosmetic: `DashboardModels.swift`'s two existing `mockPendingStarter`/`mockMissingProfile` fixtures construct `DashboardInsightSummary(id:title:severity:emptyMessage:)` without a `confidence:` argument, and only compile because the memberwise initializer picks up this default.

Add `recentActivity` to `DashboardSummary` and the new `DashboardActivityItem` type:

```swift
struct DashboardActivityItem: Codable, Equatable, Identifiable {
    let type: String
    let title: String
    let subtitle: String
    let timestamp: Date
    let protocolID: UUID?
    let checkinID: UUID?

    var id: String { "\(type)-\(timestamp.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case type, title, subtitle, timestamp
        case protocolID = "protocol_id"
        case checkinID = "checkin_id"
    }
}

struct DashboardWearableTiles: Equatable {
    let sleepHours: Double?
    let hrvMs: Double?
    let readinessScore: Double?

    var isEmpty: Bool {
        sleepHours == nil && hrvMs == nil && readinessScore == nil
    }
}
```

Update the `DashboardSummary` struct declaration to add the field (as the last stored property) and its `CodingKeys` entry:

```swift
struct DashboardSummary: Codable, Equatable {
    let generatedAt: Date
    let profileStatus: String
    let `protocol`: DashboardProtocolSummary
    let todayCheckin: DashboardTodayCheckin
    let responseSnapshot: DashboardResponseSnapshot
    let insight: DashboardInsightSummary
    let connectedContext: DashboardConnectedContext
    let recentActivity: [DashboardActivityItem]? = nil

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case profileStatus = "profile_status"
        case `protocol`
        case todayCheckin = "today_checkin"
        case responseSnapshot = "response_snapshot"
        case insight
        case connectedContext = "connected_context"
        case recentActivity = "recent_activity"
    }
}
```

The `= nil` inline default matters, not just the `Optional` type: Swift's synthesized memberwise initializer only gives a parameter a default value when the stored property itself has one. Without it, every existing call site that constructs `DashboardSummary(...)` directly — the two `mock*` fixtures, `replacingProtocol(with:)`, **and** the literal `DashboardSummary(...)` built inline inside `testCheckinRefreshFailurePreservesPreviouslyLoadedSummaryAndRoute` in `DashboardViewModelTests.swift` — would fail to compile with a missing-argument error. With the inline default, all of them keep compiling completely unchanged; no existing file needs editing for this field alone.

- [x] **Step 4: Run tests to verify they pass**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/DashboardModelDecodingTests -only-testing:peppyTests/DashboardViewModelTests test`
Expected: PASS — including every pre-existing `DashboardViewModelTests` case, unaffected by the new optional field.

- [x] **Step 5: Commit**

```bash
git add ios/peppy/Features/Dashboard/Models/DashboardModels.swift ios/peppy/peppyTests/DashboardViewModelTests.swift
git commit -m "feat: decode protocol start date, insight confidence, and recent activity on the dashboard summary"
```

---

### Task 7: iOS — extend DashboardViewModel

**Files:**
- Modify: `ios/peppy/Features/Dashboard/ViewModels/DashboardViewModel.swift`
- Test: `ios/peppy/peppyTests/DashboardViewModelTests.swift`

**Interfaces:**
- Consumes: `Endpoint.getLatestWearableData(provider:)` (Task 5), `WearableDataSnapshot` (Task 5), `Protocol.nextDueCompound(doseLogs:)` (Task 4), `ProtocolStore.loadProtocols()`/`loadDoseLogs(protocolID:)`/`protocols`/`doseLogs` (existing), `DashboardWearableTiles` (Task 6).
- Produces: `DashboardViewModel.greetingText: String`, `DashboardViewModel.nextDose: (compound: Compound, dueDate: Date)?`, `DashboardViewModel.wearableTiles: DashboardWearableTiles?`, plus a new `now` and `currentDisplayName` initializer parameter (both defaulted, so every existing call site keeps compiling).

- [ ] **Step 1: Write the failing tests**

Add to `ios/peppy/peppyTests/DashboardViewModelTests.swift`:

```swift
func testGreetingUsesFirstNameAndMorningHour() async {
    let api = MockAPIClient()
    api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
    let morning = Date(timeIntervalSince1970: 1_784_000_400) // fixed morning-hour instant (UTC)
    let model = DashboardViewModel(
        api: api,
        hasProfileAttachFailure: false,
        currentDisplayName: { "Taylor Reed" },
        now: { morning }
    )

    await model.load()

    XCTAssertTrue(model.greetingText.hasPrefix("Good "))
    XCTAssertTrue(model.greetingText.hasSuffix("Taylor"))
}

func testGreetingFallsBackToThereWithoutDisplayName() async {
    let api = MockAPIClient()
    api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
    let model = DashboardViewModel(
        api: api,
        hasProfileAttachFailure: false,
        currentDisplayName: { nil }
    )

    await model.load()

    XCTAssertTrue(model.greetingText.hasSuffix("there"))
}

func testNextDoseLoadsFullProtocolAndDoseLogsForActiveProtocol() async {
    let api = MockAPIClient()
    let summary = DashboardSummary(
        generatedAt: DashboardSummary.mockPendingStarter.generatedAt,
        profileStatus: "present",
        protocol: DashboardProtocolSummary(
            id: ProtocolModel.fixture.id,
            status: "active",
            title: ProtocolModel.fixture.name,
            compounds: ["Retatrutide"],
            startDate: ProtocolModel.fixture.startDate
        ),
        todayCheckin: DashboardTodayCheckin(logged: false, checkinId: nil),
        responseSnapshot: DashboardSummary.mockPendingStarter.responseSnapshot,
        insight: DashboardSummary.mockPendingStarter.insight,
        connectedContext: DashboardSummary.mockPendingStarter.connectedContext,
        recentActivity: nil
    )
    api.setMockResponse(summary, for: Endpoint.getDashboardSummary)
    api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
    api.setMockResponse([DoseLog](), for: Endpoint.getDoseLogs(protocolID: ProtocolModel.fixture.id))
    let store = ProtocolStore(api: api)
    let model = DashboardViewModel(api: api, protocolStore: store, hasProfileAttachFailure: false)

    await model.load()

    XCTAssertEqual(model.nextDose?.compound.id, Compound.fixture.id)
    XCTAssertEqual(model.nextDose?.dueDate, ProtocolModel.fixture.startDate)
}

func testNextDoseIsNilWhenProtocolNotActive() async {
    let api = MockAPIClient()
    api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
    let store = ProtocolStore(api: api)
    let model = DashboardViewModel(api: api, protocolStore: store, hasProfileAttachFailure: false)

    await model.load()

    XCTAssertNil(model.nextDose)
}

func testWearableTilesLoadsWhenConnectedContextHasWearables() async {
    let api = MockAPIClient()
    let summary = DashboardSummary(
        generatedAt: DashboardSummary.mockPendingStarter.generatedAt,
        profileStatus: "present",
        protocol: DashboardSummary.mockPendingStarter.protocol,
        todayCheckin: DashboardSummary.mockPendingStarter.todayCheckin,
        responseSnapshot: DashboardSummary.mockPendingStarter.responseSnapshot,
        insight: DashboardSummary.mockPendingStarter.insight,
        connectedContext: DashboardConnectedContext(healthkitRequested: nil, hasLabs: false, hasWearables: true),
        recentActivity: nil
    )
    api.setMockResponse(summary, for: Endpoint.getDashboardSummary)
    api.setMockResponse(
        WearableDataSnapshot(sleepHours: 7.2, hrvMs: 54, readinessScore: nil),
        for: Endpoint.getLatestWearableData(provider: "oura")
    )
    api.setMockResponse(
        WearableDataSnapshot(sleepHours: nil, hrvMs: nil, readinessScore: 72),
        for: Endpoint.getLatestWearableData(provider: "whoop")
    )
    let model = DashboardViewModel(api: api, hasProfileAttachFailure: false)

    await model.load()

    XCTAssertEqual(model.wearableTiles?.sleepHours, 7.2)
    XCTAssertEqual(model.wearableTiles?.hrvMs, 54)
    XCTAssertEqual(model.wearableTiles?.readinessScore, 72)
}

func testWearableTilesIsNilWhenNotConnected() async {
    let api = MockAPIClient()
    api.setMockResponse(DashboardSummary.mockMissingProfile, for: Endpoint.getDashboardSummary)
    let model = DashboardViewModel(api: api, hasProfileAttachFailure: false)

    await model.load()

    XCTAssertNil(model.wearableTiles)
    XCTAssertFalse(api.requestLog.contains { $0.path == "/wearables/data/latest" })
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/DashboardViewModelTests test`
Expected: FAIL — build errors (`no member 'greetingText'`, `no member 'nextDose'`, `no member 'wearableTiles'`, extra initializer arguments not recognized).

- [ ] **Step 3: Implement**

In `ios/peppy/Features/Dashboard/ViewModels/DashboardViewModel.swift`, update the class:

```swift
@MainActor
@Observable
final class DashboardViewModel {
    private let api: APIClientProtocol
    private let protocolStore: ProtocolStore?
    private let checkinStore: CheckinStore?
    private let weightUnitPreferences: WeightUnitPreferences?
    private let hasProfileAttachFailure: () -> Bool
    private let currentDisplayName: () -> String?
    private let now: () -> Date
    private var lastSeenProtocolRevision: Int
    private var lastSeenCheckinRevision: Int

    var state = DashboardState()
    private(set) var wearableTiles: DashboardWearableTiles?

    init(
        api: APIClientProtocol,
        protocolStore: ProtocolStore? = nil,
        checkinStore: CheckinStore? = nil,
        weightUnitPreferences: WeightUnitPreferences? = nil,
        hasProfileAttachFailure: @autoclosure @escaping () -> Bool,
        currentDisplayName: @escaping () -> String? = { nil },
        now: @escaping () -> Date = Date.init
    ) {
        self.api = api
        self.protocolStore = protocolStore
        self.checkinStore = checkinStore
        self.weightUnitPreferences = weightUnitPreferences
        self.hasProfileAttachFailure = hasProfileAttachFailure
        self.currentDisplayName = currentDisplayName
        self.now = now
        self.lastSeenProtocolRevision = protocolStore?.revision ?? 0
        self.lastSeenCheckinRevision = checkinStore?.revision ?? 0
    }
```

Add the greeting and next-dose computed properties (near `todayPreview`):

```swift
    var greetingText: String {
        "Good \(dayPart), \(firstName)"
    }

    private var firstName: String {
        guard let displayName = currentDisplayName()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !displayName.isEmpty,
              let first = displayName.split(separator: " ").first else {
            return "there"
        }
        return String(first)
    }

    private var dayPart: String {
        switch Calendar.current.component(.hour, from: now()) {
        case 5...11: return "morning"
        case 12...16: return "afternoon"
        default: return "evening"
        }
    }

    var nextDose: (compound: Compound, dueDate: Date)? {
        guard let summary = state.summary,
              summary.protocol.status == "active",
              let protocolID = summary.protocol.id,
              let fullProtocol = protocolStore?.protocols.first(where: { $0.id == protocolID }),
              !fullProtocol.compounds.isEmpty
        else { return nil }
        return fullProtocol.nextDueCompound(doseLogs: protocolStore?.doseLogs ?? [])
    }
```

Update `loadDashboardSummary()` to also load what `nextDose` and `wearableTiles` need. Replace the method body with:

```swift
    private func loadDashboardSummary() async {
        state.isLoading = true
        state.errorMessage = nil
        defer { state.isLoading = false }

        do {
            let summary: DashboardSummary = try await api.execute(.getDashboardSummary)
            state.summary = await recoveringProtocol(in: summary)
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        } catch let error as APIError {
            state.errorMessage = error.userMessage
            if state.summary == nil {
                state.summary = await recoveringProtocol(in: .mockMissingProfile)
            }
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        } catch {
            state.errorMessage = error.localizedDescription
            if state.summary == nil {
                state.summary = await recoveringProtocol(in: .mockMissingProfile)
            }
            state.showsProfileSyncRecovery = hasProfileAttachFailure()
        }

        await loadActiveProtocolDetailIfNeeded()
        await loadWearableTilesIfNeeded()
    }

    private func loadActiveProtocolDetailIfNeeded() async {
        guard let summary = state.summary,
              summary.protocol.status == "active",
              let protocolID = summary.protocol.id else { return }
        await protocolStore?.loadProtocols()
        await protocolStore?.loadDoseLogs(protocolID: protocolID)
    }

    private func loadWearableTilesIfNeeded() async {
        guard state.summary?.connectedContext.hasWearables == true else {
            wearableTiles = nil
            return
        }
        // Sequential, not `async let`: `MockAPIClient` is a plain class, not
        // an actor, so concurrent calls into it from two child tasks would be
        // a data race in tests. Two small GETs in series is cheap enough that
        // the lost parallelism doesn't matter here.
        let ouraData = await fetchWearableData(provider: "oura")
        let whoopData = await fetchWearableData(provider: "whoop")
        let tiles = DashboardWearableTiles(
            sleepHours: ouraData?.sleepHours,
            hrvMs: ouraData?.hrvMs,
            readinessScore: whoopData?.readinessScore
        )
        wearableTiles = tiles.isEmpty ? nil : tiles
    }

    private func fetchWearableData(provider: String) async -> WearableDataSnapshot? {
        try? await api.execute(.getLatestWearableData(provider: provider))
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/DashboardViewModelTests test`
Expected: PASS — all new tests plus every pre-existing one in the file.

- [ ] **Step 5: Commit**

```bash
git add ios/peppy/Features/Dashboard/ViewModels/DashboardViewModel.swift ios/peppy/peppyTests/DashboardViewModelTests.swift
git commit -m "feat: compute dashboard greeting, next dose, and wearable tiles"
```

---

### Task 8: iOS — restyle existing cards, add Next Dose and Insight cards

**Files:**
- Modify: `ios/peppy/Features/Dashboard/Views/DashboardCards.swift`

**Interfaces:**
- Produces: `DashboardNextDoseCard(compound:dueDate:logDose:)`, `DashboardInsightCard(insight:action:)`, and `DashboardInsightSummary.confidenceLabel: String?` (new extension). `DashboardProtocolCard`/`DashboardTodayCard` keep their existing public interfaces (init parameters, and every extension on `DashboardProtocolSummary`) — only their view bodies change.

No test steps here beyond compiling and the manual QA checklist in Task 10 — these are pure-presentation views with no branching logic of their own, and the extension properties they lean on (`cardTitle`, `badgeText`, `confidenceLabel`, etc.) already are/will be unit-tested directly.

- [ ] **Step 1: Add the confidence-label extension**

In `ios/peppy/Features/Dashboard/Views/DashboardCards.swift`, add near the other `DashboardProtocolSummary` extension:

```swift
extension DashboardInsightSummary {
    var confidenceLabel: String? {
        guard let confidence else { return nil }
        switch confidence {
        case ..<0.5: return "Low confidence"
        case 0.5..<0.75: return "Medium confidence"
        default: return "High confidence"
        }
    }
}
```

- [ ] **Step 2: Restyle `DashboardProtocolCard` and `DashboardTodayCard`**

Replace the `DashboardProtocolCard` body (keep its `let summary`/`let finishSetup` properties and the `DashboardProtocolSummary` extension above it untouched):

```swift
struct DashboardProtocolCard: View {
    let summary: DashboardProtocolSummary
    let finishSetup: () -> Void

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    ZStack {
                        Circle().fill(Color.pepPrimaryMuted)
                        Image(systemName: "pills.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                    Text(summary.cardTitle.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.pepPrimary)
                        .tracking(0.5)

                    Spacer(minLength: Spacing.sm)

                    PepBadge(text: summary.badgeText, type: summary.badgeType)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(summary.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.pepTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !summary.compounds.isEmpty {
                        Text(summary.compounds.joined(separator: ", "))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                PepButton(
                    title: summary.actionTitle,
                    style: .primary,
                    action: finishSetup
                )
            }
        }
    }
}
```

Replace the `DashboardTodayCard` body (keep `let today`/`let preview`/`let openCheckin`, `isSaved`, and `accessibilitySummary` untouched — only the `body` changes, so the existing `accessibilityLabel`/`accessibilityElement` behavior that `testSavedCheckinAccessibilitySummaryIncludesVisibleHighlights` depends on is preserved):

```swift
    var body: some View {
        Button(action: openCheckin) {
            PepCard {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle().fill(Color.pepPrimaryMuted)
                        Image(systemName: isSaved ? "checkmark.circle.fill" : "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("TODAY'S CHECK-IN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.pepPrimary)
                            .tracking(0.5)
                        Text(preview?.title ?? (isSaved ? "Your check-in" : "How are you today?"))
                            .font(.headline)
                            .foregroundStyle(Color.pepTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(preview?.subtitle ?? (isSaved
                            ? "Today's check-in is saved"
                            : "Log weight, energy, mood, and symptoms."))
                            .font(.subheadline)
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let preview {
                            ForEach(preview.highlights, id: \.self) { value in
                                Text(value)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.pepTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Spacer(minLength: Spacing.sm)
                    Text(isSaved ? "View" : "Check in")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .overlay(
                            Capsule().stroke(Color.pepPrimary, lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }
```

- [ ] **Step 3: Add `DashboardNextDoseCard`**

Append to `DashboardCards.swift`:

```swift
struct DashboardNextDoseCard: View {
    let compound: Compound
    let dueDate: Date
    let logDose: () -> Void

    var body: some View {
        Button(action: logDose) {
            PepCard {
                HStack(alignment: .top, spacing: Spacing.md) {
                    ZStack {
                        Circle().fill(Color.pepPrimaryMuted)
                        Image(systemName: "pills.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("NEXT DOSE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.pepPrimary)
                            .tracking(0.5)
                        Text(compound.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.pepTextPrimary)
                        Text("\(doseText) • Due \(Self.dueDateFormatter.string(from: dueDate))")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Spacing.sm)

                    Text("Log dose")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.pepPrimary)
                        .clipShape(Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Next dose: \(compound.name), \(doseText), due \(Self.dueDateFormatter.string(from: dueDate)). Log dose."
        )
    }

    private var doseText: String {
        let amount = Self.doseFormatter.string(from: NSNumber(value: compound.doseMg)) ?? "\(compound.doseMg)"
        return "\(amount) \(compound.doseUnit)"
    }

    private static let dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private static let doseFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
```

- [ ] **Step 4: Add `DashboardInsightCard`**

Append to `DashboardCards.swift`:

```swift
struct DashboardInsightCard: View {
    let insight: DashboardInsightSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PepCard {
                HStack(alignment: .top, spacing: Spacing.md) {
                    ZStack {
                        Circle().fill(Color.pepPrimaryMuted)
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("LATEST INSIGHT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.pepPrimary)
                            .tracking(0.5)

                        Text(insight.title ?? insight.emptyMessage ?? "No new insights right now.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let confidenceLabel = insight.confidenceLabel {
                            Text(confidenceLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.pepSuccess)
                        }
                    }

                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.pepTextTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 5: Update the file's `#Preview` and build**

Update the existing `#Preview` at the bottom of `DashboardCards.swift` to also show the two new cards, so visual regressions are catchable in Xcode's canvas:

```swift
#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            DashboardProtocolCard(summary: DashboardSummary.mockPendingStarter.protocol) {}
            DashboardTodayCard(
                today: DashboardSummary.mockPendingStarter.todayCheckin,
                preview: nil
            ) {}
            DashboardNextDoseCard(compound: .fixture, dueDate: Date()) {}
            DashboardInsightCard(
                insight: DashboardInsightSummary(
                    id: nil, title: "Your weight trend is accelerating", severity: "info",
                    emptyMessage: nil, confidence: 0.82
                )
            ) {}
        }
        .padding()
    }
    .background(Color.pepBackground)
}
```

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: BUILD SUCCEEDED (`Compound.fixture` is declared in `peppyTests`, which the main app target can't see — if this errors, replace `.fixture` in the preview with a literal `Compound(id: UUID(), name: "Retatrutide", doseMg: 2.5, doseUnit: "mg", frequency: "weekly", administrationRoute: "subcutaneous", notes: nil)` instead).

- [ ] **Step 6: Run the existing Dashboard card tests to confirm no regressions**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/DashboardViewModelTests test`
Expected: PASS (the protocol-card presentation tests and accessibility test only exercise the extensions/computed properties this task didn't touch).

- [ ] **Step 7: Commit**

```bash
git add ios/peppy/Features/Dashboard/Views/DashboardCards.swift
git commit -m "feat: restyle dashboard cards and add next-dose and insight cards"
```

---

### Task 9: iOS — new DashboardDataViews.swift (weight trend, wearable tiles, activity feed)

**Files:**
- Create: `ios/peppy/Features/Dashboard/Views/DashboardDataViews.swift`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj` (registration — see Global Constraints)

**Interfaces:**
- Produces: `DashboardWeightTrendCard(snapshot:preferredUnit:)`, `DashboardWearableTilesRow(tiles:)`, `DashboardActivityFeed(items:openProtocol:openCheckin:)`.
- Consumes: `DashboardResponseSnapshot`/`DashboardWeightPoint` (existing), `DashboardWearableTiles` (Task 6), `DashboardActivityItem` (Task 6), `WeightUnit` (existing).

This is the one new file in the whole plan. No new business logic beyond simple presentation formatting, so verification is compiling successfully plus the manual QA checklist in Task 10 — the same standard already applied to Task 8's card views.

- [ ] **Step 1: Register the (empty) file in Xcode**

Create `ios/peppy/Features/Dashboard/Views/DashboardDataViews.swift` with just:

```swift
import SwiftUI
import Charts
```

Register it in `project.pbxproj` per the Global Constraints procedure: add a `PBXBuildFile` + `PBXFileReference` pair with fresh IDs, add the file-reference ID to the same group `DashboardCards.swift` is in, and add the build-file ID to the `peppy` target's Sources phase. Verify:

Run: `grep -n "DashboardDataViews.swift" peppy.xcodeproj/project.pbxproj`
Expected: exactly 4 matching lines.

Then confirm the empty file actually compiles as part of the target:

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Add `DashboardWeightTrendCard`**

```swift
struct DashboardWeightTrendCard: View {
    let snapshot: DashboardResponseSnapshot
    let preferredUnit: WeightUnit

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("WEIGHT TREND")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.pepPrimary)
                    .tracking(0.5)

                if let latest = snapshot.weightTrend.last {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preferredUnit.format(kilograms: latest.weightKg))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Color.pepTextPrimary)
                            if let deltaText {
                                Text(deltaText)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(delta ?? 0 <= 0 ? Color.pepSuccess : Color.pepWarning)
                            }
                        }
                        Spacer()
                        sparkline
                            .frame(width: 140, height: 60)
                    }
                } else {
                    Text("Log a few check-ins to see your trend.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var delta: Double? {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return nil }
        let recent = snapshot.weightTrend.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        guard let first = recent.first, let last = recent.last, first.date != last.date else { return nil }
        return last.weightKg - first.weightKg
    }

    private var deltaText: String? {
        guard let delta else { return nil }
        let displayDelta = preferredUnit.displayValue(kilograms: abs(delta))
        let arrow = delta <= 0 ? "\u{2193}" : "\u{2191}"
        return "\(arrow) \(String(format: "%.1f", displayDelta)) \(preferredUnit.symbol) this week"
    }

    private var sparkline: some View {
        let points = snapshot.weightTrend
        let weights = points.map(\.weightKg)
        let lower = (weights.min() ?? 0) - 0.5
        return Chart(points, id: \.date) { point in
            AreaMark(
                x: .value("Day", point.date),
                yStart: .value("Baseline", lower),
                yEnd: .value("Weight", point.weightKg)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.pepPrimary.opacity(0.22), Color.pepPrimary.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Day", point.date),
                y: .value("Weight", point.weightKg)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.pepPrimary)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    .font(.system(size: 9))
                    .foregroundStyle(Color.pepTextTertiary)
            }
        }
        .chartYAxis(.hidden)
    }
}
```

- [ ] **Step 3: Add `DashboardWearableTilesRow`**

```swift
struct DashboardWearableTilesRow: View {
    let tiles: DashboardWearableTiles

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let sleepHours = tiles.sleepHours {
                tile(
                    icon: "moon.fill",
                    tint: Color.pepInfo,
                    label: "SLEEP",
                    value: formattedHours(sleepHours),
                    source: "From Oura"
                )
            }
            if let hrvMs = tiles.hrvMs {
                tile(
                    icon: "heart.fill",
                    tint: Color.pepSuccess,
                    label: "HRV",
                    value: "\(Int(hrvMs.rounded())) ms",
                    source: "From Oura"
                )
            }
            if let readinessScore = tiles.readinessScore {
                tile(
                    icon: "sun.max.fill",
                    tint: Color.pepWarning,
                    label: "READINESS",
                    value: "\(Int(readinessScore.rounded()))%",
                    source: "From Whoop"
                )
            }
        }
    }

    private func formattedHours(_ hours: Double) -> String {
        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        return "\(wholeHours)h \(minutes)m"
    }

    private func tile(icon: String, tint: Color, label: String, value: String, source: String) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.pepTextSecondary)
                        .tracking(0.5)
                }
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.pepTextPrimary)
                Text(source)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.pepTextTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 4: Add `DashboardActivityFeed`**

```swift
struct DashboardActivityFeed: View {
    let items: [DashboardActivityItem]
    let openProtocol: (UUID) -> Void
    let openCheckin: (UUID) -> Void

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(for: item)
                    if index < items.count - 1 {
                        Divider().padding(.vertical, Spacing.sm)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: DashboardActivityItem) -> some View {
        let content = HStack(spacing: Spacing.sm) {
            ZStack {
                Circle().fill(iconTint(for: item.type).opacity(0.15))
                Image(systemName: icon(for: item.type))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconTint(for: item.type))
            }
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)
                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.pepTextSecondary)
            }

            Spacer(minLength: Spacing.sm)

            Text(Self.timeFormatter.string(from: item.timestamp))
                .font(.system(size: 11))
                .foregroundStyle(Color.pepTextTertiary)

            if isNavigable(item) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.pepTextTertiary)
                    .accessibilityHidden(true)
            }
        }

        if item.type == "dose_logged", let protocolID = item.protocolID {
            Button { openProtocol(protocolID) } label: { content }
                .buttonStyle(.plain)
        } else if item.type == "checkin_completed", let checkinID = item.checkinID {
            Button { openCheckin(checkinID) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func isNavigable(_ item: DashboardActivityItem) -> Bool {
        (item.type == "dose_logged" && item.protocolID != nil)
            || (item.type == "checkin_completed" && item.checkinID != nil)
    }

    private func icon(for type: String) -> String {
        switch type {
        case "dose_logged": return "pills.fill"
        case "checkin_completed": return "checkmark.circle.fill"
        case "wearable_synced": return "applewatch"
        case "lab_added": return "testtube.2"
        default: return "circle.fill"
        }
    }

    private func iconTint(for type: String) -> Color {
        switch type {
        case "dose_logged": return .pepPrimary
        case "checkin_completed": return .pepSuccess
        case "wearable_synced": return .pepInfo
        case "lab_added": return .pepWarning
        default: return .pepTextSecondary
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            DashboardWeightTrendCard(
                snapshot: DashboardSummary.mockPendingStarter.responseSnapshot,
                preferredUnit: .pounds
            )
            DashboardWearableTilesRow(
                tiles: DashboardWearableTiles(sleepHours: 7.3, hrvMs: 54, readinessScore: 72)
            )
            DashboardActivityFeed(
                items: [
                    DashboardActivityItem(
                        type: "dose_logged", title: "Dose logged", subtitle: "Retatrutide \u{2022} 4 mg",
                        timestamp: Date(), protocolID: UUID(), checkinID: nil
                    ),
                    DashboardActivityItem(
                        type: "checkin_completed", title: "Check-in completed", subtitle: "Energy, mood, weight",
                        timestamp: Date(), protocolID: nil, checkinID: UUID()
                    ),
                ],
                openProtocol: { _ in },
                openCheckin: { _ in }
            )
        }
        .padding()
    }
    .background(Color.pepBackground)
}
```

- [ ] **Step 5: Build**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add ios/peppy/Features/Dashboard/Views/DashboardDataViews.swift ios/peppy/peppy.xcodeproj/project.pbxproj
git commit -m "feat: add weight trend, wearable tile, and activity feed dashboard views"
```

---

### Task 10: iOS — rewrite DashboardView

**Files:**
- Modify: `ios/peppy/Features/Dashboard/Views/DashboardView.swift`
- Test: `ios/peppy/peppyTests/DashboardViewModelTests.swift` (one navigation-wiring test)

**Interfaces:**
- Consumes: everything produced in Tasks 6–9, plus existing `deps.appState.currentUser?.displayName`, `deps.protocolNavigation`.

- [ ] **Step 1: Write the failing test**

Add to `ios/peppy/peppyTests/DashboardViewModelTests.swift` — this confirms `nextDose`'s `logDoseRoute`-equivalent wiring will have the right IDs available for the view to route with (the view itself isn't unit-testable, but the data it needs is):

```swift
func testNextDoseCarriesEnoughInfoToBuildLogDoseRoute() async {
    let api = MockAPIClient()
    let summary = DashboardSummary(
        generatedAt: DashboardSummary.mockPendingStarter.generatedAt,
        profileStatus: "present",
        protocol: DashboardProtocolSummary(
            id: ProtocolModel.fixture.id,
            status: "active",
            title: ProtocolModel.fixture.name,
            compounds: ["Retatrutide"],
            startDate: ProtocolModel.fixture.startDate
        ),
        todayCheckin: DashboardTodayCheckin(logged: false, checkinId: nil),
        responseSnapshot: DashboardSummary.mockPendingStarter.responseSnapshot,
        insight: DashboardSummary.mockPendingStarter.insight,
        connectedContext: DashboardSummary.mockPendingStarter.connectedContext,
        recentActivity: nil
    )
    api.setMockResponse(summary, for: Endpoint.getDashboardSummary)
    api.setMockResponse([ProtocolModel.fixture], for: Endpoint.getProtocols)
    api.setMockResponse([DoseLog](), for: Endpoint.getDoseLogs(protocolID: ProtocolModel.fixture.id))
    let store = ProtocolStore(api: api)
    let model = DashboardViewModel(api: api, protocolStore: store, hasProfileAttachFailure: false)

    await model.load()

    let route = ProtocolRoute.logDose(
        protocolID: model.state.summary!.protocol.id!,
        compoundID: model.nextDose?.compound.id
    )
    XCTAssertEqual(route, .logDose(protocolID: ProtocolModel.fixture.id, compoundID: Compound.fixture.id))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/DashboardViewModelTests/testNextDoseCarriesEnoughInfoToBuildLogDoseRoute test`
Expected: PASS already, actually — this test only exercises Task 7's `nextDose`, which already exists. Treat this step as a **confirmation** step rather than a red step: if it's already green, that's fine, it means Task 7 laid the groundwork correctly; proceed to Step 3. (Every other part of this task is view code with no independent unit-test surface — its correctness is checked by the build in Step 4 and the manual QA checklist below.)

- [ ] **Step 3: Implement**

Replace the entire contents of `ios/peppy/Features/Dashboard/Views/DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    @Environment(\.dependencies) private var deps
    @State private var model: DashboardViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let state = model?.state {
                        if state.showsProfileSyncRecovery {
                            syncRecoveryCard
                        }

                        if let summary = state.summary {
                            dateRow(for: summary.protocol)

                            if let nextDose = model?.nextDose {
                                DashboardNextDoseCard(
                                    compound: nextDose.compound,
                                    dueDate: nextDose.dueDate
                                ) {
                                    deps.protocolNavigation.show(
                                        .logDose(
                                            protocolID: summary.protocol.id ?? nextDose.compound.id,
                                            compoundID: nextDose.compound.id
                                        )
                                    )
                                }
                            } else {
                                DashboardProtocolCard(summary: summary.protocol) {
                                    deps.protocolNavigation.show(summary.protocol.protocolRoute)
                                }
                            }

                            DashboardTodayCard(
                                today: summary.todayCheckin,
                                preview: model?.todayPreview
                            ) {
                                guard let model else { return }
                                deps.protocolNavigation.showCheckin(model.checkinRoute)
                            }

                            DashboardWeightTrendCard(
                                snapshot: summary.responseSnapshot,
                                preferredUnit: deps.weightUnitPreferences.unit
                            )

                            if let wearableTiles = model?.wearableTiles {
                                DashboardWearableTilesRow(tiles: wearableTiles)
                            }

                            DashboardInsightCard(insight: summary.insight) {
                                if let id = summary.insight.id {
                                    deps.protocolNavigation.showInsight(.detail(id))
                                } else {
                                    deps.protocolNavigation.showInsightsTab()
                                }
                            }

                            if let activity = summary.recentActivity, !activity.isEmpty {
                                DashboardActivityFeed(
                                    items: activity,
                                    openProtocol: { id in
                                        deps.protocolNavigation.show(.detail(id))
                                    },
                                    openCheckin: { id in
                                        deps.protocolNavigation.showCheckin(.detail(id))
                                    }
                                )
                            }
                        } else if state.isLoading {
                            PepLoadingView(message: "Loading your dashboard")
                                .frame(minHeight: 220)
                        } else if let message = state.errorMessage {
                            errorCard(message)
                        }
                    } else {
                        PepLoadingView(message: "Loading your dashboard")
                            .frame(minHeight: 220)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                if model == nil {
                    model = DashboardViewModel(
                        api: deps.api,
                        protocolStore: deps.protocolStore,
                        checkinStore: deps.checkinStore,
                        weightUnitPreferences: deps.weightUnitPreferences,
                        hasProfileAttachFailure: deps.flow.hasProfileAttachFailure,
                        currentDisplayName: { deps.appState.currentUser?.displayName }
                    )
                }
                await model?.load()
            }
            .onChange(of: deps.protocolStore.revision) {
                Task { await model?.refreshIfProtocolStateChanged() }
            }
            .onChange(of: deps.checkinStore.revision) {
                Task { await model?.refreshIfCheckinStateChanged() }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                PeppyLogo(size: 28, showsWordmark: true)
                Text(model?.greetingText ?? "Good day")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.pepTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Here's what's happening with your protocol today.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            Button {
                deps.protocolNavigation.selectedTab = .profile
            } label: {
                ZStack {
                    Circle().fill(Color.pepPrimaryMuted)
                    PeppyLogo(size: 20, showsWordmark: false)
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile")
        }
        .padding(.top, Spacing.sm)
    }

    private func dateRow(for protocolSummary: DashboardProtocolSummary) -> some View {
        HStack {
            Label(Self.dateFormatter.string(from: Date()), systemImage: "calendar")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.pepTextSecondary)

            Spacer()

            if protocolSummary.status != "missing" && protocolSummary.status != "pending_setup" {
                PepBadge(
                    text: "\(protocolSummary.badgeText) \u{2022} \(weekText(for: protocolSummary))",
                    type: protocolSummary.badgeType
                )
            }
        }
    }

    private func weekText(for protocolSummary: DashboardProtocolSummary) -> String {
        guard let startDate = protocolSummary.startDate else { return "Week 1" }
        let elapsed = Date().timeIntervalSince(startDate)
        let week = max(1, Int(elapsed / (7 * 86_400)) + 1)
        return "Week \(week)"
    }

    private var syncRecoveryCard: some View {
        PepCard {
            Label("Finish syncing setup", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
        }
    }

    private func errorCard(_ message: String) -> some View {
        PepCard {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.pepWarning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

extension DashboardProtocolSummary {
    /// Route for the Dashboard protocol card: pending starters resume setup,
    /// configured protocols open detail, and summaries without a server ID
    /// (no protocol yet) go to protocol creation.
    var protocolRoute: ProtocolRoute {
        guard let id else { return .create }
        return status == "pending_setup"
            ? .starterSetup(protocolID: id, compounds: compounds)
            : .detail(id)
    }
}

#Preview {
    let dependencies = Dependencies.mock()
    dependencies.appState.login(
        user: User(id: UUID(), email: "taylor@example.com", displayName: "Taylor Reed", isVerified: true)
    )
    return DashboardView()
        .withDependencies(dependencies)
}
```

Note: `protocolRoute` on `DashboardProtocolSummary` already existed at the bottom of the old `DashboardView.swift` — it's carried over unchanged, just still living in this file.

- [ ] **Step 4: Build and run the full Dashboard test surface**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Expected: BUILD SUCCEEDED.

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:peppyTests/DashboardViewModelTests -only-testing:peppyTests/ProtocolDetailViewModelTests -only-testing:peppyTests/ProtocolNextDueCompoundTests -only-testing:peppyTests/WearableEndpointTests -only-testing:peppyTests/DashboardModelDecodingTests test`
Expected: PASS across every test class touched by this plan.

- [ ] **Step 5: Run the full iOS suite one more time**

Run: `cd ios/peppy && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project peppy.xcodeproj -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
Expected: PASS, no regressions anywhere else in the app (Onboarding, Settings, Protocols, Insights, Checkins are all untouched by this plan).

- [ ] **Step 6: Commit**

```bash
git add ios/peppy/Features/Dashboard/Views/DashboardView.swift ios/peppy/peppyTests/DashboardViewModelTests.swift
git commit -m "feat: rebuild the home dashboard to match the Figma reference"
```

---

## After implementation: manual QA handoff

No simulator screenshotting/UI-driving by the agent. Once all 10 tasks are committed, hand this checklist to Gabriel to verify visually in the simulator (from the spec doc, repeated here for convenience):

- Fresh account (no protocol): header shows create-protocol card, no next dose/week pill, no activity feed.
- Pending-setup starter protocol: finish-setup card shown, week pill hidden.
- Active protocol with logged doses: next-dose card shows the soonest compound, "Log dose" opens the correct compound's log-dose flow.
- Check-in not yet done today vs. already saved — both card states.
- Weight trend with 0, 1, and several check-ins (chart doesn't crash on sparse data).
- No wearable connection: stat-tile row absent.
- Insight present vs. empty-state message; confidence badge only on real insights.
- Activity feed with a mix of dose/check-in rows; tapping each lands on the right destination.
- Greeting matches device clock's time of day and shows the real display name from account registration.
