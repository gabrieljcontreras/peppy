# Peppy iOS Onboarding and Authentication Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Peppy's Figma-matched iOS launch, pre-auth onboarding, personalized summary, authentication handoff, local persistence, native HealthKit and notification permissions, app icon, and backend handoff documentation.

**Architecture:** Add an injected `AppFlowCoordinator` for deterministic root routing, a versioned `OnboardingDraft` persisted through `OnboardingStoreProtocol`, and isolated permission services behind the existing `Dependencies` environment. SwiftUI onboarding views render from one observable view model, save after every interaction, and hand the completed anonymous draft to the authenticated backend user ID without changing backend code.

**Tech Stack:** Swift 6 / SwiftUI, Observation, XCTest, UserDefaults, Keychain Services, HealthKit, UserNotifications, Xcode asset catalogs, iOS 17+

---

## Source Material and Constraints

- Approved design: `docs/superpowers/specs/2026-06-13-ios-onboarding-auth-flow-design.md`
- Visual source: `/Users/gabrielcontreras/Downloads/Peppy IOS.fig`
- Required build:

```bash
xcodebuild \
  -project peppy.xcodeproj \
  -scheme peppy \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- Work only in `ios/peppy`; inspect Android/backend files for product parity but do not edit them.
- Preserve the user's uncommitted `peppy.xcodeproj/project.xcworkspace/xcuserdata/.../UserInterfaceState.xcuserstate`.
- Use Xcode to add targets, files, capabilities, and resources. Do not manually invent PBX object IDs.
- Match the Figma closely. Native permission alerts, Dynamic Type, VoiceOver, Reduce Motion, safe areas, keyboard avoidance, and 44-point targets override pixel matching.
- Apple references:
  - [UILaunchScreen](https://developer.apple.com/documentation/bundleresources/information-property-list/uilaunchscreen)
  - [Authorizing HealthKit access](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
  - [Requesting notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)

## File Map

### Create

```text
App/AppFlowCoordinator.swift
Core/Data/PeptideCatalog.swift
Core/Permissions/HealthKitService.swift
Core/Permissions/NotificationPermissionService.swift
Core/Storage/OnboardingStore.swift
Features/Onboarding/Models/OnboardingDraft.swift
Features/Onboarding/ViewModels/OnboardingViewModel.swift
Features/Onboarding/Views/OnboardingFlowView.swift
Features/Onboarding/Views/OnboardingScaffold.swift
Features/Onboarding/Views/OnboardingIntroView.swift
Features/Onboarding/Views/BaselineStepsView.swift
Features/Onboarding/Views/PeptidesStepView.swift
Features/Onboarding/Views/MedicationsStepView.swift
Features/Onboarding/Views/WorkoutStepView.swift
Features/Onboarding/Views/GoalsStepView.swift
Features/Onboarding/Views/HealthPermissionView.swift
Features/Onboarding/Views/NotificationPermissionView.swift
Features/Onboarding/Views/ReadySummaryView.swift
Design/Components/PepOnboardingProgress.swift
Design/Components/PepSelectionChip.swift
Design/Assets 2.xcassets/LaunchBackground.colorset/Contents.json
Design/Assets 2.xcassets/LaunchLogo.imageset/Contents.json
Design/Assets 2.xcassets/LaunchLogo.imageset/launch-logo.png
Design/Assets 2.xcassets/AppIcon.appiconset/AppIcon-1024.png
LaunchScreen.storyboard
peppy.entitlements
peppyTests/AppFlowCoordinatorTests.swift
peppyTests/OnboardingDraftTests.swift
peppyTests/OnboardingStoreTests.swift
peppyTests/OnboardingViewModelTests.swift
peppyTests/PermissionServiceTests.swift
BACKEND.md
```

### Modify

```text
App/AppState.swift
App/Dependencies.swift
App/PeppyApp.swift
App/RootView.swift
Features/Auth/Views/LoginView.swift
Features/Auth/Views/RegisterView.swift
Design/Assets 2.xcassets/AppIcon.appiconset/Contents.json
peppy.xcodeproj/project.pbxproj (through Xcode UI)
peppy.xcodeproj/xcuserdata/gabrielcontreras.xcuserdatad/xcschemes/xcschememanagement.plist (only if Xcode updates scheme sharing)
```

## Task 1: Establish the Test Target and Baseline

**Files:**
- Modify through Xcode: `peppy.xcodeproj/project.pbxproj`
- Create through Xcode: `peppyTests/`

- [ ] **Step 1: Confirm the current baseline builds**

Run:

```bash
xcodebuild \
  -project peppy.xcodeproj \
  -scheme peppy \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: `** BUILD SUCCEEDED **`. If it fails before any implementation change, record the exact baseline failure and resolve only project-local build issues.

- [ ] **Step 2: Add a unit-test target using Xcode**

Open `peppy.xcodeproj`, then use **File → New → Target → iOS Unit Testing Bundle** with:

```text
Product Name: peppyTests
Team: same as peppy
Language: Swift
Target to be Tested: peppy
Deployment Target: iOS 17.0
```

Enable the `peppyTests` target in the shared `peppy` scheme's Test action. Do not add a UI-test target in this phase.

- [ ] **Step 3: Add a smoke test**

Create `peppyTests/OnboardingDraftTests.swift`:

```swift
import XCTest
@testable import peppy

final class OnboardingDraftTests: XCTestCase {
    func testPlaceholderUntilDraftModelIsImplemented() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: Run the test target**

First obtain an available device:

```bash
xcrun simctl list devices available
```

Then run with the listed simulator name:

```bash
xcodebuild \
  -project peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

Expected: one passing smoke test. If that simulator is not installed, substitute an exact available iPhone name from the preceding command.

- [ ] **Step 5: Commit the test scaffold**

```bash
git add peppy.xcodeproj peppyTests
git commit -m "test: add iOS unit test target"
```

## Task 2: Define the Versioned Onboarding Domain Model

**Files:**
- Create: `Features/Onboarding/Models/OnboardingDraft.swift`
- Test: `peppyTests/OnboardingDraftTests.swift`

- [ ] **Step 1: Replace the smoke test with normalization and progression tests**

```swift
import XCTest
@testable import peppy

final class OnboardingDraftTests: XCTestCase {
    func testFeetAndInchesNormalizeToCentimeters() {
        XCTAssertEqual(
            OnboardingDraft.centimeters(feet: 5, inches: 8),
            172.72,
            accuracy: 0.001
        )
    }

    func testPoundsNormalizeToKilograms() {
        XCTAssertEqual(
            OnboardingDraft.kilograms(pounds: 165),
            74.84268,
            accuracy: 0.001
        )
    }

    func testNextStepAdvancesThroughPermissionScreens() {
        XCTAssertEqual(OnboardingStep.goals.next, .health)
        XCTAssertEqual(OnboardingStep.health.next, .notifications)
        XCTAssertNil(OnboardingStep.notifications.next)
    }

    func testSkippedValuesRemainNil() {
        let draft = OnboardingDraft()
        XCTAssertNil(draft.age)
        XCTAssertNil(draft.heightCentimeters)
        XCTAssertNil(draft.weightKilograms)
        XCTAssertTrue(draft.selectedPeptides.isEmpty)
    }
}
```

- [ ] **Step 2: Run the focused test and verify failure**

```bash
xcodebuild \
  -project peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:peppyTests/OnboardingDraftTests \
  test
```

Expected: compile failure because `OnboardingDraft` and `OnboardingStep` do not exist.

- [ ] **Step 3: Implement the draft model**

Create `Features/Onboarding/Models/OnboardingDraft.swift`:

```swift
import Foundation

enum HeightUnit: String, Codable, CaseIterable {
    case feetAndInches
    case centimeters
}

enum WeightUnit: String, Codable, CaseIterable {
    case pounds
    case kilograms
}

enum PermissionChoice: String, Codable {
    case notAsked
    case requested
    case skipped
}

enum PermissionOutcome: String, Codable {
    case notDetermined
    case requested
    case authorized
    case denied
    case unavailable
    case failed
}

enum OnboardingGoal: String, Codable, CaseIterable, Identifiable {
    case trackProtocols
    case understandBody
    case buildHabits
    case seeWhatWorks
    case optimizeRecovery
    case feelInControl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trackProtocols: "Track my protocols"
        case .understandBody: "Understand my body better"
        case .buildHabits: "Build consistent habits"
        case .seeWhatWorks: "See what's actually working"
        case .optimizeRecovery: "Optimize recovery"
        case .feelInControl: "Feel more in control"
        }
    }
}

enum OnboardingStep: Int, Codable, CaseIterable {
    case intro
    case age
    case height
    case weight
    case peptides
    case medications
    case workout
    case goals
    case health
    case notifications

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var questionnaireIndex: Int? {
        guard rawValue >= Self.age.rawValue,
              rawValue <= Self.goals.rawValue else { return nil }
        return rawValue
    }
}

struct OnboardingDraft: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var currentStep: OnboardingStep = .intro
    var isComplete = false
    var age: Int?
    var heightCentimeters: Double?
    var preferredHeightUnit: HeightUnit = .feetAndInches
    var weightKilograms: Double?
    var preferredWeightUnit: WeightUnit = .pounds
    var selectedPeptides: [String] = []
    var customPeptides: [String] = []
    var otherMedications: String?
    var workoutDaysPerWeek: Int?
    var goals: Set<OnboardingGoal> = []
    var customGoal: String?
    var healthChoice: PermissionChoice = .notAsked
    var healthOutcome: PermissionOutcome = .notDetermined
    var notificationChoice: PermissionChoice = .notAsked
    var notificationOutcome: PermissionOutcome = .notDetermined
    var createdAt = Date()
    var updatedAt = Date()

    static func centimeters(feet: Int, inches: Int) -> Double {
        (Double(feet) * 30.48) + (Double(inches) * 2.54)
    }

    static func kilograms(pounds: Double) -> Double {
        pounds * 0.45359237
    }
}
```

