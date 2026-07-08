# Peppy iOS Protocols Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver Peppy's complete, backend-connected iOS protocol lifecycle with Figma-accurate list, detail, create/edit, compound management, starter setup, dose logging, status management, deletion, and Dashboard routing.

**Architecture:** A shared `ProtocolStore` owns server-backed protocol state and reconciles every mutation. Focused SwiftUI view models own transient form state, while a typed Protocols navigation stack is shared by the tab and Dashboard entry points. Existing protocol APIs are reused; the backend gains only the missing dose-log persistence and endpoints required by the approved workflow.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy, Alembic, Pydantic, pytest, Swift 6, SwiftUI, Observation, XCTest, URLSession-backed `APIClientProtocol`, iOS 17+.

## Global Constraints

- Approved design: `ios/peppy/docs/superpowers/specs/2026-07-08-ios-protocols-workflow-design.md`.
- Visual source of truth: `/Users/gabri/Downloads/Peppy IOS.fig` and its extracted protocol frames.
- Match Figma hierarchy, spacing, typography, colors, borders, icons, controls, sheets, scrolling, and safe areas exactly at the reference viewport.
- Reuse Peppy design components only when their rendered values match Figma; keep protocol-only styling local.
- Connect every included screen and action to real backend APIs.
- Make backend changes only for missing or incomplete contracts required by this workflow.
- Preserve form drafts after validation and network failures.
- Prevent overlapping mutations for the same protocol.
- Support Dynamic Type, VoiceOver, keyboard avoidance, and all supported iPhone sizes.
- Do not commit unless Gabriel explicitly asks. Execute this plan on `IOS_protocol_dev`.

---

## Source Material

- iOS engineering guide: `ios/AGENTS.md`
- Product requirements: `APP_DEV.md`
- Existing protocol API: `backend/app/api/routes/protocols.py`
- Existing protocol service: `backend/app/services/protocol.py`
- Existing iOS contracts: `ios/peppy/Core/Network/APIModels.swift`
- Existing starter flow: `ios/peppy/Features/Protocols/`
- Existing Dashboard route: `ios/peppy/Features/Dashboard/Views/DashboardView.swift`

## File Map

### Backend Create

```text
backend/app/models/dose_log.py
backend/app/api/schemas/dose_log.py
backend/app/services/dose_log.py
backend/app/api/routes/dose_logs.py
backend/alembic/versions/c5d6e7f8a9b0_protocol_dose_logs.py
backend/tests/test_dose_log_service.py
backend/tests/test_dose_log_routes.py
```

### Backend Modify

```text
backend/app/main.py
backend/app/models/__init__.py
backend/app/models/user.py
backend/app/models/protocol.py
```

### iOS Create

```text
ios/peppy/Features/Protocols/Models/ProtocolModels.swift
ios/peppy/Features/Protocols/Models/ProtocolRoute.swift
ios/peppy/Features/Protocols/Stores/ProtocolStore.swift
ios/peppy/Features/Protocols/ViewModels/ProtocolListViewModel.swift
ios/peppy/Features/Protocols/ViewModels/ProtocolDetailViewModel.swift
ios/peppy/Features/Protocols/ViewModels/ProtocolEditorViewModel.swift
ios/peppy/Features/Protocols/ViewModels/CompoundEditorViewModel.swift
ios/peppy/Features/Protocols/ViewModels/DoseLogViewModel.swift
ios/peppy/Features/Protocols/Views/ProtocolsRootView.swift
ios/peppy/Features/Protocols/Views/ProtocolListView.swift
ios/peppy/Features/Protocols/Views/ProtocolRow.swift
ios/peppy/Features/Protocols/Views/ProtocolDetailView.swift
ios/peppy/Features/Protocols/Views/ProtocolEditorView.swift
ios/peppy/Features/Protocols/Views/CompoundEditorView.swift
ios/peppy/Features/Protocols/Views/DoseLogView.swift
ios/peppy/Features/Protocols/Views/ProtocolComponents.swift
ios/peppy/peppyTests/ProtocolStoreTests.swift
ios/peppy/peppyTests/ProtocolListViewModelTests.swift
ios/peppy/peppyTests/ProtocolDetailViewModelTests.swift
ios/peppy/peppyTests/ProtocolEditorViewModelTests.swift
ios/peppy/peppyTests/CompoundEditorViewModelTests.swift
ios/peppy/peppyTests/DoseLogViewModelTests.swift
ios/peppy/peppyTests/ProtocolNavigationTests.swift
```

