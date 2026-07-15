# Peppy iOS Launch Session Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route every failed saved-session restoration directly to returning-user sign-in without showing a server error on the logo screen or sending the user through onboarding.

**Architecture:** Keep `RootView` and the existing authentication screens unchanged. Centralize failed session restoration inside `AppFlowCoordinator`: clear unusable credentials, record that this device belongs to a known account, reset transient authenticated state, and route to `authentication(.signIn)` for both API and raw transport errors.

**Tech Stack:** Swift 5, SwiftUI, Observation, XCTest, Xcode 26.6, iOS 17 minimum deployment target

## Global Constraints

- Preserve the successful `/auth/me` route to `dashboard`.
- Preserve the token-free fresh-install route to onboarding.
- Never send a user with saved credentials through onboarding after restoration fails.
- Keep the existing `LoginView` and its `Create account.` action unchanged.
- Preserve onboarding drafts and per-user local draft data.
- Clear failed access and refresh tokens so restoration is not retried next launch.
- Add no new dependencies and make no backend changes.
- Follow test-driven development: observe the focused regression tests fail before editing production code.

---

### Task 1: Route Failed Session Restoration to Returning-User Authentication

**Files:**
- Modify: `ios/peppy/peppyTests/AppFlowCoordinatorTests.swift:64-87`
- Modify: `ios/peppy/peppyTests/AppFlowCoordinatorTests.swift:287-303`
- Modify: `ios/peppy/App/AppFlowCoordinator.swift:43-70`
- Modify: `ios/peppy/App/AppFlowCoordinator.swift:154-165`

**Interfaces:**
- Consumes: `APIClientProtocol.execute(_:)`, `KeychainServiceProtocol`, `OnboardingStoreProtocol.hasKnownAccount`, `AppState.logout()`, and `AppRoute.authentication(.signIn)`.
- Produces: `AppFlowCoordinator.resolveFailedSessionRestoration() -> Void`, a private coordinator transition used by every `/auth/me` failure path.

- [ ] **Step 1: Replace the old failure expectations and add a raw transport regression test**

In `AppFlowCoordinatorTests.swift`, replace
`testUnauthorizedSessionClearsCredentialsAndUsesSignedOutRoute` and
`testTemporarySessionFailureKeepsLaunchingWithRetryError` with these tests:

```swift
func testUnauthorizedSessionRoutesReturningUserToSignIn() async throws {
    let fixture = Fixture()
    try fixture.keychain.save("access", for: KeychainKeys.accessToken)
    try fixture.keychain.save("refresh", for: KeychainKeys.refreshToken)
    fixture.api.setMockError(.unauthorized, for: "/auth/me")

    await fixture.coordinator.resolveLaunch()

    XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
    XCTAssertNil(fixture.coordinator.launchError)
    XCTAssertFalse(fixture.coordinator.shouldShowAuthenticationBackButton)
    XCTAssertTrue(fixture.store.hasKnownAccount)
    XCTAssertNil(fixture.keychain.get(KeychainKeys.accessToken))
    XCTAssertNil(fixture.keychain.get(KeychainKeys.refreshToken))
}

func testNetworkFailureDuringSessionRestoreRoutesReturningUserToSignIn() async throws {
    let fixture = Fixture()
    try fixture.keychain.save("access", for: KeychainKeys.accessToken)
    try fixture.keychain.save("refresh", for: KeychainKeys.refreshToken)
    fixture.api.setMockError(.networkUnavailable, for: "/auth/me")

    await fixture.coordinator.resolveLaunch()

    XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
    XCTAssertNil(fixture.coordinator.launchError)
    XCTAssertFalse(fixture.coordinator.shouldShowAuthenticationBackButton)
    XCTAssertTrue(fixture.store.hasKnownAccount)
    XCTAssertNil(fixture.keychain.get(KeychainKeys.accessToken))
    XCTAssertNil(fixture.keychain.get(KeychainKeys.refreshToken))
}

func testRawTransportFailureDuringSessionRestoreRoutesReturningUserToSignIn() async throws {
    let keychain = MockKeychainService()
    let appState = AppState()
    let store = InMemoryOnboardingStore()
    let coordinator = AppFlowCoordinator(
        api: ThrowingAPIClient(error: URLError(.cannotConnectToHost)),
        keychain: keychain,
        appState: appState,
        onboardingStore: store
    )
    try keychain.save("access", for: KeychainKeys.accessToken)
    try keychain.save("refresh", for: KeychainKeys.refreshToken)

    await coordinator.resolveLaunch()

    XCTAssertEqual(coordinator.route, .authentication(.signIn))
    XCTAssertNil(coordinator.launchError)
    XCTAssertFalse(coordinator.shouldShowAuthenticationBackButton)
    XCTAssertTrue(store.hasKnownAccount)
    XCTAssertNil(keychain.get(KeychainKeys.accessToken))
    XCTAssertNil(keychain.get(KeychainKeys.refreshToken))
    XCTAssertFalse(appState.isAuthenticated)
}
```