- [ ] **Step 4: Run the model tests**

Run the focused command from Step 2.

Expected: all `OnboardingDraftTests` pass.

- [ ] **Step 5: Commit the model**

```bash
git add Features/Onboarding/Models/OnboardingDraft.swift peppyTests/OnboardingDraftTests.swift peppy.xcodeproj
git commit -m "feat: add onboarding draft model"
```

## Task 3: Persist Anonymous and User-Associated Drafts

**Files:**
- Create: `Core/Storage/OnboardingStore.swift`
- Test: `peppyTests/OnboardingStoreTests.swift`
- Modify: `App/Dependencies.swift`

- [ ] **Step 1: Write storage tests**

Create `peppyTests/OnboardingStoreTests.swift`:

```swift
import XCTest
@testable import peppy

final class OnboardingStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: UserDefaultsOnboardingStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "OnboardingStoreTests")!
        defaults.removePersistentDomain(forName: "OnboardingStoreTests")
        store = UserDefaultsOnboardingStore(defaults: defaults)
    }

    func testAnonymousDraftRoundTrips() {
        var draft = OnboardingDraft()
        draft.age = 32
        store.saveAnonymousDraft(draft)
        XCTAssertEqual(store.loadAnonymousDraft()?.age, 32)
    }

    func testAssociatingDraftMovesItToUserID() {
        var draft = OnboardingDraft()
        draft.selectedPeptides = ["Retatrutide"]
        store.saveAnonymousDraft(draft)

        let userID = UUID()
        store.associateAnonymousDraft(with: userID)

        XCTAssertNil(store.loadAnonymousDraft())
        XCTAssertEqual(store.loadDraft(for: userID)?.selectedPeptides, ["Retatrutide"])
        XCTAssertTrue(store.hasKnownAccount)
    }

    func testMalformedDraftIsClearedWithoutCrashing() {
        defaults.set(Data("broken".utf8), forKey: "peppy.onboarding.anonymous")
        XCTAssertNil(store.loadAnonymousDraft())
        XCTAssertNil(defaults.data(forKey: "peppy.onboarding.anonymous"))
    }
}
```

- [ ] **Step 2: Run and verify failure**

Run:

```bash
xcodebuild \
  -project peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:peppyTests/OnboardingStoreTests \
  test
```

Expected: compile failure because the onboarding store types do not exist.

- [ ] **Step 3: Implement the store**

Create `Core/Storage/OnboardingStore.swift`:

```swift
import Foundation

protocol OnboardingStoreProtocol: AnyObject {
    var hasKnownAccount: Bool { get set }
    func loadAnonymousDraft() -> OnboardingDraft?
    func saveAnonymousDraft(_ draft: OnboardingDraft)
    func clearAnonymousDraft()
    func associateAnonymousDraft(with userID: UUID)
    func loadDraft(for userID: UUID) -> OnboardingDraft?
}

final class UserDefaultsOnboardingStore: OnboardingStoreProtocol {
    private enum Key {
        static let anonymous = "peppy.onboarding.anonymous"
        static let knownAccount = "peppy.onboarding.hasKnownAccount"
        static func user(_ id: UUID) -> String {
            "peppy.onboarding.user.\(id.uuidString.lowercased())"
        }
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    var hasKnownAccount: Bool {
        get { defaults.bool(forKey: Key.knownAccount) }
        set { defaults.set(newValue, forKey: Key.knownAccount) }
    }

    func loadAnonymousDraft() -> OnboardingDraft? {
        load(forKey: Key.anonymous)
    }

    func saveAnonymousDraft(_ draft: OnboardingDraft) {
        save(draft, forKey: Key.anonymous)
    }

    func clearAnonymousDraft() {
        defaults.removeObject(forKey: Key.anonymous)
    }

    func associateAnonymousDraft(with userID: UUID) {
        if let draft = loadAnonymousDraft() {
            save(draft, forKey: Key.user(userID))
            clearAnonymousDraft()
        }
        hasKnownAccount = true
    }

    func loadDraft(for userID: UUID) -> OnboardingDraft? {
        load(forKey: Key.user(userID))
    }

    private func save(_ draft: OnboardingDraft, forKey key: String) {
        guard let data = try? encoder.encode(draft) else { return }
        defaults.set(data, forKey: key)
    }

    private func load(forKey key: String) -> OnboardingDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let draft = try? decoder.decode(OnboardingDraft.self, from: data),
              draft.schemaVersion == OnboardingDraft.currentSchemaVersion else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return draft
    }
}

final class InMemoryOnboardingStore: OnboardingStoreProtocol {
    var hasKnownAccount = false
    var anonymousDraft: OnboardingDraft?
    var userDrafts: [UUID: OnboardingDraft] = [:]

    func loadAnonymousDraft() -> OnboardingDraft? { anonymousDraft }
    func saveAnonymousDraft(_ draft: OnboardingDraft) { anonymousDraft = draft }
    func clearAnonymousDraft() { anonymousDraft = nil }

    func associateAnonymousDraft(with userID: UUID) {
        if let anonymousDraft {
            userDrafts[userID] = anonymousDraft
            self.anonymousDraft = nil
        }
        hasKnownAccount = true
    }

    func loadDraft(for userID: UUID) -> OnboardingDraft? {
        userDrafts[userID]
    }
}
```

- [ ] **Step 4: Inject the store**

Add `let onboardingStore: OnboardingStoreProtocol` to `Dependencies`, accept it in the initializer, use `UserDefaultsOnboardingStore()` in `.live()`, and `InMemoryOnboardingStore()` in `.mock()`.

The initializer shape must be:

```swift
init(
    api: APIClientProtocol,
    keychain: KeychainServiceProtocol,
    appState: AppState,
    onboardingStore: OnboardingStoreProtocol
)
```

- [ ] **Step 5: Run storage tests and build**

Run the focused storage test, then the required generic simulator build.

Expected: tests pass and build succeeds.

- [ ] **Step 6: Commit persistence**

```bash
git add Core/Storage/OnboardingStore.swift App/Dependencies.swift peppyTests/OnboardingStoreTests.swift peppy.xcodeproj
git commit -m "feat: persist onboarding drafts locally"
```

## Task 4: Add Permission Service Boundaries

**Files:**
- Create: `Core/Permissions/HealthKitService.swift`
- Create: `Core/Permissions/NotificationPermissionService.swift`
- Create: `peppy.entitlements`
- Modify through Xcode: `peppy.xcodeproj/project.pbxproj`
- Modify: `App/Dependencies.swift`
- Test: `peppyTests/PermissionServiceTests.swift`

- [ ] **Step 1: Write deterministic mock-service tests**

Create `peppyTests/PermissionServiceTests.swift`:

```swift
import XCTest
@testable import peppy

final class PermissionServiceTests: XCTestCase {
    func testMockHealthServiceReturnsConfiguredOutcome() async {
        let service = MockHealthKitService(outcome: .unavailable)
        XCTAssertEqual(await service.requestReadAccess(), .unavailable)
    }

    func testMockNotificationServiceReturnsConfiguredOutcome() async {
        let service = MockNotificationPermissionService(outcome: .denied)
        XCTAssertEqual(await service.requestAuthorization(), .denied)
    }
}
```

- [ ] **Step 2: Run and verify compile failure**

Use `-only-testing:peppyTests/PermissionServiceTests`.

Expected: compile failure because the service types do not exist.

- [ ] **Step 3: Implement HealthKit access**

Create `Core/Permissions/HealthKitService.swift`:

```swift
import HealthKit

protocol HealthKitServiceProtocol {
    var isAvailable: Bool { get }
    func requestReadAccess() async -> PermissionOutcome
}

final class HealthKitService: HealthKitServiceProtocol {
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestReadAccess() async -> PermissionOutcome {
        guard isAvailable else { return .unavailable }

        let types: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.workoutType()
        ].compactMap { $0 }.reduce(into: Set<HKObjectType>()) { result, type in
            result.insert(type)
        }

        do {
            try await store.requestAuthorization(toShare: [], read: types)
            return .requested
        } catch {
            return .failed
        }
    }
}

struct MockHealthKitService: HealthKitServiceProtocol {
    var outcome: PermissionOutcome
    var isAvailable: Bool { outcome != .unavailable }

    func requestReadAccess() async -> PermissionOutcome {
        outcome
    }
}
```

Use `.requested`, not `.authorized`, after a successful HealthKit prompt because HealthKit does not reveal per-read-type authorization.

- [ ] **Step 4: Implement notification authorization**

Create `Core/Permissions/NotificationPermissionService.swift`:

```swift
import UserNotifications

protocol NotificationPermissionServiceProtocol {
    func requestAuthorization() async -> PermissionOutcome
}

final class NotificationPermissionService: NotificationPermissionServiceProtocol {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> PermissionOutcome {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .authorized : .denied
        } catch {
            return .failed
        }
    }
}

struct MockNotificationPermissionService: NotificationPermissionServiceProtocol {
    var outcome: PermissionOutcome

    func requestAuthorization() async -> PermissionOutcome {
        outcome
    }
}
```

- [ ] **Step 5: Configure the HealthKit capability in Xcode**

In the app target:

1. **Signing & Capabilities → + Capability → HealthKit**
2. Confirm Xcode creates `peppy.entitlements` containing:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
</dict>
</plist>
```

3. Add this generated Info.plist value to both Debug and Release:

```text
Privacy - Health Share Usage Description
Peppy reads selected health data to personalize your baseline, trends, and insights.
```

Confirm `CODE_SIGN_ENTITLEMENTS = peppy.entitlements`.

- [ ] **Step 6: Inject live and mock services**

Extend `Dependencies` with:

```swift
let healthKit: HealthKitServiceProtocol
let notifications: NotificationPermissionServiceProtocol
```

Use `HealthKitService()` and `NotificationPermissionService()` in `.live()`. Use mocks configured with `.requested` and `.authorized` in `.mock()`.

- [ ] **Step 7: Run tests and build**

Expected: permission tests pass and the generic simulator build succeeds with `CODE_SIGNING_ALLOWED=NO`.

- [ ] **Step 8: Commit permissions**

```bash
git add Core/Permissions App/Dependencies.swift peppy.entitlements peppy.xcodeproj peppyTests/PermissionServiceTests.swift
git commit -m "feat: add onboarding permission services"
```

## Task 5: Implement and Test the App Flow Coordinator

**Files:**
- Create: `App/AppFlowCoordinator.swift`
- Modify: `App/AppState.swift`
- Modify: `App/Dependencies.swift`
- Test: `peppyTests/AppFlowCoordinatorTests.swift`

- [ ] **Step 1: Write launch and transition tests**

Create `peppyTests/AppFlowCoordinatorTests.swift`:

```swift
import XCTest
@testable import peppy

@MainActor
final class AppFlowCoordinatorTests: XCTestCase {
    func testFreshInstallStartsOnboarding() async {
        let fixture = Fixture()
        await fixture.coordinator.resolveLaunch()
        XCTAssertEqual(fixture.coordinator.route, .onboarding)
    }

    func testKnownSignedOutAccountStartsSignIn() async {
        let fixture = Fixture()
        fixture.store.hasKnownAccount = true
        await fixture.coordinator.resolveLaunch()
        XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
    }

    func testCompletedDraftStartsReadySummary() async {
        let fixture = Fixture()
        var draft = OnboardingDraft()
        draft.isComplete = true
        fixture.store.saveAnonymousDraft(draft)
        await fixture.coordinator.resolveLaunch()
        XCTAssertEqual(fixture.coordinator.route, .readySummary)
    }

    func testValidSessionStartsDashboard() async throws {
        let fixture = Fixture()
        try fixture.keychain.save("access", for: KeychainKeys.accessToken)
        fixture.api.setMockResponse(
            User(id: UUID(), email: "alex@example.com", createdAt: Date()),
            for: "/auth/me"
        )

        await fixture.coordinator.resolveLaunch()

        XCTAssertEqual(fixture.coordinator.route, .dashboard)
        XCTAssertTrue(fixture.appState.isAuthenticated)
    }

    func testTemporarySessionFailureKeepsLaunchingWithRetryError() async throws {
        let fixture = Fixture()
        try fixture.keychain.save("access", for: KeychainKeys.accessToken)
        fixture.api.setMockError(.networkUnavailable, for: "/auth/me")

        await fixture.coordinator.resolveLaunch()

        XCTAssertEqual(fixture.coordinator.route, .launching)
        XCTAssertEqual(fixture.coordinator.launchError, .networkUnavailable)
        XCTAssertEqual(fixture.keychain.get(KeychainKeys.accessToken), "access")
    }

    private struct Fixture {
        let api = MockAPIClient()
        let keychain = MockKeychainService()
        let appState = AppState()
        let store = InMemoryOnboardingStore()
        let coordinator: AppFlowCoordinator

        init() {
            coordinator = AppFlowCoordinator(
                api: api,
                keychain: keychain,
                appState: appState,
                onboardingStore: store
            )
        }
    }
}
```

- [ ] **Step 2: Run and verify failure**

Use `-only-testing:peppyTests/AppFlowCoordinatorTests`.

Expected: compile failure because `AppFlowCoordinator` and route types do not exist.

- [ ] **Step 3: Implement coordinator routing**

Create `App/AppFlowCoordinator.swift`:

```swift
import Foundation

enum AuthenticationMode: Equatable {
    case register
    case signIn
}

enum AppRoute: Equatable {
    case launching
    case onboarding
    case readySummary
    case futurePaywall
    case authentication(AuthenticationMode)
    case dashboard
}

@MainActor
@Observable
final class AppFlowCoordinator {
    var route: AppRoute = .launching
    var launchError: APIError?

    private let api: APIClientProtocol
    private let keychain: KeychainServiceProtocol
    private let appState: AppState
    private let onboardingStore: OnboardingStoreProtocol

    init(
        api: APIClientProtocol,
        keychain: KeychainServiceProtocol,
        appState: AppState,
        onboardingStore: OnboardingStoreProtocol
    ) {
        self.api = api
        self.keychain = keychain
        self.appState = appState
        self.onboardingStore = onboardingStore
    }

    func resolveLaunch() async {
        launchError = nil

        guard keychain.get(KeychainKeys.accessToken) != nil else {
            resolveSignedOutRoute()
            return
        }

        do {
            let user: User = try await api.execute(.me)
            appState.login(user: user)
            onboardingStore.hasKnownAccount = true
            route = .dashboard
        } catch let error as APIError {
            if error == .unauthorized {
                keychain.delete(KeychainKeys.accessToken)
                keychain.delete(KeychainKeys.refreshToken)
                resolveSignedOutRoute()
            } else {
                launchError = error
                route = .launching
            }
        } catch {
            launchError = .unknown(error.localizedDescription)
            route = .launching
        }
    }

    func showSignIn() {
        route = .authentication(.signIn)
    }

    func showRegistration() {
        route = .authentication(.register)
    }

    func showReadySummary() {
        route = .readySummary
    }

    func continueFromReadySummary() {
        route = .futurePaywall
    }

    func advancePastFuturePaywall() {
        route = .authentication(.register)
    }

    func didAuthenticate(user: User) {
        onboardingStore.associateAnonymousDraft(with: user.id)
        onboardingStore.hasKnownAccount = true
        appState.login(user: user)
        route = .dashboard
    }

    func logout() {
        keychain.delete(KeychainKeys.accessToken)
        keychain.delete(KeychainKeys.refreshToken)
        appState.logout()
        route = .authentication(.signIn)
    }

