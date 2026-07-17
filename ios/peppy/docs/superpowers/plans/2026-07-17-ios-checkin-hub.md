# Peppy iOS Check-in Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the one-use iOS check-in form with a server-backed Check-in Hub that shows today, history, editable details, a connected Home preview, and pounds-first weight entry with a persistent lb/kg preference.

**Architecture:** Add one shared `CheckinStore` to `Dependencies` so Check-in and Home observe the same records and mutation revision. Keep presentation derivation in `CheckinHubViewModel`, form normalization in `CheckinViewModel`, and cross-tab intent in the existing navigation coordinator. Preserve the existing backend routes, while correcting PATCH semantics so explicit JSON `null` clears an optional value and an omitted key leaves it unchanged.

**Tech Stack:** Swift 5, SwiftUI, Observation, Foundation, XCTest, Xcode 26.6, iOS 17 minimum deployment target, Python 3.11, FastAPI, Pydantic v2, SQLAlchemy async, pytest

## Global Constraints

- Reuse Peppy's existing Figma-derived colors, typography, spacing, `PepCard`, `PepButton`, `PepEmptyState`, `PepLoadingView`, and toast patterns.
- Do not add third-party dependencies.
- The Check-in tab root is the hub; creation is not the root screen.
- Only today's check-in is editable. Historical check-ins are read-only.
- Do not add check-in deletion, historical editing, pagination, new trend charts, insight changes, or a More-tab unit setting.
- The backend and API continue storing and returning weight in kilograms.
- Pounds are the default when no stored Check-in preference or onboarding preference exists.
- The inline lb/kg selection persists on-device and updates Home, hub, history, detail, and editor display immediately.
- List at most the 100 records returned by the backend's current default response, newest first.
- Preserve loaded records during refresh failures and preserve editor input during mutation failures.
- Keep all networking behind `APIClientProtocol`; views never call endpoints directly.
- Keep all new Swift files registered in the `peppy` app target. The project uses explicit PBX file references, so headless execution must update `ios/peppy/peppy.xcodeproj/project.pbxproj` carefully and must not disturb unrelated project entries.
- Follow test-driven development: every behavior task observes a focused failing test before production changes.
- Preserve the unrelated user-owned `.DS_Store` worktree modification.

---

### Task 1: Make Existing Check-in PATCH Semantics Support Clearing Values

**Files:**
- Create: `backend/tests/test_checkin_updates.py`
- Modify: `backend/app/services/checkin.py:78-151`
- Modify: `backend/app/api/routes/checkins.py:188-229`

**Interfaces:**
- Consumes: `PATCH /api/v1/checkins/{checkin_id}`, `CheckinUpdate.model_dump(exclude_unset=True)`, `CheckinService.get_by_id(checkin_id:user_id:)`.
- Produces: `CheckinService.update(checkin:changes:) -> Checkin`, where an omitted key preserves the column and an explicitly present `None` clears the column.

- [ ] **Step 1: Write route-level failing tests for omitted versus explicit-null fields**

Create `backend/tests/test_checkin_updates.py`:

```python
import pytest


@pytest.fixture
async def auth_headers(client):
    await client.post(
        "/api/v1/auth/register",
        json={"email": "checkin_update@example.com", "password": "password123"},
    )
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "checkin_update@example.com", "password": "password123"},
    )
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def create_checkin(client, auth_headers):
    response = await client.post(
        "/api/v1/checkins",
        headers=auth_headers,
        json={
            "date": "2026-07-17",
            "weight_kg": 74.8,
            "energy_level": 7,
            "mood": 8,
            "notes": "Original note",
        },
    )
    assert response.status_code == 201
    return response.json()


async def test_patch_omitted_fields_preserve_existing_values(client, auth_headers):
    created = await create_checkin(client, auth_headers)

    response = await client.patch(
        f"/api/v1/checkins/{created['id']}",
        headers=auth_headers,
        json={"energy_level": 9},
    )

    assert response.status_code == 200
    assert response.json()["energy_level"] == 9
    assert response.json()["weight_kg"] == 74.8
    assert response.json()["notes"] == "Original note"


async def test_patch_explicit_null_clears_optional_values(client, auth_headers):
    created = await create_checkin(client, auth_headers)

    response = await client.patch(
        f"/api/v1/checkins/{created['id']}",
        headers=auth_headers,
        json={"weight_kg": None, "notes": None, "mood": None},
    )

    assert response.status_code == 200
    assert response.json()["weight_kg"] is None
    assert response.json()["notes"] is None
    assert response.json()["mood"] is None
    assert response.json()["energy_level"] == 7
```

- [ ] **Step 2: Run the new backend tests and verify the explicit-null case fails**

Run from `backend/`:

```bash
pytest tests/test_checkin_updates.py -v
```

Expected: `test_patch_omitted_fields_preserve_existing_values` passes and `test_patch_explicit_null_clears_optional_values` fails because the current service ignores every `None` argument.

- [ ] **Step 3: Replace positional optional arguments with an explicit changes dictionary**

In `backend/app/services/checkin.py`, replace `CheckinService.update` with:

```python
    async def update(self, checkin: Checkin, changes: dict[str, object]) -> Checkin:
        """Apply only provided fields; explicit None clears nullable columns."""
        if "date" in changes:
            checkin_date = changes["date"]
            if checkin_date is not None and checkin_date != checkin.date:
                existing = await self.get_by_date(checkin.user_id, checkin_date)
                if existing and existing.id != checkin.id:
                    raise ValueError(f"Check-in already exists for {checkin_date}")
                checkin.date = checkin_date

        mutable_fields = (
            "weight_kg",
            "energy_level",
            "sleep_quality",
            "appetite_level",
            "mood",
            "nausea",
            "injection_site_reaction",
            "fatigue",
            "headache",
            "gi_issues",
            "notes",
        )
        for field in mutable_fields:
            if field in changes:
                setattr(checkin, field, changes[field])

        await self.db.commit()
        await self.db.refresh(checkin)
        return checkin
```

In `backend/app/api/routes/checkins.py`, replace the keyword-by-keyword call with:

```python
    try:
        updated = await service.update(
            checkin,
            update_data.model_dump(exclude_unset=True),
        )
        return updated
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )
```

Do not change `CheckinUpdate`, the URL, response model, ownership check, or conflict status.

- [ ] **Step 4: Re-run focused and full backend tests**

Run from `backend/`:

```bash
pytest tests/test_checkin_updates.py -v
pytest -q
```

Expected: both focused tests pass and the full backend suite completes with zero failures.

- [ ] **Step 5: Commit the PATCH semantics fix**

```bash
git add backend/app/services/checkin.py backend/app/api/routes/checkins.py backend/tests/test_checkin_updates.py
git commit -m "fix: allow clearing check-in fields"
```

---

### Task 2: Add iOS Update Networking, Conflict Errors, and Weight Preferences

**Files:**
- Create: `ios/peppy/Core/Storage/WeightUnitPreferenceStore.swift`
- Modify: `ios/peppy/Core/Network/APIModels.swift:494-724`
- Modify: `ios/peppy/Core/Network/Endpoint.swift:35-215`
- Modify: `ios/peppy/Core/Network/APIError.swift:3-46`
- Modify: `ios/peppy/Core/Network/APIClient.swift:55-94`
- Modify: `ios/peppy/App/Dependencies.swift:3-103`
- Modify: `ios/peppy/peppyTests/CheckinViewModelTests.swift`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: existing `WeightUnit`, `OnboardingDraft.preferredWeightUnit`, `CreateCheckinRequest`, `Checkin`, `APIClientProtocol`, `UserDefaults`.
- Produces: `UpdateCheckinRequest`, `Endpoint.updateCheckin(id:request:)`, `APIError.conflict(String)`, `WeightUnitPreferences.unit`, `WeightUnitPreferences.select(_:)`, `WeightUnit.kilograms(from:)`, `WeightUnit.displayValue(kilograms:)`, and `WeightUnit.format(kilograms:)`.

- [ ] **Step 1: Add failing request, conflict, conversion, default, seed, and persistence tests**

Append these tests to `CheckinViewModelTests.swift`:

```swift
func testUpdateRequestEncodesNullForClearedFields() throws {
    let request = UpdateCheckinRequest(
        date: Date(timeIntervalSince1970: 1_788_000_000),
        weightKg: nil,
        energyLevel: 9,
        sleepQuality: nil,
        appetiteLevel: nil,
        mood: nil,
        nausea: nil,
        injectionSiteReaction: nil,
        fatigue: nil,
        headache: nil,
        giIssues: nil,
        notes: nil
    )

    let object = try XCTUnwrap(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
    )
    XCTAssertTrue(object["weight_kg"] is NSNull)
    XCTAssertTrue(object["notes"] is NSNull)
    XCTAssertEqual(object["energy_level"] as? Int, 9)
}

func testUpdateEndpointUsesPatchAndCheckinIdentifier() {
    let id = UUID()
    let request = UpdateCheckinRequest.fixture
    let endpoint = Endpoint.updateCheckin(id: id, request)

    XCTAssertEqual(endpoint.method, .patch)
    XCTAssertEqual(endpoint.path, "/checkins/\(id)")
}

func testConflictErrorPreservesServerMessage() {
    XCTAssertEqual(
        APIError.conflict("Check-in already exists for 2026-07-17").userMessage,
        "Check-in already exists for 2026-07-17"
    )
}

func testWeightUnitConversionsAndFormatting() {
    XCTAssertEqual(WeightUnit.pounds.kilograms(from: 165), 74.84274105, accuracy: 0.000001)
    XCTAssertEqual(WeightUnit.pounds.displayValue(kilograms: 74.84274105), 165, accuracy: 0.000001)
    XCTAssertEqual(WeightUnit.pounds.format(kilograms: 74.84274105), "165.0 lb")
    XCTAssertEqual(WeightUnit.kilograms.format(kilograms: 74.8), "74.8 kg")
}

func testWeightPreferenceDefaultsToPoundsAndPersistsSelection() {
    let suite = "WeightUnitPreferencesTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = WeightUnitPreferences(defaults: defaults)
    XCTAssertEqual(first.unit, .pounds)
    first.select(.kilograms)

    let second = WeightUnitPreferences(defaults: defaults)
    XCTAssertEqual(second.unit, .kilograms)
}

func testWeightPreferenceUsesOnboardingSeedOnlyWhenNoSavedSelectionExists() {
    let suite = "WeightUnitPreferencesSeedTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let seeded = WeightUnitPreferences(defaults: defaults, seed: { .kilograms })
    XCTAssertEqual(seeded.unit, .kilograms)
    seeded.select(.pounds)

    let reloaded = WeightUnitPreferences(defaults: defaults, seed: { .kilograms })
    XCTAssertEqual(reloaded.unit, .pounds)
}
```

Add this test-only fixture below the test class:

```swift
private extension UpdateCheckinRequest {
    static let fixture = UpdateCheckinRequest(
        date: Date(timeIntervalSince1970: 1_788_000_000),
        weightKg: 74.8,
        energyLevel: 7,
        sleepQuality: nil,
        appetiteLevel: nil,
        mood: 8,
        nausea: nil,
        injectionSiteReaction: nil,
        fatigue: nil,
        headache: nil,
        giIssues: nil,
        notes: nil
    )
}
```

- [ ] **Step 2: Register the new preference file and verify the focused tests fail**

Add `WeightUnitPreferenceStore.swift` to the `Core/Storage` PBX group and the `peppy` Sources phase. Use Xcode's Add Files action when available. In a headless session, add one `PBXFileReference`, one `PBXBuildFile`, one Storage-group child, and one app Sources entry with unique IDs; verify the filename appears exactly once in each relevant section.

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:peppyTests/CheckinViewModelTests \
  test
```

Expected: compilation fails because the update request, conflict error, unit helpers, and preference type do not exist.

- [ ] **Step 3: Add explicit-null update encoding and the PATCH endpoint**

Make `Checkin` equatable:

```swift
struct Checkin: Codable, Identifiable, Equatable {
```

Add this model after `CreateCheckinRequest`:

```swift
struct UpdateCheckinRequest: Encodable, Equatable {
    let date: Date
    let weightKg: Double?
    let energyLevel: Int?
    let sleepQuality: Int?
    let appetiteLevel: Int?
    let mood: Int?
    let nausea: Int?
    let injectionSiteReaction: Int?
    let fatigue: Int?
    let headache: Int?
    let giIssues: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case date, mood, nausea, fatigue, headache, notes
        case weightKg = "weight_kg"
        case energyLevel = "energy_level"
        case sleepQuality = "sleep_quality"
        case appetiteLevel = "appetite_level"
        case injectionSiteReaction = "injection_site_reaction"
        case giIssues = "gi_issues"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.dateFormatter.string(from: date), forKey: .date)
        try container.encode(weightKg, forKey: .weightKg)
        try container.encode(energyLevel, forKey: .energyLevel)
        try container.encode(sleepQuality, forKey: .sleepQuality)
        try container.encode(appetiteLevel, forKey: .appetiteLevel)
        try container.encode(mood, forKey: .mood)
        try container.encode(nausea, forKey: .nausea)
        try container.encode(injectionSiteReaction, forKey: .injectionSiteReaction)
        try container.encode(fatigue, forKey: .fatigue)
        try container.encode(headache, forKey: .headache)
        try container.encode(giIssues, forKey: .giIssues)
        try container.encode(notes, forKey: .notes)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
```

Add `case updateCheckin(id: UUID, UpdateCheckinRequest)` to `Endpoint`, map it to `/checkins/{id}`, `.patch`, and its request body. Add a 409 response mapping in `APIClient.performRequest`:

```swift
case 409:
    if let response = try? decoder.decode(APIErrorResponse.self, from: data) {
        throw APIError.conflict(response.errorMessage)
    }
    throw APIError.conflict("A check-in already exists for this date.")
```

Add `case conflict(String)` to `APIError`, return the associated message from `userMessage`, and include associated-string equality in `APIError.==`.

- [ ] **Step 4: Implement one shared weight conversion and preference type**

Create `WeightUnitPreferenceStore.swift`:

```swift
import Foundation
import Observation

extension WeightUnit {
    private static let poundsPerKilogram = 2.2046226218

    var symbol: String { self == .pounds ? "lb" : "kg" }

    func kilograms(from displayValue: Double) -> Double {
        self == .pounds ? displayValue / Self.poundsPerKilogram : displayValue
    }

    func displayValue(kilograms: Double) -> Double {
        self == .pounds ? kilograms * Self.poundsPerKilogram : kilograms
    }

    func format(kilograms: Double) -> String {
        String(format: "%.1f %@", displayValue(kilograms: kilograms), symbol)
    }
}

@MainActor
@Observable
final class WeightUnitPreferences {
    private static let key = "peppy.checkins.weight-unit"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let seed: () -> WeightUnit?
    private var selectedUnit: WeightUnit?

    var unit: WeightUnit {
        selectedUnit ?? seed() ?? .pounds
    }

    init(
        defaults: UserDefaults = .standard,
        seed: @escaping () -> WeightUnit? = { nil }
    ) {
        self.defaults = defaults
        self.seed = seed
        if let raw = defaults.string(forKey: Self.key),
           let saved = WeightUnit(rawValue: raw) {
            selectedUnit = saved
        }
    }