Add this test double inside `AppFlowCoordinatorTests`, immediately before the
existing `Fixture` declaration:

```swift
private final class ThrowingAPIClient: APIClientProtocol {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func execute<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        throw error
    }

    func executeVoid(_ endpoint: Endpoint) async throws {
        throw error
    }
}
```

- [ ] **Step 2: Run the focused tests and verify the regression tests fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:peppyTests/AppFlowCoordinatorTests \
  test
```

Expected: `testUnauthorizedSessionRoutesReturningUserToSignIn`,
`testNetworkFailureDuringSessionRestoreRoutesReturningUserToSignIn`, and
`testRawTransportFailureDuringSessionRestoreRoutesReturningUserToSignIn` fail
because the current coordinator routes to onboarding or remains on
`launching` with a launch error. Existing fresh-install and valid-session
tests remain green.

- [ ] **Step 3: Implement the single failed-restoration transition**

In `AppFlowCoordinator.resolveLaunch()`, replace both existing catch blocks
with one catch that invokes the shared transition:

```swift
func resolveLaunch() async {
    launchError = nil
    authenticationBackStack = []

    guard keychain.get(KeychainKeys.accessToken) != nil else {
        resolveSignedOutRoute()
        return
    }

    do {
        let user: User = try await api.execute(.me)
        appState.login(user: user)
        onboardingStore.hasKnownAccount = true
        route = .dashboard
    } catch {
        resolveFailedSessionRestoration()
    }
}
```

Add the private transition immediately before `resolveSignedOutRoute()`:

```swift
private func resolveFailedSessionRestoration() {
    keychain.delete(KeychainKeys.accessToken)
    keychain.delete(KeychainKeys.refreshToken)
    onboardingStore.hasKnownAccount = true
    appState.logout()
    launchError = nil
    authenticationBackStack = []
    route = .authentication(.signIn)
}
```

Do not call `resolveSignedOutRoute()` here. Direct routing expresses the
returning-user invariant and prevents incomplete or missing local onboarding
metadata from selecting onboarding.

- [ ] **Step 4: Re-run the focused coordinator tests**

Run the same focused command from Step 2.

Expected: `** TEST SUCCEEDED **` with every `AppFlowCoordinatorTests` test
passing, including fresh install, valid session, API failure, and raw
`URLError` coverage.

- [ ] **Step 5: Run the complete iOS test suite**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/peppy/peppy.xcodeproj \
  -scheme peppy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  test
```

Expected: `** TEST SUCCEEDED **` with zero failing tests.

- [ ] **Step 6: Build the Debug app for a generic iOS Simulator**

Run:

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

Expected: `** BUILD SUCCEEDED **` with no Swift compilation errors.

- [ ] **Step 7: Review and commit the focused fix**

Run:

```bash
git diff --check
git diff -- ios/peppy/App/AppFlowCoordinator.swift ios/peppy/peppyTests/AppFlowCoordinatorTests.swift
```

Confirm that only the approved coordinator transition and its regression tests
changed. Then commit:

```bash
git add ios/peppy/App/AppFlowCoordinator.swift ios/peppy/peppyTests/AppFlowCoordinatorTests.swift
git commit -m "fix: route failed session restore to sign in"
```