    private func resolveSignedOutRoute() {
        if onboardingStore.hasKnownAccount {
            route = .authentication(.signIn)
        } else if onboardingStore.loadAnonymousDraft()?.isComplete == true {
            route = .readySummary
        } else {
            route = .onboarding
        }
    }
}
```

Add `import Observation` beside `import Foundation` so the macro dependency is explicit.

- [ ] **Step 4: Inject the coordinator without creating dependency cycles**

Change `Dependencies` to accept `flow: AppFlowCoordinator`. In `.live()` and `.mock()`, create API, Keychain, AppState, and OnboardingStore first, then initialize the coordinator with those instances.

The final stored properties are:

```swift
let api: APIClientProtocol
let keychain: KeychainServiceProtocol
let appState: AppState
let onboardingStore: OnboardingStoreProtocol
let healthKit: HealthKitServiceProtocol
let notifications: NotificationPermissionServiceProtocol
let flow: AppFlowCoordinator
```

- [ ] **Step 5: Run coordinator tests**

Expected: all launch-routing tests pass.

- [ ] **Step 6: Commit coordinator behavior**

```bash
git add App/AppFlowCoordinator.swift App/AppState.swift App/Dependencies.swift peppyTests/AppFlowCoordinatorTests.swift peppy.xcodeproj
git commit -m "feat: add deterministic app flow routing"
```

## Task 6: Build the Onboarding View Model with TDD

**Files:**
- Create: `Features/Onboarding/ViewModels/OnboardingViewModel.swift`
- Test: `peppyTests/OnboardingViewModelTests.swift`

- [ ] **Step 1: Write progression, persistence, and validation tests**

Create `peppyTests/OnboardingViewModelTests.swift`:

```swift
import XCTest
@testable import peppy

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testResumeLoadsSavedStep() {
        let store = InMemoryOnboardingStore()
        var draft = OnboardingDraft()
        draft.currentStep = .weight
        draft.age = 32
        store.saveAnonymousDraft(draft)

        let model = OnboardingViewModel(
            store: store,
            healthKit: MockHealthKitService(outcome: .requested),
            notifications: MockNotificationPermissionService(outcome: .authorized)
        )

        XCTAssertEqual(model.draft.currentStep, .weight)
        XCTAssertEqual(model.draft.age, 32)
    }

    func testAgeUpdatePersistsImmediately() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)
        model.setAge(32)
        XCTAssertEqual(store.loadAnonymousDraft()?.age, 32)
    }

    func testCompletingNotificationStepMarksDraftComplete() async {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)
        model.draft.currentStep = .notifications

        await model.requestNotifications()

        XCTAssertTrue(model.draft.isComplete)
        XCTAssertEqual(model.draft.notificationOutcome, .authorized)
        XCTAssertTrue(store.loadAnonymousDraft()?.isComplete == true)
    }

    func testSkippingLeavesValueAbsent() {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)
        model.draft.currentStep = .age
        model.skipCurrentStep()
        XCTAssertNil(model.draft.age)
        XCTAssertEqual(model.draft.currentStep, .height)
    }

    private func makeModel(store: InMemoryOnboardingStore) -> OnboardingViewModel {
        OnboardingViewModel(
            store: store,
            healthKit: MockHealthKitService(outcome: .requested),
            notifications: MockNotificationPermissionService(outcome: .authorized)
        )
    }
}
```

- [ ] **Step 2: Run and verify failure**

Expected: compile failure because `OnboardingViewModel` does not exist.

- [ ] **Step 3: Implement the observable model**

Create `Features/Onboarding/ViewModels/OnboardingViewModel.swift` with:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    enum NavigationDirection {
        case forward
        case backward
    }

    var draft: OnboardingDraft
    var isRequestingPermission = false
    var navigationDirection: NavigationDirection = .forward

    private let store: OnboardingStoreProtocol
    private let healthKit: HealthKitServiceProtocol
    private let notifications: NotificationPermissionServiceProtocol

    init(
        store: OnboardingStoreProtocol,
        healthKit: HealthKitServiceProtocol,
        notifications: NotificationPermissionServiceProtocol
    ) {
        self.store = store
        self.healthKit = healthKit
        self.notifications = notifications
        self.draft = store.loadAnonymousDraft() ?? OnboardingDraft()
    }

    func setAge(_ age: Int?) {
        draft.age = age
        save()
    }

    func setHeightCentimeters(_ value: Double?, unit: HeightUnit) {
        draft.heightCentimeters = value
        draft.preferredHeightUnit = unit
        save()
    }

    func setWeightKilograms(_ value: Double?, unit: WeightUnit) {
        draft.weightKilograms = value
        draft.preferredWeightUnit = unit
        save()
    }

    func togglePeptide(_ name: String) {
        if draft.selectedPeptides.contains(name) {
            draft.selectedPeptides.removeAll { $0 == name }
        } else {
            draft.selectedPeptides.append(name)
        }
        save()
    }

    func setOtherMedications(_ value: String) {
        draft.otherMedications = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
        save()
    }

    func setWorkoutDays(_ days: Int?) {
        draft.workoutDaysPerWeek = days
        save()
    }

    func toggleGoal(_ goal: OnboardingGoal) {
        if draft.goals.contains(goal) {
            draft.goals.remove(goal)
        } else {
            draft.goals.insert(goal)
        }
        save()
    }

    func setCustomGoal(_ value: String) {
        draft.customGoal = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
        save()
    }

    func continueToNextStep() {
        guard let next = draft.currentStep.next else { return }
        navigationDirection = .forward
        draft.currentStep = next
        save()
    }

    func goBack() {
        guard let previous = draft.currentStep.previous else { return }
        navigationDirection = .backward
        draft.currentStep = previous
        save()
    }

    func skipCurrentStep() {
        if draft.currentStep == .health {
            draft.healthChoice = .skipped
        }
        if draft.currentStep == .notifications {
            draft.notificationChoice = .skipped
            complete()
            return
        }
        continueToNextStep()
    }

    func requestHealthAccess() async {
        isRequestingPermission = true
        draft.healthChoice = .requested
        draft.healthOutcome = await healthKit.requestReadAccess()
        isRequestingPermission = false
        continueToNextStep()
    }

    func requestNotifications() async {
        isRequestingPermission = true
        draft.notificationChoice = .requested
        draft.notificationOutcome = await notifications.requestAuthorization()
        isRequestingPermission = false
        complete()
    }

    func complete() {
        draft.isComplete = true
        save()
    }

    private func save() {
        draft.updatedAt = Date()
        store.saveAnonymousDraft(draft)
    }
}
```

- [ ] **Step 4: Keep one stable view model in `Dependencies`**

Add:

```swift
let onboardingViewModel: OnboardingViewModel
```

Create it once in `.live()` and `.mock()` from the same onboarding store and permission-service instances that the rest of `Dependencies` uses. This prevents SwiftUI body recomputation from recreating draft state.

- [ ] **Step 5: Run the view-model tests**

Expected: all progression and persistence tests pass.

- [ ] **Step 6: Commit view-model behavior**

```bash
git add Features/Onboarding/ViewModels/OnboardingViewModel.swift peppyTests/OnboardingViewModelTests.swift peppy.xcodeproj
git commit -m "feat: add onboarding state management"
```

## Task 7: Add Shared Figma-Matched Onboarding Components

**Files:**
- Create: `Design/Components/PepOnboardingProgress.swift`
- Create: `Design/Components/PepSelectionChip.swift`
- Create: `Features/Onboarding/Views/OnboardingScaffold.swift`
- Modify if measurements require it: `Design/Colors.swift`
- Modify if measurements require it: `Design/Spacing.swift`

- [ ] **Step 1: Implement the seven-segment progress control**

Create `Design/Components/PepOnboardingProgress.swift`:

```swift
import SwiftUI

struct PepOnboardingProgress: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.pepPrimary : Color.pepPrimary.opacity(0.18))
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep) of \(totalSteps)")
    }
}
```

- [ ] **Step 2: Implement selectable pills**

Create `Design/Components/PepSelectionChip.swift`:

```swift
import SwiftUI

struct PepSelectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.pepPrimaryDark : Color.pepTextPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(isSelected ? Color.pepPrimaryMuted : Color.pepSurface)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.pepPrimary : Color.pepBorder, lineWidth: 1)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

- [ ] **Step 3: Implement the common screen scaffold**

Create `Features/Onboarding/Views/OnboardingScaffold.swift`:

```swift
import SwiftUI

struct OnboardingScaffold<Content: View>: View {
    let step: Int?
    let title: Text
    let subtitle: String
    let primaryTitle: String
    let canGoBack: Bool
    let showsSkip: Bool
    let isPrimaryLoading: Bool
    let primaryAction: () -> Void
    let backAction: () -> Void
    let skipAction: () -> Void
    let content: Content

    init(
        step: Int?,
        title: Text,
        subtitle: String,
        primaryTitle: String = "Continue",
        canGoBack: Bool = true,
        showsSkip: Bool = true,
        isPrimaryLoading: Bool = false,
        primaryAction: @escaping () -> Void,
        backAction: @escaping () -> Void,
        skipAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.step = step
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.canGoBack = canGoBack
        self.showsSkip = showsSkip
        self.isPrimaryLoading = isPrimaryLoading
        self.primaryAction = primaryAction
        self.backAction = backAction
        self.skipAction = skipAction
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if canGoBack {
                    HStack {
                        Button(action: backAction) {
                            Image(systemName: "chevron.left")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                }
                PeppyLogo(size: 28)
            }

            if let step {
                PepOnboardingProgress(currentStep: step, totalSteps: 7)
                    .padding(.top, 22)
                Text("Step \(step) of 7")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.pepPrimary)
                    .padding(.top, 10)
            }

            title
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.pepTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 28)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Color.pepTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)

            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                PepButton(
                    title: primaryTitle,
                    isLoading: isPrimaryLoading,
                    action: primaryAction
                )
                if canGoBack {
                    PepButton(title: "Back", style: .secondary, action: backAction)
                }
                if showsSkip {
                    Button("Skip this step", action: skipAction)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.pepTextSecondary)
                        .frame(minHeight: 44)
                }
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.pepBackground.ignoresSafeArea())
    }
}
```

- [ ] **Step 4: Add previews for selected and unselected states**

Add `#Preview` blocks at iPhone 15 Pro dimensions and at an accessibility Dynamic Type size. Verify there is no clipping.