    func select(_ unit: WeightUnit) {
        selectedUnit = unit
        defaults.set(unit.rawValue, forKey: Self.key)
    }
}
```

Add `weightUnitPreferences: WeightUnitPreferences` to `Dependencies`. In both
`live()` and `mock()`, pass a seed closure that first checks the current user's
associated onboarding draft and otherwise checks the anonymous draft:

```swift
let weightUnitPreferences = WeightUnitPreferences {
    if let userID = appState.currentUser?.id,
       let draft = onboardingStore.loadDraft(for: userID) {
        return draft.preferredWeightUnit
    }
    return onboardingStore.loadAnonymousDraft()?.preferredWeightUnit
}
```

Because the closure is evaluated until the user makes an explicit Check-in
selection, it also covers returning users whose associated draft becomes known
only after authentication. With no saved selection or draft it returns pounds.

- [ ] **Step 5: Run focused tests and commit the foundations**

Run the focused command from Step 2.

Expected: `** TEST SUCCEEDED **`; JSON contains explicit nulls, the endpoint is PATCH, 409 has a dedicated error, conversion is reversible within tolerance, pounds are default, onboarding seeds once, and later selection persists.

```bash
git add ios/peppy/Core/Network/APIModels.swift ios/peppy/Core/Network/Endpoint.swift ios/peppy/Core/Network/APIError.swift ios/peppy/Core/Network/APIClient.swift ios/peppy/Core/Storage/WeightUnitPreferenceStore.swift ios/peppy/App/Dependencies.swift ios/peppy/peppyTests/CheckinViewModelTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
git commit -m "feat: add check-in update and weight preferences"
```

---

### Task 3: Add the Shared Check-in Store

**Files:**
- Create: `ios/peppy/Features/Checkins/Stores/CheckinStore.swift`
- Modify: `ios/peppy/App/Dependencies.swift`
- Modify: `ios/peppy/peppyTests/CheckinViewModelTests.swift`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `APIClientProtocol`, `Endpoint.getCheckins`, `Endpoint.getCheckin`, `Endpoint.createCheckin`, `Endpoint.updateCheckin`, `Checkin`, `CreateCheckinRequest`, `UpdateCheckinRequest`, `APIError.conflict`.
- Produces: `CheckinStore.checkins`, `today`, `history`, `selectedCheckin`, `revision`, `load(force:)`, `loadDetail(_:)`, `create(_:) -> CheckinCreateResult`, `update(id:request:) -> Checkin?`, and `checkin(id:)`.

- [ ] **Step 1: Add failing store tests**

Append to `CheckinViewModelTests.swift`:

```swift
func testStoreLoadsNewestFirstAndSeparatesTodayFromHistory() async {
    let api = MockAPIClient()
    let today = Date(timeIntervalSince1970: 1_789_689_600)
    let older = today.addingTimeInterval(-86_400)
    api.setMockResponse(
        [Checkin.fixture(date: older), Checkin.fixture(date: today)],
        for: Endpoint.getCheckins(startDate: nil, endDate: nil)
    )
    let store = CheckinStore(api: api, now: { today })

    await store.load()

    XCTAssertEqual(store.today?.date, today)
    XCTAssertEqual(store.history.map(\.date), [older])
    XCTAssertEqual(store.checkins.map(\.date), [today, older])
}

func testStoreRefreshFailureKeepsLoadedRecords() async {
    let api = MockAPIClient()
    let record = Checkin.fixture()
    api.setMockResponse([record], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
    let store = CheckinStore(api: api)
    await store.load()
    api.setMockError(.networkUnavailable, for: Endpoint.getCheckins(startDate: nil, endDate: nil))

    await store.load(force: true)

    XCTAssertEqual(store.checkins.map(\.id), [record.id])
    XCTAssertEqual(store.errorMessage, "No internet connection.")
}

func testStoreCreateAndUpdateReconcileByIdentifier() async {
    let api = MockAPIClient()
    let original = Checkin.fixture(energyLevel: 7)
    let updated = original.replacing(energyLevel: 9)
    api.setMockResponse(original, for: Endpoint.createCheckin(.fixture))
    api.setMockResponse(updated, for: Endpoint.updateCheckin(id: original.id, .fixture))
    let store = CheckinStore(api: api)

    let createResult = await store.create(.fixture)
    let updateResult = await store.update(id: original.id, request: .fixture)

    XCTAssertEqual(createResult, .saved(original))
    XCTAssertNotNil(updateResult)

    XCTAssertEqual(store.checkins.count, 1)
    XCTAssertEqual(store.checkins.first?.energyLevel, 9)
    XCTAssertEqual(store.revision, 2)
}

func testStoreConflictReloadsAndReturnsExistingToday() async {
    let api = MockAPIClient()
    let today = Date(timeIntervalSince1970: 1_789_689_600)
    let existing = Checkin.fixture(date: today)
    api.setMockError(.conflict("Already exists"), for: Endpoint.createCheckin(.fixture))
    api.setMockResponse([existing], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
    let store = CheckinStore(api: api, now: { today })

    let result = await store.create(.fixture)

    XCTAssertEqual(result, .existing(existing))
    XCTAssertEqual(store.today?.id, existing.id)
}
```

Add these test-only fixtures below the test class:

```swift
private extension CreateCheckinRequest {
    static let fixture = CreateCheckinRequest(
        date: Date(timeIntervalSince1970: 1_789_689_600),
        weightKg: 74.8,
        energyLevel: 7,
        sleepQuality: nil,
        appetiteLevel: nil,
        mood: 8,
        nausea: nil,
        injectionSiteReaction: nil,
        fatigue: nil,
        headache: nil,
        giIssues: nil,
        notes: nil
    )
}

private extension Checkin {
    static func fixture(
        id: UUID = UUID(),
        date: Date = Date(timeIntervalSince1970: 1_789_689_600),
        weightKg: Double? = nil,
        energyLevel: Int? = nil,
        sleepQuality: Int? = nil,
        appetiteLevel: Int? = nil,
        mood: Int? = nil,
        nausea: Int? = nil,
        injectionSiteReaction: Int? = nil,
        fatigue: Int? = nil,
        headache: Int? = nil,
        giIssues: Int? = nil,
        notes: String? = nil
    ) -> Checkin {
        Checkin(
            id: id,
            userId: UUID(),
            date: date,
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: sleepQuality,
            appetiteLevel: appetiteLevel,
            mood: mood,
            nausea: nausea,
            injectionSiteReaction: injectionSiteReaction,
            fatigue: fatigue,
            headache: headache,
            giIssues: giIssues,
            notes: notes,
            createdAt: nil,
            updatedAt: nil
        )
    }

    func replacing(energyLevel: Int?, notes: String? = nil) -> Checkin {
        Checkin(
            id: id,
            userId: userId,
            date: date,
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: sleepQuality,
            appetiteLevel: appetiteLevel,
            mood: mood,
            nausea: nausea,
            injectionSiteReaction: injectionSiteReaction,
            fatigue: fatigue,
            headache: headache,
            giIssues: giIssues,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
```

- [ ] **Step 2: Register the store file and verify tests fail**

Create the `Features/Checkins/Stores` group/directory, register `CheckinStore.swift` in the app target, and add the group beneath the existing Checkins group. Run the focused Check-in test command from Task 2.

Expected: compilation fails because `CheckinStore` and `CheckinCreateResult` do not exist.

- [ ] **Step 3: Implement deterministic loading and mutation reconciliation**

Create `CheckinStore.swift` with this public shape and behavior:

```swift
import Foundation
import Observation

enum CheckinCreateResult: Equatable {
    case saved(Checkin)
    case existing(Checkin)
    case failed
}

@MainActor
@Observable
final class CheckinStore {
    private let api: APIClientProtocol
    private let now: () -> Date
    private var didLoad = false
    private var loadToken = 0
    private var mutatingIDs: Set<UUID> = []

    private(set) var checkins: [Checkin] = []
    private(set) var selectedCheckin: Checkin?
    private(set) var isLoading = false
    private(set) var revision = 0
    var errorMessage: String?

    init(api: APIClientProtocol, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.now = now
    }

    var today: Checkin? {
        checkins.first { Self.utcCalendar.isDate($0.date, inSameDayAs: now()) }
    }

    var history: [Checkin] {
        checkins.filter { !Self.utcCalendar.isDate($0.date, inSameDayAs: now()) }
    }

    func checkin(id: UUID) -> Checkin? {
        if selectedCheckin?.id == id { return selectedCheckin }
        return checkins.first { $0.id == id }
    }

    func load(force: Bool = false) async {
        guard force || !didLoad else { return }
        loadToken += 1
        let token = loadToken
        isLoading = true
        errorMessage = nil
        do {
            let loaded: [Checkin] = try await api.execute(
                .getCheckins(startDate: nil, endDate: nil)
            )
            guard token == loadToken else { return }
            checkins = loaded.sorted { $0.date > $1.date }
            didLoad = true
            isLoading = false
        } catch {
            guard token == loadToken else { return }
            errorMessage = Self.message(for: error)
            isLoading = false
        }
    }

    func loadDetail(_ id: UUID) async {
        if let local = checkin(id: id) { selectedCheckin = local }
        do {
            let detail: Checkin = try await api.execute(.getCheckin(id: id))
            selectedCheckin = detail
            reconcile(detail)
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func create(_ request: CreateCheckinRequest) async -> CheckinCreateResult {
        errorMessage = nil
        do {
            let created: Checkin = try await api.execute(.createCheckin(request))
            reconcile(created)
            didLoad = true
            revision += 1
            return .saved(created)
        } catch APIError.conflict(_) {
            await load(force: true)
            if let today { return .existing(today) }
            errorMessage = "A check-in already exists for today, but it could not be loaded."
            return .failed
        } catch {
            errorMessage = Self.message(for: error)
            return .failed
        }
    }

    func update(id: UUID, request: UpdateCheckinRequest) async -> Checkin? {
        guard mutatingIDs.insert(id).inserted else { return nil }
        defer { mutatingIDs.remove(id) }
        errorMessage = nil
        do {
            let updated: Checkin = try await api.execute(.updateCheckin(id: id, request))
            reconcile(updated)
            revision += 1
            return updated
        } catch {
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    private func reconcile(_ value: Checkin) {
        if let index = checkins.firstIndex(where: { $0.id == value.id }) {
            checkins[index] = value
        } else {
            checkins.append(value)
        }
        checkins.sort { $0.date > $1.date }
        if selectedCheckin?.id == value.id { selectedCheckin = value }
    }

    private static func message(for error: Error) -> String {
        (error as? APIError)?.userMessage ?? error.localizedDescription
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
}
```

Add `checkinStore` to `Dependencies`, creating it from the same live or mock API instance used by the other stores.

- [ ] **Step 4: Run focused tests and commit the store**

Run the focused Check-in tests. Expected: all load, stale-content, reconciliation, duplicate-gate, and existing-record conflict tests pass.

```bash
git add ios/peppy/Features/Checkins/Stores/CheckinStore.swift ios/peppy/App/Dependencies.swift ios/peppy/peppyTests/CheckinViewModelTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
git commit -m "feat: add shared check-in store"
```

---

### Task 4: Derive Hub, History, and Detail Presentation Models

**Files:**
- Create: `ios/peppy/Features/Checkins/Models/CheckinModels.swift`
- Create: `ios/peppy/Features/Checkins/ViewModels/CheckinHubViewModel.swift`
- Modify: `ios/peppy/peppyTests/CheckinViewModelTests.swift`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `CheckinStore`, `WeightUnitPreferences`, `Checkin`, UTC date semantics.
- Produces: `CheckinRoute`, `CheckinHubState`, `CheckinMetricModel`, `CheckinSymptomModel`, `CheckinDetailModel`, `CheckinHistoryRowModel`, and `CheckinHubViewModel` derived properties/actions.

- [ ] **Step 1: Add failing hub-state and presentation tests**

Add tests covering these exact outcomes:

```swift
func testHubSeparatesTodayAndMapsOnlyRecordedDetailValues() async {
    let fixture = HubFixture()
    let today = fixture.makeCheckin(
        weightKg: 74.8,
        energyLevel: 7,
        sleepQuality: nil,
        mood: 8,
        nausea: 1,
        notes: "Felt steady."
    )
    fixture.api.setMockResponse([today], for: Endpoint.getCheckins(startDate: nil, endDate: nil))

    await fixture.model.loadIfNeeded()

    XCTAssertEqual(fixture.model.state, .loaded)
    XCTAssertEqual(fixture.model.todayDetail?.metrics.map(\.label), ["Weight", "Energy", "Mood"])
    XCTAssertEqual(fixture.model.todayDetail?.metrics.first?.value, "164.9 lb")
    XCTAssertEqual(fixture.model.todayDetail?.symptoms, [.init(label: "Nausea", severity: 1)])
    XCTAssertEqual(fixture.model.todayDetail?.notes, "Felt steady.")
    XCTAssertTrue(fixture.model.historyRows.isEmpty)
}

func testHubHistoryIsNewestFirstAndRoutesToReadOnlyDetail() async {
    let fixture = HubFixture()
    let newer = fixture.makeCheckin(daysAgo: 1, energyLevel: 7)
    let older = fixture.makeCheckin(daysAgo: 2, mood: 6)
    fixture.api.setMockResponse([older, newer], for: Endpoint.getCheckins(startDate: nil, endDate: nil))

    await fixture.model.loadIfNeeded()

    XCTAssertEqual(fixture.model.historyRows.map(\.id), [newer.id, older.id])
    XCTAssertEqual(fixture.model.historyRows.first?.route, .detail(newer.id))
}

func testHubPreservesLoadedRowsAndExposesRefreshError() async {
    let fixture = HubFixture()
    let row = fixture.makeCheckin(daysAgo: 1)
    fixture.api.setMockResponse([row], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
    await fixture.model.loadIfNeeded()
    fixture.api.setMockError(.networkUnavailable, for: Endpoint.getCheckins(startDate: nil, endDate: nil))

    await fixture.model.refresh()

    XCTAssertEqual(fixture.model.state, .loaded)
    XCTAssertEqual(fixture.model.refreshErrorMessage, "No internet connection.")
}

func testChangingPreferredUnitRecomputesHubWeight() async {
    let fixture = HubFixture()
    let today = fixture.makeCheckin(weightKg: 74.8)
    fixture.api.setMockResponse([today], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
    await fixture.model.loadIfNeeded()

    fixture.preferences.select(.kilograms)

    XCTAssertEqual(fixture.model.todayDetail?.metrics.first?.value, "74.8 kg")
}
```

Add this fixture below the test class:

```swift
@MainActor
private final class HubFixture {
    let now = Date(timeIntervalSince1970: 1_789_689_600)
    let api = MockAPIClient()
    let defaults: UserDefaults
    let suite: String
    let preferences: WeightUnitPreferences
    let store: CheckinStore
    let model: CheckinHubViewModel

    init() {
        suite = "HubFixture.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        preferences = WeightUnitPreferences(defaults: defaults)
        store = CheckinStore(api: api, now: { [now] in now })
        model = CheckinHubViewModel(store: store, preferences: preferences)
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
    }

    func makeCheckin(
        daysAgo: Int = 0,
        weightKg: Double? = nil,
        energyLevel: Int? = nil,
        sleepQuality: Int? = nil,
        mood: Int? = nil,
        nausea: Int? = nil,
        fatigue: Int? = nil,
        notes: String? = nil
    ) -> Checkin {
        .fixture(
            date: now.addingTimeInterval(-Double(daysAgo) * 86_400),
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: sleepQuality,
            mood: mood,
            nausea: nausea,
            fatigue: fatigue,
            notes: notes
        )
    }
}
```

- [ ] **Step 2: Register both files and verify the new tests fail**

Add a `Models` group beneath Checkins for `CheckinModels.swift`, add `CheckinHubViewModel.swift` to the existing ViewModels group, and register both in the app Sources phase. Run the focused Check-in tests.

Expected: compilation fails because the presentation models and hub view model do not exist.

- [ ] **Step 3: Define stable route and presentation contracts**

Create `CheckinModels.swift`:

```swift
import Foundation

enum CheckinRoute: Hashable {
    case create
    case detail(UUID)
    case edit(UUID)
}

enum CheckinHubState: Equatable {
    case idle
    case loading
    case empty
    case loaded
    case failed(String)
}

struct CheckinMetricModel: Identifiable, Equatable {
    let label: String
    let value: String
    var id: String { label }
}

struct CheckinSymptomModel: Identifiable, Equatable {
    let label: String
    let severity: Int
    var id: String { label }
}

struct CheckinDetailModel: Identifiable, Equatable {
    let id: UUID
    let dateText: String
    let metrics: [CheckinMetricModel]
    let symptoms: [CheckinSymptomModel]
    let notes: String?
    let isToday: Bool
}

struct CheckinHistoryRowModel: Identifiable, Equatable {
    let id: UUID
    let dateText: String
    let summary: String
    let route: CheckinRoute
}
```

- [ ] **Step 4: Implement deterministic mapping in `CheckinHubViewModel`**

Implement:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class CheckinHubViewModel {
    private let store: CheckinStore
    private let preferences: WeightUnitPreferences
    private var didAttemptLoad = false

    init(store: CheckinStore, preferences: WeightUnitPreferences) {
        self.store = store
        self.preferences = preferences
    }

    var state: CheckinHubState {
        if store.isLoading && store.checkins.isEmpty { return .loading }
        if !store.checkins.isEmpty { return .loaded }
        if didAttemptLoad, let error = store.errorMessage { return .failed(error) }
        return didAttemptLoad ? .empty : .idle
    }

    var todayDetail: CheckinDetailModel? { store.today.map(makeDetail) }
    var createRoute: CheckinRoute { .create }
    var refreshErrorMessage: String? { store.checkins.isEmpty ? nil : store.errorMessage }
    var historyRows: [CheckinHistoryRowModel] { store.history.map(row) }

    func loadIfNeeded() async { didAttemptLoad = true; await store.load() }
    func refresh() async { didAttemptLoad = true; await store.load(force: true) }
    func retry() async { await refresh() }
    func detail(for checkin: Checkin) -> CheckinDetailModel { makeDetail(checkin) }

    private func row(_ checkin: Checkin) -> CheckinHistoryRowModel {
        let values = [
            checkin.weightKg.map { preferences.unit.format(kilograms: $0) },
            checkin.energyLevel.map { "Energy \($0)" },
            checkin.mood.map { "Mood \($0)" },
            symptomModels(checkin).isEmpty ? nil : "Symptoms logged",
        ].compactMap { $0 }
        return CheckinHistoryRowModel(
            id: checkin.id,
            dateText: Self.dateFormatter.string(from: checkin.date),
            summary: values.isEmpty
                ? (checkin.notes == nil ? "Check-in saved" : "Notes added")
                : values.prefix(3).joined(separator: " · "),
            route: .detail(checkin.id)
        )
    }

    private func makeDetail(_ checkin: Checkin) -> CheckinDetailModel {
        var metrics: [CheckinMetricModel] = []
        if let value = checkin.weightKg { metrics.append(.init(label: "Weight", value: preferences.unit.format(kilograms: value))) }
        if let value = checkin.energyLevel { metrics.append(.init(label: "Energy", value: "\(value)/10")) }
        if let value = checkin.mood { metrics.append(.init(label: "Mood", value: "\(value)/10")) }
        if let value = checkin.sleepQuality { metrics.append(.init(label: "Sleep quality", value: "\(value)/10")) }
        if let value = checkin.appetiteLevel { metrics.append(.init(label: "Appetite", value: "\(value)/10")) }
        return CheckinDetailModel(
            id: checkin.id,
            dateText: Self.dateFormatter.string(from: checkin.date),
            metrics: metrics,
            symptoms: symptomModels(checkin),
            notes: checkin.notes,
            isToday: store.today?.id == checkin.id
        )
    }

    private func symptomModels(_ checkin: Checkin) -> [CheckinSymptomModel] {
        [
            ("Nausea", checkin.nausea),
            ("Injection site", checkin.injectionSiteReaction),
            ("Fatigue", checkin.fatigue),
            ("Headache", checkin.headache),
            ("GI issues", checkin.giIssues),
        ].compactMap { label, value in
            guard let value, value > 0 else { return nil }
            return CheckinSymptomModel(label: label, severity: value)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
}
```

- [ ] **Step 5: Run tests and commit presentation mapping**

Run the focused Check-in tests. Expected: hub state, omission rules, UTC ordering, summaries, routes, stale error, and live unit recomputation all pass.

```bash
git add ios/peppy/Features/Checkins/Models/CheckinModels.swift ios/peppy/Features/Checkins/ViewModels/CheckinHubViewModel.swift ios/peppy/peppyTests/CheckinViewModelTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
git commit -m "feat: model check-in hub presentation"
```

---

### Task 5: Convert the Existing Form into a Create/Edit Editor

**Files:**
- Modify: `ios/peppy/Features/Checkins/ViewModels/CheckinViewModel.swift`
- Modify: `ios/peppy/Features/Checkins/Views/CheckinView.swift`
- Modify: `ios/peppy/peppyTests/CheckinViewModelTests.swift`

**Interfaces:**
- Consumes: `CheckinStore`, `WeightUnitPreferences`, `Checkin`, `CreateCheckinRequest`, `UpdateCheckinRequest`, `CheckinCreateResult`.
- Produces: `CheckinEditorMode`, `CheckinEditorOutcome`, `CheckinViewModel.changeWeightUnit(to:)`, `CheckinViewModel.save() -> CheckinEditorOutcome?`, and `CheckinEditorView`.

- [ ] **Step 1: Replace direct-API save tests with failing create/edit/unit tests**

Keep existing encoding/timestamp tests. Update model tests to construct the model with a store and preferences, then add:

```swift
func testEditorDefaultsToPoundsAndCreatesKilogramPayload() async {
    let fixture = EditorFixture(mode: .create(Date(timeIntervalSince1970: 1_788_000_000)))
    let saved = Checkin.fixture(weightKg: 74.84274105)
    fixture.api.setMockResponse(saved, for: Endpoint.createCheckin(.fixture))
    fixture.model.weightText = "165"

    let outcome = await fixture.model.save()

    XCTAssertEqual(fixture.model.selectedWeightUnit, .pounds)
    XCTAssertEqual(outcome, .saved(saved.id))
    guard case .createCheckin(let request) = fixture.api.requestLog.last else {
        return XCTFail("Expected create endpoint")
    }
    XCTAssertEqual(request.weightKg ?? 0, 74.84274105, accuracy: 0.000001)
}

func testEditModePrefillsAndSendsExplicitNullableSnapshot() async {
    let existing = Checkin.fixture(weightKg: 74.8, energyLevel: 7, notes: "Original")
    let fixture = EditorFixture(mode: .edit(existing))
    let updated = existing.replacing(energyLevel: 9, notes: nil)
    fixture.api.setMockResponse(updated, for: Endpoint.updateCheckin(id: existing.id, .fixture))

    XCTAssertEqual(Double(fixture.model.weightText) ?? 0, 164.9, accuracy: 0.1)
    XCTAssertEqual(fixture.model.energyLevel, 7)
    XCTAssertEqual(fixture.model.notes, "Original")

    fixture.model.weightText = ""
    fixture.model.energyLevel = 9
    fixture.model.notes = ""

    let outcome = await fixture.model.save()

    XCTAssertEqual(outcome, .saved(existing.id))
    guard case .updateCheckin(_, let request) = fixture.api.requestLog.last else {
        return XCTFail("Expected update endpoint")
    }
    XCTAssertNil(request.weightKg)
    XCTAssertNil(request.notes)
    XCTAssertEqual(request.energyLevel, 9)
}

func testSwitchingUnitConvertsValidTextAndPersistsPreference() {
    let fixture = EditorFixture(mode: .create(Date()))
    fixture.model.weightText = "165"

    fixture.model.changeWeightUnit(to: .kilograms)

    XCTAssertEqual(Double(fixture.model.weightText) ?? 0, 74.8, accuracy: 0.1)
    XCTAssertEqual(fixture.preferences.unit, .kilograms)
}

func testSwitchingUnitPreservesInvalidTextForValidation() {
    let fixture = EditorFixture(mode: .create(Date()))
    fixture.model.weightText = "16."

    fixture.model.changeWeightUnit(to: .kilograms)

    XCTAssertEqual(fixture.model.weightText, "16.")
    XCTAssertEqual(fixture.preferences.unit, .kilograms)
}

func testConflictReturnsExistingOutcomeAndKeepsFormUsable() async {
    let fixture = EditorFixture(mode: .create(Date()))
    let existing = Checkin.fixture()
    fixture.api.setMockError(.conflict("Already exists"), for: Endpoint.createCheckin(.fixture))
    fixture.api.setMockResponse([existing], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
    fixture.model.notes = "Duplicate attempt"

    let outcome = await fixture.model.save()

    XCTAssertEqual(outcome, .existing(existing.id))
    XCTAssertEqual(fixture.model.notes, "Duplicate attempt")
}
```

Add the editor fixture below the test class. It shares one mock API with the
store and gives each test an isolated preference domain:

```swift
@MainActor
private final class EditorFixture {
    let api = MockAPIClient()
    let defaults: UserDefaults
    let suite: String
    let preferences: WeightUnitPreferences
    let store: CheckinStore
    let model: CheckinViewModel

    init(mode: CheckinEditorMode) {
        suite = "EditorFixture.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        preferences = WeightUnitPreferences(defaults: defaults)
        store = CheckinStore(api: api)
        model = CheckinViewModel(
            store: store,
            preferences: preferences,
            mode: mode
        )
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
    }
}
```

- [ ] **Step 2: Run focused tests and verify editor contracts fail**

Run the focused Check-in command. Expected: compilation fails because the model still takes `APIClientProtocol`, supports create only, exposes no unit selection, and returns `Bool`.

- [ ] **Step 3: Implement create/edit modes and request snapshots**

In `CheckinViewModel.swift`, add:

```swift
enum CheckinEditorMode: Equatable {
    case create(Date)
    case edit(Checkin)
}

enum CheckinEditorOutcome: Equatable {
    case saved(UUID)
    case existing(UUID)
}
```

Change the model initializer to:

```swift
init(
    store: CheckinStore,
    preferences: WeightUnitPreferences,
    mode: CheckinEditorMode
) {
    self.store = store
    self.preferences = preferences

    switch mode {
    case .create(let date):
        self.date = date
        editingID = nil
    case .edit(let checkin):
        date = checkin.date
        editingID = checkin.id
        weightText = checkin.weightKg.map {
            String(format: "%.1f", preferences.unit.displayValue(kilograms: $0))
        } ?? ""
        energyLevel = checkin.energyLevel
        sleepQuality = checkin.sleepQuality
        appetiteLevel = checkin.appetiteLevel
        mood = checkin.mood
        nausea = checkin.nausea ?? 0
        injectionSiteReaction = checkin.injectionSiteReaction ?? 0
        fatigue = checkin.fatigue ?? 0
        headache = checkin.headache ?? 0
        giIssues = checkin.giIssues ?? 0
        notes = checkin.notes ?? ""
    }
}
```

Replace the old `api` property with these stored dependencies and retain the
existing form fields, `normalizedNotes`, `severityOrNil(_:)`, and the
`CreateCheckinRequest.hasUserSignal` extension:

```swift
private let store: CheckinStore
private let preferences: WeightUnitPreferences
private let editingID: UUID?
let date: Date

var canSave: Bool { !hasInvalidWeight && createRequest.hasUserSignal && !isSaving }
```

Implement:

```swift
var selectedWeightUnit: WeightUnit { preferences.unit }

func changeWeightUnit(to newUnit: WeightUnit) {
    guard newUnit != preferences.unit else { return }
    let oldUnit = preferences.unit
    let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.hasSuffix("."), let value = Double(trimmed) {
        let kilograms = oldUnit.kilograms(from: value)
        weightText = String(format: "%.1f", newUnit.displayValue(kilograms: kilograms))
    }
    preferences.select(newUnit)
}

func save() async -> CheckinEditorOutcome? {
    guard !hasInvalidWeight else {
        errorMessage = "Enter a valid weight in \(selectedWeightUnit.symbol)."
        return nil
    }
    guard createRequest.hasUserSignal else {
        errorMessage = "Add at least one metric, symptom, or note."
        return nil
    }
    guard !isSaving else { return nil }
    isSaving = true
    errorMessage = nil
    defer { isSaving = false }

    if let editingID {
        guard let updated = await store.update(id: editingID, request: updateRequest) else {
            errorMessage = store.errorMessage
            return nil
        }
        return .saved(updated.id)
    }

    switch await store.create(createRequest) {
    case .saved(let checkin): return .saved(checkin.id)
    case .existing(let checkin): return .existing(checkin.id)
    case .failed:
        errorMessage = store.errorMessage
        return nil
    }
}
```

Use this normalized-weight implementation and build both request types from the
same normalized field snapshot; update encoding sends nils explicitly:

```swift
private var normalizedWeight: Double? {
    let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          !trimmed.hasSuffix("."),
          let displayValue = Double(trimmed) else { return nil }
    let kilograms = selectedWeightUnit.kilograms(from: displayValue)
    guard kilograms > 0, kilograms <= 500 else { return nil }
    return kilograms
}

private var hasInvalidWeight: Bool {
    let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmed.isEmpty && normalizedWeight == nil
}

private var createRequest: CreateCheckinRequest {
    CreateCheckinRequest(
        date: date,
        weightKg: normalizedWeight,
        energyLevel: energyLevel,
        sleepQuality: sleepQuality,
        appetiteLevel: appetiteLevel,
        mood: mood,
        nausea: severityOrNil(nausea),
        injectionSiteReaction: severityOrNil(injectionSiteReaction),
        fatigue: severityOrNil(fatigue),
        headache: severityOrNil(headache),
        giIssues: severityOrNil(giIssues),
        notes: normalizedNotes
    )
}

private var updateRequest: UpdateCheckinRequest {
    UpdateCheckinRequest(
        date: date,
        weightKg: normalizedWeight,
        energyLevel: energyLevel,
        sleepQuality: sleepQuality,
        appetiteLevel: appetiteLevel,
        mood: mood,
        nausea: severityOrNil(nausea),
        injectionSiteReaction: severityOrNil(injectionSiteReaction),
        fatigue: severityOrNil(fatigue),
        headache: severityOrNil(headache),
        giIssues: severityOrNil(giIssues),
        notes: normalizedNotes
    )
}
```

The explicit invalid-weight guard prevents a nonempty invalid value from being
mistaken for an intentional clear.

- [ ] **Step 4: Turn `CheckinView` into `CheckinEditorView`**

Rename the struct, not necessarily the file:

```swift
struct CheckinEditorView: View {
    @State private var model: CheckinViewModel
    private let onComplete: (CheckinEditorOutcome) -> Void

    init(
        store: CheckinStore,
        preferences: WeightUnitPreferences,
        mode: CheckinEditorMode,
        onComplete: @escaping (CheckinEditorOutcome) -> Void
    ) {
        _model = State(initialValue: CheckinViewModel(
            store: store,
            preferences: preferences,
            mode: mode
        ))
        self.onComplete = onComplete
    }
}
```

Remove the environment-created optional model and outer `NavigationStack`; destinations will already be inside the Check-in stack. Keep the metric, symptom, note, error, loading-button, and accessibility presentation. Place this segmented selector above the weight field:

```swift
Picker("Weight unit", selection: Binding(
    get: { model.selectedWeightUnit },
    set: { model.changeWeightUnit(to: $0) }
)) {
    Text("lb").tag(WeightUnit.pounds)
    Text("kg").tag(WeightUnit.kilograms)
}
.pickerStyle(.segmented)
```

Set the weight label to `Weight (lb)` or `Weight (kg)`. On save, call `onComplete(outcome)` only for a non-nil outcome; do not dismiss or clear input after failure.

- [ ] **Step 5: Run tests, build, and commit the editor**

Run the focused Check-in tests, then the generic simulator build command from the iOS engineering guide. Expected: tests and build succeed.

```bash
git add ios/peppy/Features/Checkins/ViewModels/CheckinViewModel.swift ios/peppy/Features/Checkins/Views/CheckinView.swift ios/peppy/peppyTests/CheckinViewModelTests.swift
git commit -m "feat: support creating and editing check-ins"
```

---

### Task 6: Add Check-in Navigation and the Hub UI

**Files:**
- Create: `ios/peppy/Features/Checkins/Views/CheckinHubView.swift`
- Modify: `ios/peppy/App/MainTabView.swift`
- Modify: `ios/peppy/peppyTests/ProtocolNavigationTests.swift`
- Modify: `ios/peppy/peppy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `CheckinRoute`, `CheckinStore`, `CheckinHubViewModel`, `CheckinEditorView`, `CheckinDetailModel`, existing `ProtocolNavigationCoordinator.selectedTab`.
- Produces: `ProtocolNavigationCoordinator.checkinPath`, `showCheckin(_:)`, `CheckinHubView`, `CheckinDetailView`, and detail loading for an ID not yet cached.

- [ ] **Step 1: Add failing cross-tab navigation tests**

Add to `ProtocolNavigationTests.swift`:

```swift
func testShowCheckinSwitchesTabAndReplacesCheckinPath() {
    let coordinator = ProtocolNavigationCoordinator()
    let id = UUID()
    coordinator.checkinPath = [.create]

    coordinator.showCheckin(.detail(id))

    XCTAssertEqual(coordinator.selectedTab, .checkin)
    XCTAssertEqual(coordinator.checkinPath, [.detail(id)])
}

func testShowNewCheckinRoutesDirectlyToEditor() {
    let coordinator = ProtocolNavigationCoordinator()

    coordinator.showCheckin(.create)

    XCTAssertEqual(coordinator.selectedTab, .checkin)
    XCTAssertEqual(coordinator.checkinPath, [.create])
}
```

- [ ] **Step 2: Register the hub view and verify navigation tests fail**

Register `CheckinHubView.swift` in the existing Checkins/Views group and app Sources phase. Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:peppyTests/ProtocolNavigationTests \
  test
```

Expected: compilation fails because the coordinator has no Check-in path or action.

- [ ] **Step 3: Extend the existing coordinator without renaming it**

In `ProtocolNavigationCoordinator`, add:

```swift
var checkinPath: [CheckinRoute] = []

func showCheckin(_ route: CheckinRoute) {
    selectedTab = .checkin
    checkinPath = [route]
}
```

Update the coordinator comment to say it owns shared cross-tab intent for Check-in, Protocols, and Insights; do not rename the type or existing `protocolNavigation` dependency in this project.

- [ ] **Step 4: Build the hub root and reusable saved-detail presentation**

Create `CheckinHubView.swift` with:

```swift
import SwiftUI

struct CheckinHubView: View {
    private let store: CheckinStore
    private let preferences: WeightUnitPreferences
    @Bindable private var navigation: ProtocolNavigationCoordinator
    @State private var model: CheckinHubViewModel

    init(
        store: CheckinStore,
        preferences: WeightUnitPreferences,
        navigation: ProtocolNavigationCoordinator
    ) {
        self.store = store
        self.preferences = preferences
        self.navigation = navigation
        _model = State(initialValue: CheckinHubViewModel(
            store: store,
            preferences: preferences
        ))
    }

    var body: some View {
        NavigationStack(path: $navigation.checkinPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    content
                    if let error = model.refreshErrorMessage { retryCard(error) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, Spacing.lg)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable { await model.refresh() }
            .task { await model.loadIfNeeded() }
            .navigationDestination(for: CheckinRoute.self) { route in
                destination(route)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Check-in")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.pepTextPrimary)
            Text("See today's signals and revisit how you've been feeling.")
                .font(.system(size: 14))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func retryCard(_ message: String) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Couldn't refresh check-ins")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                PepButton(title: "Try again", style: .secondary) {
                    Task { await model.retry() }
                }
            }
        }
    }
}
```

Implement the root-state switch and actions with:

```swift
@ViewBuilder
private var content: some View {
    switch model.state {
    case .idle, .loading:
        PepLoadingView(message: "Loading your check-ins")
            .frame(maxWidth: .infinity, minHeight: 220)
    case .failed(let message):
        VStack(spacing: Spacing.md) {
            PepEmptyState(
                icon: "exclamationmark.triangle",
                title: "Check-ins couldn't load",
                message: message
            )
            PepButton(title: "Try again", style: .primary) {
                Task { await model.retry() }
            }
        }
    case .empty:
        VStack(spacing: Spacing.md) {
            PepEmptyState(
                icon: "checkmark.circle",
                title: "Start your check-in history",
                message: "Log how you feel today so Peppy can connect changes to your protocol."
            )
            addTodayButton
        }
    case .loaded:
        if let today = model.todayDetail {
            CheckinDetailView(model: today, showsEdit: true) {
                navigation.checkinPath.append(.edit(today.id))
            }
        } else {
            addTodayButton
        }
        historySection
    }
}

private var addTodayButton: some View {
    PepButton(title: "Add today's check-in", style: .primary) {
        navigation.checkinPath.append(.create)
    }
}

@ViewBuilder
private var historySection: some View {
    if !model.historyRows.isEmpty {
        Text("Recent check-ins")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.pepTextPrimary)
        VStack(spacing: Spacing.sm) {
            ForEach(model.historyRows) { row in
                Button {
                    navigation.checkinPath.append(row.route)
                } label: {
                    PepCard {
                        HStack(spacing: Spacing.sm) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(row.dateText)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.pepTextPrimary)
                                Text(row.summary)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.pepTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.pepTextTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(row.dateText), \(row.summary). View check-in")
            }
        }
    }
}
```

Implement `CheckinDetailView(model:showsEdit:onEdit:)` in the same file:

```swift
struct CheckinDetailView: View {
    let model: CheckinDetailModel
    let showsEdit: Bool
    let onEdit: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm),
    ]

    var body: some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            if model.isToday { PepBadge(text: "Today · Saved", type: .success) }
                            Text(model.dateText)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.pepTextPrimary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.pepPrimary)
                            .accessibilityHidden(true)
                    }

                    if !model.metrics.isEmpty {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                            ForEach(model.metrics) { metric in
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(metric.label).font(.caption).foregroundStyle(Color.pepTextSecondary)
                                    Text(metric.value).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.pepTextPrimary)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(metric.label), \(metric.value)")
                            }
                        }
                    }

                    if !model.symptoms.isEmpty {
                        Divider()
                        Text("Symptoms").font(.system(size: 15, weight: .semibold))
                        ForEach(model.symptoms) { symptom in
                            HStack {
                                Text(symptom.label)
                                Spacer()
                                Text("\(symptom.severity)/10").foregroundStyle(Color.pepTextSecondary)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(symptom.label), severity \(symptom.severity) out of 10")
                        }
                    }

                    if let notes = model.notes {
                        Divider()
                        Text("Notes").font(.system(size: 15, weight: .semibold))
                        Text(notes).foregroundStyle(Color.pepTextSecondary)
                    }

                    if showsEdit {
                        PepButton(title: "Edit today's check-in", style: .primary, action: onEdit)
                    }
            }
        }
        .navigationTitle(model.isToday ? "Today's check-in" : "Check-in details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

Implement destinations:

```swift
@ViewBuilder
private func destination(_ route: CheckinRoute) -> some View {
    switch route {
    case .create:
        CheckinEditorView(store: store, preferences: preferences, mode: .create(Date())) {
            handleEditorOutcome($0)
        }
    case .edit(let id):
        if let value = store.checkin(id: id) {
            CheckinEditorView(store: store, preferences: preferences, mode: .edit(value)) {
                handleEditorOutcome($0)
            }
        } else {
            CheckinLoadingDestination(store: store, preferences: preferences, id: id)
        }
    case .detail(let id):
        CheckinLoadingDestination(store: store, preferences: preferences, id: id)
    }
}
```

Add the destination wrapper and outcome reconciliation:

```swift
private struct CheckinLoadingDestination: View {
    let store: CheckinStore
    let preferences: WeightUnitPreferences
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var didLoad = false

    var body: some View {
        Group {
            if let value = store.checkin(id: id) {
                ScrollView {
                    CheckinDetailView(
                        model: CheckinHubViewModel(
                            store: store,
                            preferences: preferences
                        ).detail(for: value),
                        showsEdit: false,
                        onEdit: {}
                    )
                    .padding(20)
                }
            } else if !didLoad {
                PepLoadingView(message: "Loading check-in")
            } else {
                VStack(spacing: Spacing.md) {
                    PepEmptyState(
                        icon: "exclamationmark.circle",
                        title: "Check-in not found",
                        message: store.errorMessage ?? "This check-in is no longer available."
                    )
                    PepButton(title: "Back", style: .secondary) { dismiss() }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pepBackground.ignoresSafeArea())
        .task {
            if store.checkin(id: id) == nil { await store.loadDetail(id) }
            didLoad = true
        }
    }
}

private func handleEditorOutcome(_ outcome: CheckinEditorOutcome) {
    switch outcome {
    case .saved:
        navigation.checkinPath.removeAll()
    case .existing(let id):
        navigation.checkinPath = [.detail(id)]
    }
}
```

- [ ] **Step 5: Replace the Check-in tab's form root with the hub**

Replace `CheckinTab` in `MainTabView.swift`:

```swift
struct CheckinTab: View {
    @Environment(\.dependencies) private var deps

    var body: some View {
        CheckinHubView(
            store: deps.checkinStore,
            preferences: deps.weightUnitPreferences,
            navigation: deps.protocolNavigation
        )
    }
}
```

Update previews to seed `MockAPIClient` with `[Checkin]` for the list endpoint.

- [ ] **Step 6: Run navigation and Check-in tests, build, and commit**

Run both focused suites:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:peppyTests/CheckinViewModelTests \
  -only-testing:peppyTests/ProtocolNavigationTests \
  test
```

Then run the generic simulator build. Expected: tests and build succeed.

```bash
git add ios/peppy/Features/Checkins/Views/CheckinHubView.swift ios/peppy/App/MainTabView.swift ios/peppy/peppyTests/ProtocolNavigationTests.swift ios/peppy/peppy.xcodeproj/project.pbxproj
git commit -m "feat: add iOS check-in hub"
```

---

### Task 7: Connect Today's Real Check-in Values to Home

**Files:**
- Modify: `ios/peppy/Features/Dashboard/Models/DashboardModels.swift`
- Modify: `ios/peppy/Features/Dashboard/ViewModels/DashboardViewModel.swift`
- Modify: `ios/peppy/Features/Dashboard/Views/DashboardCards.swift`
- Modify: `ios/peppy/Features/Dashboard/Views/DashboardView.swift`
- Modify: `ios/peppy/peppyTests/DashboardViewModelTests.swift`
- Modify: `ios/peppy/peppyTests/ProtocolNavigationTests.swift`

**Interfaces:**
- Consumes: `DashboardSummary.todayCheckin`, `CheckinStore.today`, `CheckinStore.revision`, `WeightUnitPreferences.unit`, `ProtocolNavigationCoordinator.showCheckin(_:)`.
- Produces: `DashboardCheckinPreview`, `DashboardViewModel.todayPreview`, `DashboardViewModel.checkinRoute`, and Home refresh triggered by successful Check-in mutation.

- [ ] **Step 1: Add failing Home preview, fallback, route, and refresh tests**

Add to `DashboardViewModelTests.swift`:

```swift
func testDashboardPreviewUsesTodayValuesAndPreferredUnit() async {
    let fixture = DashboardCheckinFixture()
    let today = Checkin.fixture(weightKg: 74.8, energyLevel: 7, mood: 8, nausea: 1)
    fixture.api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
    fixture.api.setMockResponse([today], for: Endpoint.getCheckins(startDate: nil, endDate: nil))

    await fixture.model.load()

    XCTAssertEqual(fixture.model.todayPreview?.highlights, ["164.9 lb", "Energy 7", "Mood 8"])
    XCTAssertEqual(fixture.model.checkinRoute, .detail(today.id))
}

func testDashboardPreviewFallsBackToSymptoms() async {
    let fixture = DashboardCheckinFixture()
    let symptoms = Checkin.fixture(nausea: 2, fatigue: 3)
    fixture.api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
    fixture.api.setMockResponse([symptoms], for: Endpoint.getCheckins(startDate: nil, endDate: nil))
    await fixture.model.load()
    XCTAssertEqual(fixture.model.todayPreview?.highlights, ["2 symptoms logged"])
}

func testDashboardPreviewFallsBackToNotes() async {
    let fixture = DashboardCheckinFixture()
    let notesOnly = Checkin.fixture(notes: "Felt steady")
    fixture.api.setMockResponse(DashboardSummary.mockPendingStarter, for: Endpoint.getDashboardSummary)
    fixture.api.setMockResponse([notesOnly], for: Endpoint.getCheckins(startDate: nil, endDate: nil))

    await fixture.model.load()

    XCTAssertEqual(fixture.model.todayPreview?.highlights, ["Notes added"])
}

func testDashboardWithoutTodayRoutesToCreate() async {
    let fixture = DashboardCheckinFixture()
    fixture.api.setMockResponse(DashboardSummary.mockMissingProfile, for: Endpoint.getDashboardSummary)
    fixture.api.setMockResponse([Checkin](), for: Endpoint.getCheckins(startDate: nil, endDate: nil))
    await fixture.model.load()
    XCTAssertEqual(fixture.model.checkinRoute, .create)
}

func testSuccessfulCheckinMutationTriggersDashboardSummaryRefresh() async {
    let fixture = DashboardCheckinFixture()
    fixture.api.setMockResponse(DashboardSummary.mockMissingProfile, for: Endpoint.getDashboardSummary)
    fixture.api.setMockResponse([Checkin](), for: Endpoint.getCheckins(startDate: nil, endDate: nil))
    await fixture.model.load()
    let created = Checkin.fixture()
    fixture.api.setMockResponse(created, for: Endpoint.createCheckin(.fixture))
    _ = await fixture.store.create(.fixture)

    await fixture.model.refreshIfCheckinStateChanged()

    XCTAssertEqual(fixture.dashboardLoadCount, 2)
}
```

Add the fixtures below `DashboardViewModelTests` so these tests do not depend on
file-private helpers in another test source:

```swift
@MainActor
private final class DashboardCheckinFixture {
    let now = Date(timeIntervalSince1970: 1_789_689_600)
    let api = MockAPIClient()
    let defaults: UserDefaults
    let suite: String
    let preferences: WeightUnitPreferences
    let store: CheckinStore
    let model: DashboardViewModel

    init() {
        suite = "DashboardCheckinFixture.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        preferences = WeightUnitPreferences(defaults: defaults)
        store = CheckinStore(api: api, now: { [now] in now })
        model = DashboardViewModel(
            api: api,
            checkinStore: store,
            weightUnitPreferences: preferences,
            hasProfileAttachFailure: false
        )
    }

    var dashboardLoadCount: Int {
        api.requestLog.filter {
            $0.requestID == Endpoint.getDashboardSummary.requestID
        }.count
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
    }
}

private extension CreateCheckinRequest {
    static let fixture = CreateCheckinRequest(
        date: Date(timeIntervalSince1970: 1_789_689_600),
        weightKg: 74.8,
        energyLevel: 7,
        sleepQuality: nil,
        appetiteLevel: nil,
        mood: 8,
        nausea: nil,
        injectionSiteReaction: nil,
        fatigue: nil,
        headache: nil,
        giIssues: nil,
        notes: nil
    )
}

private extension Checkin {
    static func fixture(
        id: UUID = UUID(),
        date: Date = Date(timeIntervalSince1970: 1_789_689_600),
        weightKg: Double? = nil,
        energyLevel: Int? = nil,
        mood: Int? = nil,
        nausea: Int? = nil,
        fatigue: Int? = nil,
        notes: String? = nil
    ) -> Checkin {
        Checkin(
            id: id,
            userId: UUID(),
            date: date,
            weightKg: weightKg,
            energyLevel: energyLevel,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: mood,
            nausea: nausea,
            injectionSiteReaction: nil,
            fatigue: fatigue,
            headache: nil,
            giIssues: nil,
            notes: notes,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
```

Add to `ProtocolNavigationTests.swift`:

```swift
func testDashboardCheckinRouteSwitchesToCheckinTab() {
    let coordinator = ProtocolNavigationCoordinator()
    let id = UUID()

    coordinator.showCheckin(.detail(id))

    XCTAssertEqual(coordinator.selectedTab, .checkin)
    XCTAssertEqual(coordinator.checkinPath, [.detail(id)])
}
```

- [ ] **Step 2: Run Dashboard and navigation suites and verify failures**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:peppyTests/DashboardViewModelTests \
  -only-testing:peppyTests/ProtocolNavigationTests \
  test
```

Expected: compilation fails because dashboard preview and Check-in revision APIs are not integrated.

- [ ] **Step 3: Add a compact preview model and deterministic priority mapping**

In `DashboardModels.swift`, add:

```swift
struct DashboardCheckinPreview: Equatable {
    let isSaved: Bool
    let title: String
    let subtitle: String
    let highlights: [String]
}
```

Add optional constructor dependencies so existing dashboard tests remain focused,
while `DashboardView` injects the shared production instances:

```swift
private let checkinStore: CheckinStore?
private let weightUnitPreferences: WeightUnitPreferences?
private var lastSeenCheckinRevision: Int

init(
    api: APIClientProtocol,
    protocolStore: ProtocolStore? = nil,
    checkinStore: CheckinStore? = nil,
    weightUnitPreferences: WeightUnitPreferences? = nil,
    hasProfileAttachFailure: @autoclosure @escaping () -> Bool
) {
    self.api = api
    self.protocolStore = protocolStore
    self.checkinStore = checkinStore
    self.weightUnitPreferences = weightUnitPreferences
    self.hasProfileAttachFailure = hasProfileAttachFailure
    lastSeenProtocolRevision = protocolStore?.revision ?? 0
    lastSeenCheckinRevision = checkinStore?.revision ?? 0
}

func load() async {
    lastSeenProtocolRevision = protocolStore?.revision ?? 0
    lastSeenCheckinRevision = checkinStore?.revision ?? 0
    await checkinStore?.load()
    await loadDashboardSummary()
}

func refreshIfCheckinStateChanged() async {
    guard let checkinStore,
          checkinStore.revision != lastSeenCheckinRevision else { return }
    lastSeenCheckinRevision = checkinStore.revision
    await loadDashboardSummary()
}

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
        state.summary = await recoveringProtocol(in: .mockMissingProfile)
        state.showsProfileSyncRecovery = hasProfileAttachFailure()
    } catch {
        state.errorMessage = error.localizedDescription
        state.summary = await recoveringProtocol(in: .mockMissingProfile)
        state.showsProfileSyncRecovery = hasProfileAttachFailure()
    }
}
```

Keep `refreshIfProtocolStateChanged()` and `recoveringProtocol(in:)`; the former
continues to call `load()`. A CheckinStore list error remains on the store and
does not replace a successfully loaded dashboard summary.

Implement:

```swift
var todayPreview: DashboardCheckinPreview? {
    guard let checkin = checkinStore?.today,
          let weightUnitPreferences else { return nil }
    var values = [
        checkin.weightKg.map { weightUnitPreferences.unit.format(kilograms: $0) },
        checkin.energyLevel.map { "Energy \($0)" },
        checkin.mood.map { "Mood \($0)" },
    ].compactMap { $0 }

    let symptomCount = [
        checkin.nausea,
        checkin.injectionSiteReaction,
        checkin.fatigue,
        checkin.headache,
        checkin.giIssues,
    ].compactMap { $0 }.filter { $0 > 0 }.count
    if values.count < 3, symptomCount > 0 {
        values.append("\(symptomCount) symptom\(symptomCount == 1 ? "" : "s") logged")
    }
    if values.isEmpty, checkin.notes != nil { values = ["Notes added"] }

    return DashboardCheckinPreview(
        isSaved: true,
        title: "Your check-in",
        subtitle: "Today's check-in is saved",
        highlights: Array(values.prefix(3))
    )
}

var checkinRoute: CheckinRoute {
    if let id = checkinStore?.today?.id ?? state.summary?.todayCheckin.checkinId {
        return .detail(id)
    }
    return .create
}
```

Because only successful store reconciliation increments `revision`, a failed
Check-in mutation cannot trigger the summary fetch.

- [ ] **Step 4: Replace the Home sheet with cross-tab routing and real preview content**

In `DashboardCards.swift`, replace `DashboardTodayCard` with:

```swift
struct DashboardTodayCard: View {
    let today: DashboardTodayCheckin
    let preview: DashboardCheckinPreview?
    let openCheckin: () -> Void

    private var isSaved: Bool { preview != nil || today.logged }

    var body: some View {
        Button(action: openCheckin) {
            PepCard {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(preview?.title ?? (isSaved ? "Your check-in" : "How are you today?"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(preview?.subtitle ?? (isSaved
                            ? "Today's check-in is saved"
                            : "Log weight, energy, mood, and symptoms."))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let preview {
                            ForEach(preview.highlights, id: \.self) { value in
                                Text(value)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.pepTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.pepTextTertiary)
                        .frame(width: 24, height: 44)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSaved ? "View full check-in" : "Add today's check-in")
    }
}
```

When only the backend summary says logged, this renders truthful saved copy
without fabricated metrics. Update the preview call site to pass
`preview: nil`.

In `DashboardView.swift`, remove `showsCheckin` and the `.sheet` that creates the
old form. Replace the card call with:

```swift
DashboardTodayCard(
    today: summary.todayCheckin,
    preview: model?.todayPreview
) {
    guard let model else { return }
    deps.protocolNavigation.showCheckin(model.checkinRoute)
}
```

Construct the model with the shared dependencies:

```swift
model = DashboardViewModel(
    api: deps.api,
    protocolStore: deps.protocolStore,
    checkinStore: deps.checkinStore,
    weightUnitPreferences: deps.weightUnitPreferences,
    hasProfileAttachFailure: deps.flow.hasProfileAttachFailure
)
```

Keep the existing protocol revision observer and add:

```swift
.onChange(of: deps.checkinStore.revision) {
    Task { await model?.refreshIfCheckinStateChanged() }
}
```

- [ ] **Step 5: Run focused tests, all iOS tests, build, and commit**

Run the focused Dashboard/navigation suites, then:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  test
```

Run the generic simulator build:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: all iOS tests pass and the app builds.

```bash
git add ios/peppy/Features/Dashboard/Models/DashboardModels.swift ios/peppy/Features/Dashboard/ViewModels/DashboardViewModel.swift ios/peppy/Features/Dashboard/Views/DashboardCards.swift ios/peppy/Features/Dashboard/Views/DashboardView.swift ios/peppy/peppyTests/DashboardViewModelTests.swift ios/peppy/peppyTests/ProtocolNavigationTests.swift
git commit -m "feat: connect check-ins to Home"
```

---

### Task 8: Final Accessibility, Simulator, and Regression Verification

**Files:**
- Modify only files implicated by a failing automated check or observed simulator defect.

**Interfaces:**
- Consumes: the completed backend PATCH behavior and all iOS feature interfaces from Tasks 2-7.
- Produces: a verified end-to-end Check-in Hub with no known spec gaps.

- [ ] **Step 1: Run backend quality checks**

Run from `backend/`:

```bash
pytest -q
ruff check app tests
```

Expected: zero test failures and zero Ruff findings.

- [ ] **Step 2: Run focused iOS regression suites**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:peppyTests/CheckinViewModelTests \
  -only-testing:peppyTests/DashboardViewModelTests \
  -only-testing:peppyTests/ProtocolNavigationTests \
  test
```

Expected: `** TEST SUCCEEDED **` with zero failing tests.

- [ ] **Step 3: Run the full iOS suite and generic build**

Run the full iOS test and build commands from Task 7.

Expected: `** TEST SUCCEEDED **` and `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify the end-to-end simulator flow when a runtime is available**

On iPhone 17 Pro, verify each item explicitly:

1. Empty Check-in tab shows the hub empty state and Add action.
2. Home unsaved card switches to Check-in and opens creation.
3. Weight starts in lb, switching to kg converts a valid value, and returning to the editor retains kg.
4. Saving returns to the hub and shows every recorded metric, nonzero symptom, and notes.
5. Home immediately shows up to three real highlights in the selected unit.
6. Home saved card switches to Check-in and opens the saved detail.
7. Editing today prefills all values; clearing weight or notes persists the clear.
8. Historical rows remain visible, newest first, and open read-only detail.
9. Pull-to-refresh failure preserves loaded rows and presents retry.
10. Save/update failure preserves input and rejects repeated taps while saving.
11. Large Dynamic Type remains readable without clipped values or actions.
12. VoiceOver reads date, metrics, symptoms, unit selector, and actions in a sensible order.

Compare tone, spacing, card density, typography, action hierarchy, and tab behavior against `/Users/gabri/Downloads/Peppy IOS.fig`.

- [ ] **Step 5: Review the final diff and commit only evidence-driven fixes**

```bash
git diff --check
git status --short
git diff --stat
```

Confirm `.DS_Store` remains uncommitted and no unrelated files entered the feature commits. If verification required fixes, repeat the relevant failing test before and after the change, then commit only those files:

```bash
git commit -m "fix: polish check-in hub integration"
```

If verification required no fixes, do not create an empty commit.