### iOS Modify

```text
ios/peppy/Core/Network/APIModels.swift
ios/peppy/Core/Network/Endpoint.swift
ios/peppy/Core/Network/MockAPIClient.swift
ios/peppy/App/Dependencies.swift
ios/peppy/App/MainTabView.swift
ios/peppy/Features/Dashboard/Views/DashboardView.swift
ios/peppy/Features/Protocols/ViewModels/StarterProtocolViewModel.swift
ios/peppy/Features/Protocols/Views/StarterProtocolSetupView.swift
ios/peppy/peppyTests/StarterProtocolViewModelTests.swift
ios/peppy/peppy.xcodeproj/project.pbxproj
```

## Task 1: Backend Dose Log Persistence And Contract

**Files:**
- Create the backend dose-log files listed above.
- Modify `backend/app/models/protocol.py`, `backend/app/models/user.py`, `backend/app/models/__init__.py`, and `backend/app/main.py`.

**Interfaces:**
- Produces `DoseLogCreate`, `DoseLogResponse`, `DoseLogService.create`, `DoseLogService.list_for_protocol`.
- Produces `POST /api/v1/dose-logs` and `GET /api/v1/protocols/{protocol_id}/dose-logs`.

- [ ] **Step 1: Write failing service tests**

Create tests proving that a user can log a positive dose against their own protocol compound, list logs newest-first, and cannot log against another user's compound.

```python
async def test_create_dose_log(db_session, user, protocol):
    compound = protocol.compounds[0]
    result = await DoseLogService(db_session).create(
        user_id=user.id,
        protocol_id=protocol.id,
        compound_id=compound.id,
        dose=2.5,
        unit="mg",
        administered_at=datetime(2026, 7, 8, 14, 30, tzinfo=timezone.utc),
        route="subcutaneous",
        notes="Left abdomen",
    )
    assert result.compound_id == compound.id
    assert result.dose == 2.5
    assert result.unit == "mg"
```

- [ ] **Step 2: Run the focused service tests**

```bash
cd backend
.venv/bin/python -m pytest tests/test_dose_log_service.py -q
```

Expected: collection fails because `DoseLogService` does not exist.

- [ ] **Step 3: Add model, relationships, schema, and service**

Use this persistence shape:

```python
class DoseLog(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "dose_logs"

    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False, index=True)
    protocol_id = Column(GUID(), ForeignKey("protocols.id"), nullable=False, index=True)
    compound_id = Column(GUID(), ForeignKey("compounds.id"), nullable=False, index=True)
    dose = Column(Float, nullable=False)
    unit = Column(String(20), nullable=False)
    administered_at = Column(DateTime(timezone=True), nullable=False, index=True)
    route = Column(String(50), nullable=False)
    notes = Column(Text, nullable=True)
```

`DoseLogService.create` must load the protocol and compound through ownership-scoped queries, verify the compound belongs to the supplied protocol, reject `dose <= 0`, add the row, commit, refresh, and return it. `list_for_protocol` must verify ownership and order by `administered_at DESC`.

- [ ] **Step 4: Add the Alembic migration**

Create `c5d6e7f8a9b0_protocol_dose_logs.py` with `down_revision = "b4c5d6e7f8a9"`, the table above, foreign keys with `ondelete="CASCADE"`, and indexes for `user_id`, `protocol_id`, `compound_id`, and `administered_at`.

- [ ] **Step 5: Write failing route tests**

Verify:

```python
response = client.post(
    "/api/v1/dose-logs",
    headers=auth_headers,
    json={
        "protocol_id": str(protocol.id),
        "compound_id": str(compound.id),
        "dose": 2.5,
        "unit": "mg",
        "administered_at": "2026-07-08T14:30:00Z",
        "route": "subcutaneous",
        "notes": None,
    },
)
assert response.status_code == 201
assert response.json()["dose"] == 2.5
```

Also test list, invalid dose `422`, mismatched compound `400`, foreign protocol `404`, and unauthorized `401`.

- [ ] **Step 6: Add and register the routes**

Implement:

```python
@router.post("/", response_model=DoseLogResponse, status_code=201)
async def create_dose_log(
    payload: DoseLogCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> DoseLogResponse:
    try:
        return await DoseLogService(db).create(
            user_id=current_user.id,
            protocol_id=payload.protocol_id,
            compound_id=payload.compound_id,
            dose=payload.dose,
            unit=payload.unit,
            administered_at=payload.administered_at,
            route=payload.route,
            notes=payload.notes,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

@router.get(
    "/{protocol_id}/dose-logs",
    response_model=list[DoseLogResponse],
)
async def list_protocol_dose_logs(
    protocol_id: UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[DoseLogResponse]:
    logs = await DoseLogService(db).list_for_protocol(
        user_id=current_user.id,
        protocol_id=protocol_id,
    )
    if logs is None:
        raise HTTPException(status_code=404, detail="Protocol not found")
    return logs
```

Register the create router at `/api/v1/dose-logs`; add the protocol history route to the protocols router or register an ownership-equivalent nested router.

- [ ] **Step 7: Run backend verification**

```bash
cd backend
.venv/bin/python -m pytest \
  tests/test_dose_log_service.py \
  tests/test_dose_log_routes.py \
  tests/test_protocol_service.py \
  tests/test_protocol_routes.py -q
```

Expected: all selected tests pass.

## Task 2: Complete iOS Protocol Network Contracts

**Files:**
- Modify `ios/peppy/Core/Network/APIModels.swift`.
- Modify `ios/peppy/Core/Network/Endpoint.swift`.
- Modify `ios/peppy/Core/Network/MockAPIClient.swift`.
- Create `ios/peppy/Features/Protocols/Models/ProtocolModels.swift`.
- Test through `ios/peppy/peppyTests/ProtocolStoreTests.swift`.

**Interfaces:**
- Produces complete `Compound`, `CreateCompoundRequest`, `UpdateCompoundRequest`, `DoseLog`, and `CreateDoseLogRequest`.
- Produces all endpoint cases consumed by the store.

- [ ] **Step 1: Write failing encoding and endpoint tests**

Assert that compound payloads encode `dose_mg`, `dose_unit`, `administration_route`, and `notes`; dose payloads encode IDs and `administered_at`; endpoint paths and methods match the FastAPI routes.

```swift
func testAddCompoundEndpoint() {
    let id = UUID()
    let endpoint = Endpoint.addCompound(protocolID: id, .fixture)
    XCTAssertEqual(endpoint.path, "/protocols/\(id)/compounds")
    XCTAssertEqual(endpoint.method, .post)
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project ios/peppy/peppy.xcodeproj \
  -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:peppyTests/ProtocolStoreTests
```

Expected: compilation fails because the new endpoint cases and request types do not exist.

- [ ] **Step 3: Expand API models**

The decoded compound contract must include:

```swift
struct Compound: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let doseMg: Double
    let doseUnit: String
    let frequency: String
    let administrationRoute: String
    let notes: String?
}
```

Add create/update request forms with matching coding keys. Add:

```swift
struct DoseLog: Codable, Identifiable, Hashable {
    let id: UUID
    let protocolID: UUID
    let compoundID: UUID
    let dose: Double
    let unit: String
    let administeredAt: Date
    let route: String
    let notes: String?
}
```

- [ ] **Step 4: Add endpoint cases**

Add:

```swift
case addCompound(protocolID: UUID, CreateCompoundRequest)
case updateCompound(id: UUID, UpdateCompoundRequest)
case removeCompound(id: UUID)
case getDoseLogs(protocolID: UUID)
case createDoseLog(CreateDoseLogRequest)
```

Wire exact paths, HTTP methods, and bodies. Keep `executeVoid` for `204` delete responses.

- [ ] **Step 5: Improve mock request assertions**

Make `Endpoint` expose testable request identity without relying only on duplicate paths. Add `method` and endpoint-case assertions to tests; retain `requestLog` so mutation order can be verified.

- [ ] **Step 6: Run focused tests**

Run the Task 2 command. Expected: all selected tests pass.

## Task 3: Shared Protocol Store

**Files:**
- Create `ios/peppy/Features/Protocols/Stores/ProtocolStore.swift`.
- Create `ios/peppy/peppyTests/ProtocolStoreTests.swift`.
- Modify `ios/peppy/App/Dependencies.swift`.

**Interfaces:**
- Produces `ProtocolStore`.
- Consumed by every protocol view model and Dashboard integration.

- [ ] **Step 1: Write failing store tests**

Cover list load, detail load, create replacement, metadata update, add/update/remove compound reconciliation, activate/deactivate, delete, dose creation, stale request protection, and preserving loaded content on refresh failure.

```swift
func testDeleteRemovesProtocolAndClearsSelection() async {
    let api = MockAPIClient()
    api.setMockResponse([Protocol.fixture], for: "/protocols")
    let store = ProtocolStore(api: api)
    await store.loadProtocols()
    await store.select(Protocol.fixture.id)

    let deleted = await store.deleteSelected()

    XCTAssertTrue(deleted)
    XCTAssertTrue(store.protocols.isEmpty)
    XCTAssertNil(store.selectedProtocol)
}
```

- [ ] **Step 2: Run tests and verify failure**

Expected: compilation fails because `ProtocolStore` is missing.

- [ ] **Step 3: Implement store state**

Expose:

```swift
@MainActor @Observable
final class ProtocolStore {
    private(set) var protocols: [Protocol] = []
    private(set) var selectedProtocol: Protocol?
    private(set) var doseLogs: [DoseLog] = []
    private(set) var isLoading = false
    private(set) var mutatingProtocolID: UUID?
    var errorMessage: String?

    func loadProtocols(force: Bool = false) async
    func select(_ id: UUID) async
    func create(_ request: CreateProtocolRequest) async -> Protocol?
    func update(id: UUID, request: UpdateProtocolRequest) async -> Protocol?
    func addCompound(protocolID: UUID, request: CreateCompoundRequest) async -> Compound?
    func updateCompound(id: UUID, request: UpdateCompoundRequest) async -> Compound?
    func removeCompound(id: UUID, protocolID: UUID) async -> Bool
    func activate(id: UUID) async -> Bool
    func deactivate(id: UUID) async -> Bool
    func deleteSelected() async -> Bool
    func loadDoseLogs(protocolID: UUID) async
    func logDose(_ request: CreateDoseLogRequest) async -> DoseLog?
}
```

Use a monotonically increasing load token to prevent stale list/detail requests overwriting newer responses. Reject a second mutation when `mutatingProtocolID` matches.

- [ ] **Step 4: Inject one shared store**

Add `let protocolStore: ProtocolStore` to `Dependencies`, initialized from the same live or mock API client.

- [ ] **Step 5: Run store and dependency tests**

Expected: all selected tests pass.

## Task 4: Protocol And Compound Editor View Models

**Files:**
- Create `ProtocolEditorViewModel.swift`, `CompoundEditorViewModel.swift`.
- Create their matching test files.

**Interfaces:**
- Consumes `ProtocolStore`.
- Produces validated drafts and requests for create/edit and compound create/edit.

- [ ] **Step 1: Write failing editor tests**

Test trimmed names, positive numeric dose, required units/routes/frequency, start/end ordering, at least one compound, edit prepopulation, request construction, submitting lock, and draft retention after error.