- [ ] **Step 5: Build and commit shared UI**

Run the generic simulator build.

```bash
git add Design/Components Features/Onboarding/Views/OnboardingScaffold.swift Design/Colors.swift Design/Spacing.swift peppy.xcodeproj
git commit -m "feat: add onboarding design components"
```

## Task 8: Implement Intro and Baseline Questionnaire Screens

**Files:**
- Create: `Features/Onboarding/Views/OnboardingIntroView.swift`
- Create: `Features/Onboarding/Views/BaselineStepsView.swift`
- Create: `Features/Onboarding/Views/OnboardingFlowView.swift`

- [ ] **Step 1: Implement the intro**

`OnboardingIntroView` must reproduce the Figma card stack:

```swift
import SwiftUI

struct OnboardingIntroView: View {
    let continueAction: () -> Void
    let signInAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)
            PeppyLogo(size: 54)

            (Text("Let's make\n")
                + Text("peppy").foregroundColor(.pepPrimary)
                + Text(" yours."))
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            Text("A few details help peppy organize your protocol and make your trends more meaningful.")
                .font(.system(size: 13))
                .foregroundStyle(Color.pepTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)

            VStack(spacing: 12) {
                benefit(icon: "chart.xyaxis.line", title: "Understand your baseline", body: "Capture key info so peppy can personalize your insights.")
                benefit(icon: "checklist", title: "Track your protocol", body: "Log doses, check-ins, and notes in one simple place.")
                benefit(icon: "point.3.connected.trianglepath.dotted", title: "Connect the dots over time", body: "See how your data, habits, and results come together.")
            }
            .padding(.top, 30)

            Spacer(minLength: 20)

            Label("Your data is private and secure.", systemImage: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.pepTextSecondary)

            PepButton(title: "Continue", action: continueAction)
                .padding(.top, 18)

            Button("Already have an account? Sign in", action: signInAction)
                .font(.system(size: 12))
                .foregroundStyle(Color.pepPrimary)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .background(Color.pepBackground.ignoresSafeArea())
    }

    private func benefit(icon: String, title: String, body: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Color.pepPrimary)
                .frame(width: 42, height: 42)
                .background(Color.pepPrimaryMuted)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(body)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.pepTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
    }
}
```

- [ ] **Step 2: Implement age, height, and weight controls**

Create `BaselineStepsView.swift` containing:

```swift
import SwiftUI

struct AgeStepView: View {
    @Binding var age: Int?

    var body: some View {
        NumericValueCard(
            value: age ?? 32,
            suffix: "years",
            decrement: { age = max(13, (age ?? 32) - 1) },
            increment: { age = min(120, (age ?? 32) + 1) }
        )
    }
}

struct HeightStepView: View {
    @Binding var centimeters: Double?
    @Binding var unit: HeightUnit
    @State private var feet = 5
    @State private var inches = 8

    var body: some View {
        VStack(spacing: 24) {
            Picker("Height unit", selection: $unit) {
                Text("ft / in").tag(HeightUnit.feetAndInches)
                Text("cm").tag(HeightUnit.centimeters)
            }
            .pickerStyle(.segmented)

            if unit == .feetAndInches {
                HStack(spacing: 18) {
                    NumericValueCard(value: feet, suffix: "ft", decrement: {
                        feet = max(3, feet - 1)
                        syncImperial()
                    }, increment: {
                        feet = min(8, feet + 1)
                        syncImperial()
                    })
                    NumericValueCard(value: inches, suffix: "in", decrement: {
                        inches = max(0, inches - 1)
                        syncImperial()
                    }, increment: {
                        inches = min(11, inches + 1)
                        syncImperial()
                    })
                }
            } else {
                NumericValueCard(value: Int(centimeters ?? 173), suffix: "cm", decrement: {
                    centimeters = max(100, (centimeters ?? 173) - 1)
                }, increment: {
                    centimeters = min(250, (centimeters ?? 173) + 1)
                })
            }
        }
    }

    private func syncImperial() {
        centimeters = OnboardingDraft.centimeters(feet: feet, inches: inches)
    }
}

struct WeightStepView: View {
    @Binding var kilograms: Double?
    @Binding var unit: WeightUnit
    @State private var displayedValue = 165

    var body: some View {
        VStack(spacing: 24) {
            Picker("Weight unit", selection: $unit) {
                Text("lb").tag(WeightUnit.pounds)
                Text("kg").tag(WeightUnit.kilograms)
            }
            .pickerStyle(.segmented)

            NumericValueCard(
                value: displayedValue,
                suffix: unit == .pounds ? "lb" : "kg",
                decrement: {
                    displayedValue = max(60, displayedValue - 1)
                    sync()
                },
                increment: {
                    displayedValue = min(700, displayedValue + 1)
                    sync()
                }
            )
        }
    }

    private func sync() {
        kilograms = unit == .pounds
            ? OnboardingDraft.kilograms(pounds: Double(displayedValue))
            : Double(displayedValue)
    }
}

private struct NumericValueCard: View {
    let value: Int
    let suffix: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
            }
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 64, weight: .medium))
                Text(suffix)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.pepTextSecondary)
            }
            Button(action: increment) {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
    }
}
```

Before committing, initialize each control from the persisted draft in `onAppear` so resumed values do not reset to Figma defaults.

- [ ] **Step 3: Add the flow switch**

Create `OnboardingFlowView.swift`. It owns one `@State` view model built from dependencies and switches on `model.draft.currentStep`. Use the exact Figma title/subtitle strings:

```swift
struct OnboardingFlowView: View {
    @Environment(\.dependencies) private var deps
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = deps.onboardingViewModel

        Group {
            switch model.draft.currentStep {
        case .intro:
            OnboardingIntroView(
                continueAction: model.continueToNextStep,
                signInAction: deps.flow.showSignIn
            )
        case .age:
            questionnaire(
                model: model,
                step: 1,
                title: Text("How old are you?"),
                subtitle: "Your age helps peppy contextualize your health patterns and personalize your insights."
            ) {
                AgeStepView(
                    age: Binding(
                        get: { model.draft.age },
                        set: model.setAge
                    )
                )
            }
        case .height:
            questionnaire(
                model: model,
                step: 2,
                title: Text("What's your height?"),
                subtitle: "Your height helps peppy contextualize your health patterns and trends."
            ) {
                HeightStepView(
                    centimeters: Binding(
                        get: { model.draft.heightCentimeters },
                        set: { model.setHeightCentimeters($0, unit: model.draft.preferredHeightUnit) }
                    ),
                    unit: Binding(
                        get: { model.draft.preferredHeightUnit },
                        set: { model.setHeightCentimeters(model.draft.heightCentimeters, unit: $0) }
                    )
                )
            }
        case .weight:
            questionnaire(
                model: model,
                step: 3,
                title: Text("What is your current weight?"),
                subtitle: "This creates your starting point. You can update it during daily check-ins."
            ) {
                WeightStepView(
                    kilograms: Binding(
                        get: { model.draft.weightKilograms },
                        set: { model.setWeightKilograms($0, unit: model.draft.preferredWeightUnit) }
                    ),
                    unit: Binding(
                        get: { model.draft.preferredWeightUnit },
                        set: { model.setWeightKilograms(model.draft.weightKilograms, unit: $0) }
                    )
                )
            }
        case .peptides, .medications, .workout, .goals, .health, .notifications:
            EmptyView()
            }
        }
        .id(model.draft.currentStep)
        .transition(stepTransition(for: model))
        .animation(.easeOut(duration: 0.24), value: model.draft.currentStep)
    }

    private func questionnaire<Content: View>(
        model: OnboardingViewModel,
        step: Int,
        title: Text,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        OnboardingScaffold(
            step: step,
            title: title,
            subtitle: subtitle,
            primaryAction: model.continueToNextStep,
            backAction: model.goBack,
            skipAction: model.skipCurrentStep,
            content: content
        )
    }

    private func stepTransition(for model: OnboardingViewModel) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let insertion: Edge = model.navigationDirection == .forward ? .trailing : .leading
        let removal: Edge = model.navigationDirection == .forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: removal).combined(with: .opacity)
        )
    }
}
```

Tasks 9 and 10 replace each temporary `EmptyView` as its screen is implemented; no temporary case remains at completion.

The core switch represented above is:

```swift
switch model.draft.currentStep {
case .intro:
    OnboardingIntroView(
        continueAction: model.continueToNextStep,
        signInAction: deps.flow.showSignIn
    )
case .age:
    questionnaire(title: "How old are you?", subtitle: "Your age helps peppy contextualize your health patterns and personalize your insights.") {
        AgeStepView(age: ageBinding)
    }
case .height:
    questionnaire(title: "What's your height?", subtitle: "Your height helps peppy contextualize your health patterns and trends.") {
        HeightStepView(centimeters: heightBinding, unit: heightUnitBinding)
    }
case .weight:
    questionnaire(title: "What is your current weight?", subtitle: "This creates your starting point. You can update it during daily check-ins.") {
        WeightStepView(kilograms: weightBinding, unit: weightUnitBinding)
    }
default:
    Color.pepBackground
}
```

- [ ] **Step 4: Build and visually inspect previews**

Expected: intro, age, height, and weight compile and visually follow the Figma frames.

- [ ] **Step 5: Commit baseline screens**

```bash
git add Features/Onboarding/Views peppy.xcodeproj
git commit -m "feat: add onboarding intro and baseline steps"
```

## Task 9: Implement Peptide, Medication, Workout, and Goal Steps

**Files:**
- Create: `Core/Data/PeptideCatalog.swift`
- Create: `Features/Onboarding/Views/PeptidesStepView.swift`
- Create: `Features/Onboarding/Views/MedicationsStepView.swift`
- Create: `Features/Onboarding/Views/WorkoutStepView.swift`
- Create: `Features/Onboarding/Views/GoalsStepView.swift`
- Modify: `Features/Onboarding/Views/OnboardingFlowView.swift`

- [x] **Step 1: Port the shared peptide names**

Create `Core/Data/PeptideCatalog.swift` as an alphabetized, deduplicated Swift array matching Android's existing `PeptideData.kt` names. The public API is:

```swift
enum PeptideCatalog {
    static let names: [String] = [
        "ACE-031",
        "Albiglutide",
        "AOD-9604",
        "Argireline",
        "BPC-157",
        "Cagrilintide",
        "Cerebrolysin",
        "CJC-1295",
        "CJC-1295 DAC",
        "Copper Peptides",
        "Dihexa",
        "DSIP (Delta Sleep)",
        "Dulaglutide",
        "Epitalon",
        "Epithalon",
        "Exenatide",
        "Follistatin",
        "FTPP (Adipotide)",
        "GHK-Cu",
        "GnRH (Gonadorelin)",
        "GHRP-2",
        "GHRP-6",
        "Hexarelin",
        "IGF-1 DES",
        "IGF-1 LR3",
        "Insulin (Humalog)",
        "Insulin (Lantus)",
        "Insulin (Novolog)",
        "Ipamorelin",
        "Kisspeptin",
        "LL-37",
        "Liraglutide",
        "Lixisenatide",
        "Macimorelin",
        "Matrixyl",
        "Melanotan I (Afamelanotide)",
        "Melanotan II",
        "MGF (Mechano Growth Factor)",
        "MK-677 (Ibutamoren)",
        "NA-Selank",
        "NA-Semax",
        "Oxytocin",
        "P21",
        "Palmitoyl Pentapeptide",
        "PEG-MGF",
        "Pegvisomant",
        "Pentadecapeptide",
        "PT-141 (Bremelanotide)",
        "Retatrutide",
        "Selank",
        "Semaglutide",
        "Semax",
        "Sermorelin",
        "Setmelanotide",
        "Survodutide",
        "TB-500 (Thymosin Beta-4)",
        "Tesamorelin",
        "Thymosin Alpha-1",
        "Thymalin",
        "Tirzepatide",
        "Vasopressin",
        "Vosoritide"
    ]
}
```

Add `XCTAssertEqual(Set(PeptideCatalog.names).count, PeptideCatalog.names.count)` to `OnboardingDraftTests` to protect the catalog from duplicate display options. Do not include dose guidance in onboarding.

- [x] **Step 2: Implement searchable peptide multi-select**

`PeptidesStepView` contains a Figma-styled search field, selected chips, and a bounded suggestion list:

```swift
struct PeptidesStepView: View {
    let selected: [String]
    let toggle: (String) -> Void
    @State private var query = ""

    private var suggestions: [String] {
        guard !query.isEmpty else { return [] }
        return PeptideCatalog.names
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !selected.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selected, id: \.self) { name in
                        PepSelectionChip(title: name, isSelected: true) {
                            toggle(name)
                        }
                    }
                }
            }

            PepTextField(placeholder: "Search peptides", text: $query)

            ForEach(suggestions, id: \.self) { name in
                Button {
                    toggle(name)
                    query = ""
                } label: {
                    HStack {
                        Text(name)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(minHeight: 44)
                }
            }
        }
    }
}
```

Implement `FlowLayout` as a small `Layout` type in the same file with measured wrapping; do not use horizontal scrolling because the Figma wraps chips.

```swift
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        var points: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }

        return (
            CGSize(width: min(usedWidth, maxWidth), height: y + rowHeight),
            points
        )
    }
}
```

- [x] **Step 3: Implement medications and workouts**

`MedicationsStepView` uses an optional multiline `TextEditor` with a 200-character counter and the medical-context disclaimer.

`WorkoutStepView` renders 0 through 7 as tappable circles, shows `Rest-focused` for 0 and `2–5 days per week` style summary text for selected ranges, and calls `setWorkoutDays`.

- [x] **Step 4: Implement goals**

`GoalsStepView` lays out the six `OnboardingGoal` options in a two-column adaptive grid using `PepSelectionChip`, followed by an optional `PepTextField` for "Anything else?".

- [x] **Step 5: Wire all four cases into the flow**

Add `.peptides`, `.medications`, `.workout`, and `.goals` cases with exact 4/7 through 7/7 progress, Figma copy, and persisted bindings.

- [x] **Step 6: Build questionnaire completion**

```bash
xcodebuild -project peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Completed locally on 2026-06-16:
- Added `PeptideCatalog` and the four SwiftUI step views.
- Wired `.peptides`, `.medications`, `.workout`, and `.goals` into `OnboardingFlowView` as questionnaire steps 4 through 7.
- Added focused tests for catalog uniqueness, peptide suggestions/custom options, medication limits, workout summaries, goal options, and Task 9 flow metadata.
- Verification passed: focused Task 9 tests, full iOS suite with 47 tests, generic simulator debug build with `CODE_SIGNING_ALLOWED=NO`, and `git diff --check`.
- Commit intentionally deferred; continue task-by-task unless a commit is requested.

## Task 10: Implement Permission Screens and Ready Summary

**Files:**
- Create: `Features/Onboarding/Views/HealthPermissionView.swift`
- Create: `Features/Onboarding/Views/NotificationPermissionView.swift`
- Create: `Features/Onboarding/Views/ReadySummaryView.swift`
- Modify: `Features/Onboarding/Views/OnboardingFlowView.swift`

- [x] **Step 1: Implement Apple Health explanation**

The screen lists the seven read categories from the Figma and provides:

```swift
PepButton(
    title: "Continue to Apple Health",
    style: .destructive,
    isLoading: model.isRequestingPermission
) {
    Task { await model.requestHealthAccess() }
}