```swift
func testProtocolRequiresOneValidCompound() {
    let model = ProtocolEditorViewModel(mode: .create, store: store)
    model.name = "Retatrutide Titration"
    model.startDate = Date()
    XCTAssertFalse(model.canSubmit)
    XCTAssertEqual(model.validation.nameOrForm, "Add at least one compound.")
}
```

- [ ] **Step 2: Run tests and verify failure**

Expected: compilation fails because the editor types are missing.

- [ ] **Step 3: Implement compound draft**

```swift
struct CompoundDraft: Identifiable, Equatable {
    var id = UUID()
    var persistedID: UUID?
    var name = ""
    var doseText = ""
    var unit = "mg"
    var frequency = ""
    var route = "subcutaneous"
    var notes = ""
}
```

`CompoundEditorViewModel` validates and returns a `CompoundDraft`; persisted edits call the matching store endpoint only from the owning detail flow.

- [ ] **Step 4: Implement protocol editor**

Use `enum ProtocolEditorMode { case create; case edit(Protocol) }`. Create mode sends one `CreateProtocolRequest` containing all drafts. Edit mode updates metadata, then applies compound add/update/remove operations only after metadata succeeds; retain the draft and surface the first failed operation.

- [ ] **Step 5: Run focused editor tests**

Expected: all selected tests pass.

## Task 5: Protocol List And Root Navigation

**Files:**
- Create `ProtocolRoute.swift`, `ProtocolsRootView.swift`, `ProtocolListView.swift`, `ProtocolRow.swift`, `ProtocolListViewModel.swift`, and its tests.
- Modify `ios/peppy/App/MainTabView.swift`.
- Modify `ios/peppy/peppy.xcodeproj/project.pbxproj`.

**Interfaces:**
- Produces typed Protocols navigation.
- Consumes `ProtocolStore`.

- [ ] **Step 1: Write failing list state tests**

Cover first load, loaded list, empty state, retry state, and refresh failure retaining loaded rows.

- [ ] **Step 2: Implement typed routes**

```swift
enum ProtocolRoute: Hashable {
    case detail(UUID)
    case create
    case edit(UUID)
    case addCompound(UUID)
    case editCompound(protocolID: UUID, compoundID: UUID)
    case logDose(protocolID: UUID, compoundID: UUID?)
    case starterSetup(protocolID: UUID, compounds: [String])
}
```

- [ ] **Step 3: Replace `ProtocolsTab` placeholder**

`ProtocolsRootView` owns `NavigationStack(path:)`, renders `ProtocolListView`, and registers every route destination. It receives the shared store from `Dependencies`.

- [ ] **Step 4: Build the Figma list**

Implement the reference title, summary rows, status treatment, compound/schedule content, create action, background, scrolling, and bottom-tab relationship. Add loading, empty, error/retry, and pull-to-refresh states using the closest Figma composition.

- [ ] **Step 5: Add Xcode project references**

Add every newly created Swift source and test file to the correct group and target build phase. Do not alter unrelated PBX identifiers or workspace user-state files.

- [ ] **Step 6: Run list tests and build**

Expected: focused tests pass and the app target builds.

## Task 6: Protocol Detail And Lifecycle Actions

**Files:**
- Create `ProtocolDetailViewModel.swift`, `ProtocolDetailView.swift`, `ProtocolComponents.swift`, and detail tests.

**Interfaces:**
- Consumes `ProtocolStore` and typed routes.
- Produces edit, compound, dose, activation, deactivation, and deletion intents.

- [ ] **Step 1: Write failing detail tests**

Test initial selection, dose history loading, action availability by status, mutation locking, confirmation outcomes, failed destructive action retention, and successful delete navigation intent.

- [ ] **Step 2: Implement detail view model**

Expose a presentation state derived from the selected protocol and store. Do not duplicate protocol data in a second mutable copy.

- [ ] **Step 3: Build the Figma detail screen**