Button("Not now") {
    model.skipCurrentStep()
}
```

Use the Apple Health icon from SF Symbols where permitted, a read-only access card, and copy stating users can change access in the Health app.

- [x] **Step 2: Implement notification explanation**

Match the Figma "Stay consistent without the noise" frame with cards for dose reminders, check-in reminders, and important insights. The primary action calls `requestNotifications()`; "Not now" marks the draft complete.

- [x] **Step 3: Implement the truthful personalized summary**

Create `ReadySummaryView` with:

```swift
struct ReadySummaryView: View {
    let draft: OnboardingDraft
    let continueAction: () -> Void
    let signInAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                PeppyLogo(size: 40)
                Text("You're ready.")
                    .font(.system(size: 31, weight: .bold, design: .serif))
                Text("Your baseline and preferences are ready to personalize peppy.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
                    .multilineTextAlignment(.center)

                if let age = draft.age {
                    summaryRow(icon: "birthday.cake", title: "Baseline", value: "Age \(age)")
                }
                if !draft.selectedPeptides.isEmpty {
                    summaryRow(icon: "pills", title: "Peptides", value: draft.selectedPeptides.joined(separator: ", "))
                }
                if let days = draft.workoutDaysPerWeek {
                    summaryRow(icon: "figure.run", title: "Activity", value: "\(days) days per week")
                }
                if !draft.goals.isEmpty {
                    summaryRow(icon: "target", title: "Goals", value: draft.goals.map(\.title).sorted().joined(separator: ", "))
                }
                summaryRow(
                    icon: "heart.text.square",
                    title: "Apple Health",
                    value: draft.healthOutcome == .requested ? "Requested" : "Not connected"
                )
                summaryRow(
                    icon: "bell",
                    title: "Notifications",
                    value: draft.notificationOutcome == .authorized ? "Enabled" : "Not enabled"
                )

                PepButton(title: "Go to my dashboard", action: continueAction)
                Button("Already have an account? Sign in", action: signInAction)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(minHeight: 44)
            }
            .padding(24)
        }
        .background(Color.pepBackground.ignoresSafeArea())
    }

    private func summaryRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.pepPrimary)
                .frame(width: 38, height: 38)
                .background(Color.pepPrimaryMuted)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.pepTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
    }
}
```

Do not display protocol names, check-in streaks, or connected-source counts unless the draft actually contains them.

- [x] **Step 4: Complete the flow transition**

When `.notifications` finishes or is skipped:

1. `OnboardingViewModel.complete()` persists completion.
2. `OnboardingFlowView` calls `deps.flow.showReadySummary()`.
3. Root renders `ReadySummaryView`.
4. Primary action sets `.futurePaywall`.
5. The future-paywall route immediately calls `advancePastFuturePaywall()` and ends on `.authentication(.register)`.

- [x] **Step 5: Build post-questionnaire screens**

```bash
xcodebuild -project peppy.xcodeproj -scheme peppy -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Completed locally on 2026-06-17:
- Added `HealthPermissionView`, `NotificationPermissionView`, and `ReadySummaryView`.
- Wired `.health` and `.notifications` in `OnboardingFlowView`; notification request and skip now complete the draft before showing the ready-summary route.
- Added focused tests for permission screen metadata, Health read categories, notification cards, truthful ready-summary rows, and notification completion routing.
- Verification passed: Task 10 red test failed for missing permission flow cases, focused Task 10 tests, full iOS suite with 54 tests on `iPhone 17` iOS 26.5, generic simulator debug build with `CODE_SIGNING_ALLOWED=NO`, and `git diff --check`.
- Root-level rendering of `.readySummary`, future-paywall bypass rendering, and authentication handoff remain in Task 11 as planned.
- Commit intentionally deferred; continue task-by-task unless a commit is requested.

## Task 11: Replace Root Routing and Connect Authentication

**Files:**
- Modify: `App/RootView.swift`
- Modify: `App/PeppyApp.swift`
- Modify: `Features/Auth/Views/LoginView.swift`
- Modify: `Features/Auth/Views/RegisterView.swift`
- Modify: `Features/Auth/Views/WelcomeView.swift`
- Test: `peppyTests/AppFlowCoordinatorTests.swift`

- [x] **Step 1: Add auth association tests**

Add:

```swift
func testAuthenticationAssociatesDraftAndRoutesToDashboard() {
    let fixture = Fixture()
    var draft = OnboardingDraft()
    draft.isComplete = true
    fixture.store.saveAnonymousDraft(draft)
    let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())

    fixture.coordinator.didAuthenticate(user: user)

    XCTAssertEqual(fixture.coordinator.route, .dashboard)
    XCTAssertNil(fixture.store.loadAnonymousDraft())
    XCTAssertNotNil(fixture.store.loadDraft(for: user.id))
}

func testLogoutRoutesToSignInWithoutClearingProfile() {
    let fixture = Fixture()
    let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
    fixture.coordinator.didAuthenticate(user: user)

    fixture.coordinator.logout()

    XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
    XCTAssertTrue(fixture.store.hasKnownAccount)
}

func testReadySummaryPassesThroughFuturePaywallRoute() {
    let fixture = Fixture()
    fixture.coordinator.continueFromReadySummary()
    XCTAssertEqual(fixture.coordinator.route, .futurePaywall)

    fixture.coordinator.advancePastFuturePaywall()
    XCTAssertEqual(fixture.coordinator.route, .authentication(.register))
}
```

Run coordinator tests and confirm the association test passes with Task 5's implementation.

- [x] **Step 2: Replace conditional root rendering**

`RootView` switches on `deps.flow.route`:

```swift
switch deps.flow.route {
case .launching:
    LaunchResolutionView(
        error: deps.flow.launchError,
        retry: { Task { await deps.flow.resolveLaunch() } }
    )
case .onboarding:
    OnboardingFlowView()
case .readySummary:
    ReadySummaryView(
        draft: deps.onboardingStore.loadAnonymousDraft() ?? OnboardingDraft(),
        continueAction: deps.flow.continueFromReadySummary,
        signInAction: deps.flow.showSignIn
    )
case .futurePaywall:
    Color.pepBackground
        .ignoresSafeArea()
        .task { deps.flow.advancePastFuturePaywall() }
case .authentication(let mode):
    NavigationStack {
        if mode == .register {
            RegisterView()
        } else {
            LoginView()
        }
    }
case .dashboard:
    MainTabView()
}
```

Keep `.pepToast($appState.toast)` at the root and call `resolveLaunch()` once from `.task`.

`LaunchResolutionView` visually matches the native launch screen. If `error` is non-nil, show its user message and a Retry button without exposing onboarding or auth.

- [x] **Step 3: Connect registration success**

In `RegisterView.register()`, replace direct `appState.login(user:)` with:

```swift
deps.flow.didAuthenticate(user: user)
deps.appState.showSuccess("Welcome to Peppy!")
```

Keep tokens saved before fetching `/auth/me`. Preserve the current form and toast behavior on failure.

- [x] **Step 4: Connect sign-in success**

In `LoginView.login()`, replace direct `appState.login(user:)` with:

```swift
deps.flow.didAuthenticate(user: user)
```

Change navigation links so registration and sign-in switch coordinator mode instead of nesting duplicate navigation stacks.

For the auth back buttons:

```swift
let hasCompletedAnonymousDraft =
    deps.onboardingStore.loadAnonymousDraft()?.isComplete == true
```

- Registration back returns to `.readySummary` when that value is true.
- Sign-in back returns to `.readySummary` only when entered from onboarding.
- A known signed-out account launched directly into sign-in does not show a back button.
- "Already have an account? Sign in" calls `showSignIn()`.
- "Create account" from sign-in calls `showRegistration()`.

- [x] **Step 5: Retire the old welcome route**

`WelcomeView` is no longer the launch destination. Keep it temporarily only if another preview or product reference uses it; otherwise remove it from the target after confirming no references with:

```bash
rg -n "WelcomeView" .
```

If removed, delete it through Xcode so the project file stays valid.

- [x] **Step 6: Build and test routing**

Run all unit tests and the generic simulator build.

```bash
git add App Features/Auth peppyTests/AppFlowCoordinatorTests.swift peppy.xcodeproj
git commit -m "feat: connect onboarding to authentication"
```

Completed locally on 2026-06-17:
- Added Task 11 coverage for coordinator auth back-routing, root route destination selection, login completion handoff, registration completion handoff, known-account logout behavior, fresh onboarding sign-in back routing, and auth back-button accessibility labels.
- Replaced `RootView`'s `appState.isAuthenticated` conditional with `deps.flow.route` rendering for launch, onboarding, ready summary, future-paywall bypass, authentication, and dashboard routes.
- Added `LaunchResolutionView` with retry/error handling for launch resolution without exposing onboarding or auth while a retryable launch error is active.
- Guarded root launch resolution so `resolveLaunch()` only runs while the coordinator is still on `.launching`.
- Connected registration and sign-in success to `AppFlowCoordinator.didAuthenticate(user:)`; registration still shows the existing success toast.
- Replaced nested auth `NavigationLink` handoffs with coordinator route switches and coordinator-owned auth back behavior.
- Fixed the review-found fresh-onboarding sign-in trap: intro sign-in can now return to onboarding, sign-in to registration preserves that back path, and known signed-out launch sign-in still hides back.
- Added accessible Back labels to auth icon back buttons.
- Retired `WelcomeView` from launch routing; it remains in the target temporarily for preview/product reference only.
- Verification passed: Task 11 red tests failed for missing coordinator/root/auth helper seams, the root launch-resolution guard, and auth back-button accessibility labels; focused `AppFlowCoordinatorTests` with 20 tests, full iOS suite with 64 tests on `iPhone 17` iOS 26.5, and generic simulator debug build with `CODE_SIGNING_ALLOWED=NO`.
- Commit intentionally deferred; continue task-by-task unless a commit is requested.

## Task 12: Create the App Icon and Native Launch Screen

**Files:**
- Create: `Design/Assets 2.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Modify: `Design/Assets 2.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Design/Assets 2.xcassets/LaunchLogo.imageset/`
- Create: `Design/Assets 2.xcassets/LaunchBackground.colorset/`
- Create: `LaunchScreen.storyboard`
- Modify through Xcode: `peppy.xcodeproj/project.pbxproj`

- [ ] **Step 1: Extract the higher-resolution P source from the supplied Figma**

```bash
mkdir -p /tmp/peppy-icon-source
unzip -p '/Users/gabrielcontreras/Downloads/Peppy IOS.fig' \
  images/8daa9b390da3cd2461fb3a6461bfac7fc65ae619 \
  > /tmp/peppy-icon-source/peppy-p.png
sips -g pixelWidth -g pixelHeight /tmp/peppy-icon-source/peppy-p.png
```

Expected: `256 x 384`, which is higher resolution than the checked-in 81x90 mark and preserves the supplied brand source.

- [ ] **Step 2: Generate opaque icon and transparent launch assets**

Use the bundled Node runtime and `sharp` to trim the transparent source, resize it with high-quality resampling, and compose:

```text
AppIcon-1024.png
- 1024x1024
- opaque #FDF9F6 background
- P mark centered
- mark bounding box approximately 430x500

launch-logo.png
- 512x512 transparent canvas
- P mark centered
- mark bounding box approximately 190x220
```

Run:

```bash
NODE_PATH='/Users/gabrielcontreras/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules' \
'/Users/gabrielcontreras/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node' \
-e '
const sharp = require("sharp");
const source = "/tmp/peppy-icon-source/peppy-p.png";
const icon = "Design/Assets 2.xcassets/AppIcon.appiconset/AppIcon-1024.png";
const launch = "Design/Assets 2.xcassets/LaunchLogo.imageset/launch-logo.png";
(async () => {
  const trimmed = sharp(source).trim();
  const iconMark = await trimmed.clone().resize({
    width: 430,
    height: 500,
    fit: "inside",
    kernel: sharp.kernel.lanczos3
  }).png().toBuffer();
  await sharp({
    create: { width: 1024, height: 1024, channels: 4, background: "#FDF9F6FF" }
  }).composite([{ input: iconMark, gravity: "center" }]).removeAlpha().png().toFile(icon);

  const launchMark = await sharp(source).trim().resize({
    width: 190,
    height: 220,
    fit: "inside",
    kernel: sharp.kernel.lanczos3
  }).png().toBuffer();
  await sharp({
    create: { width: 512, height: 512, channels: 4, background: "#00000000" }
  }).composite([{ input: launchMark, gravity: "center" }]).png().toFile(launch);
})();
'
```

Inspect both generated assets at 100% and small icon size. The P must remain crisp, centered optically, and free of unintended black transparent-canvas fill.

- [ ] **Step 3: Update asset catalog metadata**

`AppIcon.appiconset/Contents.json` must be:

```json
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Add `LaunchBackground` as an sRGB color asset using `FDF9F6` and `LaunchLogo` as a universal image set.

- [ ] **Step 4: Add a launch storyboard through Xcode**

Create `LaunchScreen.storyboard` with:

```text
Root view background: LaunchBackground
Centered image view: LaunchLogo
Content mode: Aspect Fit
Width: 128 points
Height: 128 points
Center X/Y constraints: 0
```

Add it to the app target's resources. Set **Launch Screen File** to `LaunchScreen` and disable the empty generated launch screen setting if Xcode keeps both.

- [ ] **Step 5: Match the first SwiftUI frame**

`LaunchResolutionView` uses the same `LaunchBackground` color and `LaunchLogo` asset with the same apparent 128-point box, preventing a launch flash.

- [ ] **Step 6: Build and inspect**

Run the generic build. Then launch on a simulator and verify:

- P appears immediately.
- No blank white frame.
- No stretched image.
- App icon appears as the P on the Home Screen.

- [ ] **Step 7: Commit branding**

```bash
git add 'Design/Assets 2.xcassets' LaunchScreen.storyboard App/RootView.swift peppy.xcodeproj
git commit -m "feat: add Peppy app icon and launch screen"
```

## Task 13: Write the Backend Integration Contract

**Files:**
- Create: `BACKEND.md`

- [ ] **Step 1: Document the proposed profile resource**

Define a versioned payload with normalized units:

```json
{
  "schema_version": 1,
  "age": 32,
  "height_cm": 172.72,
  "preferred_height_unit": "ft_in",
  "weight_kg": 74.84,
  "preferred_weight_unit": "lb",
  "peptides": ["Retatrutide"],
  "custom_peptides": [],
  "other_medications": null,
  "workout_days_per_week": 3,
  "goals": ["track_protocols", "see_what_works"],
  "custom_goal": null,
  "healthkit": {
    "requested": true,
    "last_sync_at": null
  },
  "notifications": {
    "authorized": true
  },
  "updated_at": "2026-06-14T18:00:00Z"
}
```

- [ ] **Step 2: Specify MVP endpoints and behavior**

Document:

```text
GET   /api/v1/profile/onboarding
PUT   /api/v1/profile/onboarding
PATCH /api/v1/profile/onboarding
POST  /api/v1/profile/onboarding/attach
```

Include authentication, idempotency key behavior, 200/201/400/401/409/422 responses, partial/skipped values, `updated_at` conflict semantics, and migration from the local schema version.

- [ ] **Step 3: Specify personalization consumers**

Name how dashboard, check-ins, protocol creation, insights, reminders, connected health, exports, and account deletion consume or remove each field. Separate MVP-required work from later recommendations.

- [ ] **Step 4: Specify privacy and device integration**

Cover consent timestamps, field provenance, HealthKit sample IDs and sync cursors, deduplication, data export, deletion, auditability, device token registration, notification preferences, logout, reinstall, and cross-device restoration.

- [ ] **Step 5: Review and commit documentation**

Check:

```bash
rg -n "TBD|TODO|later$|fill in" BACKEND.md
```

Expected: no unresolved placeholders.

```bash
git add BACKEND.md
git commit -m "docs: define onboarding backend contract"
```

## Task 14: Accessibility, Visual QA, and End-to-End Verification

**Files:**
- Modify only files with observed defects from Tasks 7–12
- Reference: `/Users/gabrielcontreras/Downloads/Peppy IOS.fig`

- [ ] **Step 1: Run the complete unit suite**

```bash
xcodebuild \
  -project peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

Expected: all `peppyTests` pass.

- [ ] **Step 2: Run the required build**

```bash
xcodebuild \
  -project peppy.xcodeproj \
  -scheme peppy \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify fresh-install flow**

On an available iPhone simulator:

1. Delete Peppy.
2. Install and launch.
3. Confirm P launch screen.
4. Complete all seven questionnaire steps.
5. Deny HealthKit and notifications.
6. Confirm denial does not block ready summary.
7. Tap `Go to my dashboard`.
8. Confirm registration appears.
9. Confirm sign-in escape works.

- [ ] **Step 4: Verify resume and returning-user routing**

Run these independent checks:

```text
Force-quit on each onboarding step → relaunch resumes that step.
Complete onboarding → relaunch shows ready summary.
Registration API failure → draft remains.
Successful auth → dashboard.
Authenticated relaunch → dashboard.
Logout → sign-in.
Signed-out relaunch with known account → sign-in.
```

- [ ] **Step 5: Run visual comparison for every Figma screen**

Capture simulator screenshots for:

```text
Launch
Intro
Age
Height ft/in
Height cm
Weight lb
Weight kg
Peptides empty/search/selected
Medications
Workout
Goals
Apple Health
Notifications
Ready summary
Registration
Sign-in
```

Compare each screenshot beside its Figma frame at the same device aspect ratio. Correct visible differences in position, spacing, typography, line height, color, border, radius, icon scale, and control state. Repeat comparison after each correction.

- [ ] **Step 6: Verify accessibility**

Check:

```text
Dynamic Type at Accessibility 2 does not clip primary actions.
VoiceOver announces step, title, selected pills, values, and icon buttons.
Reduce Motion replaces directional transitions with a dissolve.
All controls have at least 44x44-point hit areas.
Color is not the only selected/error indicator.
Keyboard does not cover medication, custom-goal, email, or password fields.
```

- [ ] **Step 7: Review the final diff**

```bash
git diff --check
git status --short
git diff --stat
```

Confirm no changes to unrelated workspace state, backend, Android, web, or credentials.

- [ ] **Step 8: Commit final QA fixes**

```bash
git add App Core Design Features BACKEND.md peppy.xcodeproj peppyTests
git commit -m "fix: polish iOS onboarding flow"
```

## Completion Criteria

- All tests pass.
- The required generic simulator build succeeds.
- Fresh, resumed, authenticated, signed-out, and logout routes behave as specified.
- Onboarding answers persist locally and associate with the authenticated user ID.
- Apple Health and notification prompts are real and optional.
- Figma comparison has been completed for every flow screen.
- App icon and launch screen use the supplied P mark.
- `BACKEND.md` contains the complete deferred integration contract.
- No unrelated local changes are overwritten.