Match the "Retatrutide Titration" frame: navigation, status, compound schedule, progress/information sections, dose activity, log-dose action, and management menu. Use confirmation dialogs for deactivate and delete; make delete destructive.

- [ ] **Step 4: Wire lifecycle mutations**

Activation and deactivation reconcile store state. Successful delete removes the detail route. Errors remain visible without dismissing the screen.

- [ ] **Step 5: Run detail tests and build**

Expected: focused tests pass and detail compiles in the app target.

## Task 7: Figma Protocol And Compound Editors

**Files:**
- Create `ProtocolEditorView.swift`, `CompoundEditorView.swift`.
- Use the Task 4 view models.

**Interfaces:**
- Consumes editor view models and store.
- Produces saved protocol/compound state.

- [ ] **Step 1: Build create/edit protocol composition**

Match the create-protocol frame exactly. Use a scrollable form, Figma labels and controls, compound summary rows, add-compound action, and stable bottom save action with keyboard avoidance.

- [ ] **Step 2: Build add/edit compound composition**

Match the add-compound frame exactly. Use keyboard-appropriate numeric input, Figma selection controls for unit/frequency/route, inline field validation, and a disabled/submitting save state.

- [ ] **Step 3: Wire draft navigation**

Creating a compound returns a draft to the unsaved protocol editor. Adding a compound from detail persists through the store. Editing a persisted compound prepopulates all values and reconciles detail on success.

- [ ] **Step 4: Add compound removal**

Require confirmation, disable removal for the final compound, and surface the backend invariant error without losing editor state.

- [ ] **Step 5: Run editor tests and build**

Expected: Task 4 tests remain green and all editor views compile.

## Task 8: Dose Logging UI And Behavior

**Files:**
- Create `DoseLogViewModel.swift`, `DoseLogView.swift`, and dose-log tests.

**Interfaces:**
- Consumes `ProtocolStore.logDose`.
- Produces one persisted dose and refreshed detail history.

- [ ] **Step 1: Write failing dose tests**

Test preselected context, positive dose, required date/time/unit/route, optional notes, request construction, duplicate submission blocking, success dismissal, and draft retention on failure.

```swift
func testSubmissionUsesSelectedContext() async {
    let model = DoseLogViewModel(
        protocol: .fixture,
        compound: .fixture,
        store: store
    )
    model.doseText = "2.5"
    model.administeredAt = fixtureDate
    XCTAssertTrue(await model.submit())
    XCTAssertEqual(api.requestLog.last?.path, "/dose-logs")
}
```

- [ ] **Step 2: Implement the view model**

Build `CreateDoseLogRequest` from normalized form values and call the store once. Keep `isSubmitting` true for the whole request.

- [ ] **Step 3: Build the Figma log-dose sheet**

Match the extracted log-dose frame exactly, including protocol/compound context, date and time controls, dose/unit, route, optional notes, validation, and primary action.

- [ ] **Step 4: Reconcile success**

On success, prepend or reload dose history, refresh selected detail, dismiss the sheet, and notify Dashboard refresh coordination.

- [ ] **Step 5: Run focused tests and build**

Expected: dose tests pass and the sheet compiles.

## Task 9: Starter Setup Reuse And Figma Match

**Files:**
- Modify starter view model, view, and tests.

**Interfaces:**
- Consumes `ProtocolStore` instead of directly creating parallel state.
- Produces an activated protocol visible across Dashboard and Protocols.

- [ ] **Step 1: Extend failing starter tests**

Test activation request fields, mutation lock, store reconciliation, Dashboard refresh signal, draft retention, and server error rendering.

- [ ] **Step 2: Refactor starter activation**

Keep the current activation payload and validation semantics, but route success through `ProtocolStore` so list/detail state updates immediately.

- [ ] **Step 3: Rebuild the starter screen against Figma**

Match "Set up your first protocol" exactly. Share low-level field controls with the compound editor only where visual and behavioral requirements are identical.

- [ ] **Step 4: Run starter and store tests**

Expected: all selected tests pass.

## Task 10: Dashboard And Cross-Tab Routing

**Files:**
- Modify `MainTabView.swift`, `DashboardView.swift`, `Dependencies.swift`.
- Create `ProtocolNavigationTests.swift`.

**Interfaces:**
- Produces shared selected tab and pending protocol route.
- Consumes the same `ProtocolsRootView` destinations as the Protocols tab.

- [ ] **Step 1: Write failing routing tests**

Verify pending setup routes to starter setup, configured protocol routes to detail, route selection switches to `.protocols`, and successful protocol mutations trigger Dashboard reload.

- [ ] **Step 2: Add navigation intent**

Use an observable coordinator owned by `MainTabView`:

```swift
@MainActor @Observable
final class ProtocolNavigationCoordinator {
    var path: [ProtocolRoute] = []
    func show(_ route: ProtocolRoute) {
        path = [route]
    }
}
```

Inject one coordinator through `Dependencies` or an environment value. `MainTabView` switches `selectedTab` before applying a Dashboard-originated route.

- [ ] **Step 3: Update Dashboard card behavior**

Pending setup emits `.starterSetup`; configured protocols with IDs emit `.detail`. Preserve the approved Dashboard visuals.

- [ ] **Step 4: Add mutation refresh signaling**

Use a store revision counter or explicit successful-mutation callback observed by Dashboard. Do not reload on failed mutations.

- [ ] **Step 5: Run navigation, dashboard, and starter tests**

Expected: all selected tests pass.

## Task 11: Full Contract, Accessibility, And Visual QA

**Files:**
- Modify only protocol files with verified discrepancies.
- Update tests only for confirmed acceptance behavior.

**Interfaces:**
- Validates the complete approved feature.

- [ ] **Step 1: Run backend migration and suite**

```bash
cd backend
.venv/bin/alembic upgrade head
.venv/bin/python -m pytest -q
```

Expected: migration succeeds and the full backend suite passes. If unrelated baseline failures exist, record their exact test names and prove all protocol/dose tests pass independently.

- [ ] **Step 2: Run the complete iOS test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project ios/peppy/peppy.xcodeproj \
  -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Run a clean simulator build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild clean build -project ios/peppy/peppy.xcodeproj \
  -scheme peppy -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Exercise the real end-to-end workflow**

Verify list, detail, create, edit, add/edit/remove compound, log dose, starter activation, deactivate, reactivate, delete, Dashboard entry, refresh, retry, validation, and destructive failures against the local backend.

- [ ] **Step 5: Capture same-viewport screenshots**

Capture iPhone simulator screenshots for:

```text
Protocols list
Protocol detail
Create protocol
Add compound
Log dose
Starter protocol setup
Dashboard pending and configured protocol states
```

Compare each against the corresponding extracted Figma frame at `853x1844`. Correct every unexplained hierarchy, spacing, typography, color, border, icon, control, sheet, and safe-area difference.

- [ ] **Step 6: Verify adaptive and accessibility behavior**

Inspect at least one smaller and one larger supported iPhone. Enable a large Dynamic Type size and VoiceOver inspection. Verify no overlap, clipping, inaccessible icon control, keyboard obstruction, broken scrolling, or missing destructive semantics.

- [ ] **Step 7: Run final regression verification**

Repeat the focused backend protocol/dose tests, full iOS tests, and clean build after visual corrections. Review `git diff --check` and confirm only intended files changed.

## Execution Order

Tasks are intentionally sequential because each later task consumes contracts from earlier tasks:

```text
Backend dose contract
  -> iOS network models/endpoints
  -> shared store
  -> editor state
  -> list/root navigation
  -> detail lifecycle
  -> editors
  -> dose UI
  -> starter integration
  -> Dashboard routing
  -> full visual and functional QA
```

Use `superpowers:test-driven-development` for each implementation task, `superpowers:systematic-debugging` for any unexpected failure, and `superpowers:verification-before-completion` before reporting completion.
