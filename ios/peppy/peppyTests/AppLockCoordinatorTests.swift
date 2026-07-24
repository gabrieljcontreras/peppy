import SwiftUI
import XCTest
@testable import peppy

@MainActor
final class AppLockCoordinatorTests: XCTestCase {
    func testDisabledColdLaunchDoesNotCoverOrAuthenticate() async {
        let fixture = Fixture()

        await fixture.coordinator.authenticatedSessionBecameVisible(
            userID: fixture.userID
        )

        XCTAssertFalse(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertFalse(fixture.coordinator.requiresUnlock)
        XCTAssertEqual(fixture.authenticator.authenticateCallCount, 0)
    }

    func testEnabledSessionIsCoveredBeforeColdLaunchAuthentication() async {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)

        fixture.coordinator.prepareForAuthenticatedSession(userID: fixture.userID)

        XCTAssertTrue(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertTrue(fixture.coordinator.requiresUnlock)
        XCTAssertEqual(fixture.authenticator.authenticateCallCount, 0)

        fixture.authenticator.results = [true]
        await fixture.coordinator.authenticatedSessionBecameVisible(
            userID: fixture.userID
        )

        XCTAssertFalse(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertFalse(fixture.coordinator.requiresUnlock)
        XCTAssertEqual(fixture.authenticator.authenticateCallCount, 1)
    }

    func testFourMinuteResumeRemovesCoverWithoutAnotherPrompt() async {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)
        fixture.authenticator.results = [true]
        await fixture.coordinator.authenticatedSessionBecameVisible(
            userID: fixture.userID
        )

        await fixture.coordinator.scenePhaseChanged(.background)
        fixture.clock.advance(by: 4 * 60)
        await fixture.coordinator.scenePhaseChanged(.active)

        XCTAssertFalse(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertFalse(fixture.coordinator.requiresUnlock)
        XCTAssertEqual(fixture.authenticator.authenticateCallCount, 1)
    }

    func testFiveMinuteResumeRequiresAnotherPrompt() async {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)
        fixture.authenticator.results = [true, false]
        await fixture.coordinator.authenticatedSessionBecameVisible(
            userID: fixture.userID
        )

        await fixture.coordinator.scenePhaseChanged(.background)
        fixture.clock.advance(by: AppLockCoordinator.timeout)
        await fixture.coordinator.scenePhaseChanged(.active)

        XCTAssertTrue(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertTrue(fixture.coordinator.requiresUnlock)
        XCTAssertEqual(fixture.authenticator.authenticateCallCount, 2)
    }

    func testBackgroundImmediatelyShowsPrivacyCover() async {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)
        fixture.authenticator.results = [true]
        await fixture.coordinator.authenticatedSessionBecameVisible(
            userID: fixture.userID
        )

        fixture.coordinator.scenePhaseWillChange(.background)

        XCTAssertTrue(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertFalse(fixture.coordinator.requiresUnlock)
    }

    func testSuccessfulFiveMinuteUnlockRemovesPrivacyCover() async {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)
        fixture.authenticator.results = [true, true]
        await fixture.coordinator.authenticatedSessionBecameVisible(
            userID: fixture.userID
        )

        await fixture.coordinator.scenePhaseChanged(.background)
        fixture.clock.advance(by: AppLockCoordinator.timeout)
        await fixture.coordinator.scenePhaseChanged(.active)

        XCTAssertFalse(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertFalse(fixture.coordinator.requiresUnlock)
    }

    func testCancelledAuthenticationLeavesPrivacyCoverInPlace() async {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)
        fixture.authenticator.results = [false]

        await fixture.coordinator.authenticatedSessionBecameVisible(
            userID: fixture.userID
        )

        XCTAssertTrue(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertTrue(fixture.coordinator.requiresUnlock)
    }

    func testUnavailableFaceIDLeavesCoverAndExposesActionableReason() async {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)
        fixture.authenticator.currentAvailability = .unavailable(.notEnrolled)

        await fixture.coordinator.authenticatedSessionBecameVisible(
            userID: fixture.userID
        )

        XCTAssertTrue(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertTrue(fixture.coordinator.requiresUnlock)
        XCTAssertEqual(fixture.coordinator.unavailabilityReason, .notEnrolled)
        XCTAssertEqual(fixture.authenticator.authenticateCallCount, 0)
    }

    func testRetryUnlockAuthenticatesAgainAfterCancellation() async {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)
        fixture.authenticator.results = [false, true]
        await fixture.coordinator.authenticatedSessionBecameVisible(
            userID: fixture.userID
        )

        await fixture.coordinator.retryUnlock()

        XCTAssertEqual(fixture.authenticator.authenticateCallCount, 2)
        XCTAssertFalse(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertFalse(fixture.coordinator.requiresUnlock)
    }

    func testEnablingAppLockPersistsOnlyAfterSuccessfulFaceID() async {
        let fixture = Fixture()
        fixture.authenticator.results = [false, true]

        let cancelled = await fixture.coordinator.setEnabled(
            true,
            for: fixture.userID
        )
        XCTAssertEqual(cancelled, .cancelled)
        XCTAssertFalse(fixture.preferences.isEnabled(for: fixture.userID))

        let enabled = await fixture.coordinator.setEnabled(
            true,
            for: fixture.userID
        )
        XCTAssertEqual(enabled, .enabled)
        XCTAssertTrue(fixture.preferences.isEnabled(for: fixture.userID))
    }

    func testUnavailableFaceIDCannotEnableAppLock() async {
        let fixture = Fixture()
        fixture.authenticator.currentAvailability = .unavailable(.notAvailable)

        let result = await fixture.coordinator.setEnabled(
            true,
            for: fixture.userID
        )

        XCTAssertEqual(result, .unavailable(.notAvailable))
        XCTAssertFalse(fixture.preferences.isEnabled(for: fixture.userID))
        XCTAssertEqual(fixture.authenticator.authenticateCallCount, 0)
    }

    func testDisablingAppLockDoesNotAuthenticate() async {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)
        fixture.coordinator.prepareForAuthenticatedSession(userID: fixture.userID)

        let result = await fixture.coordinator.setEnabled(
            false,
            for: fixture.userID
        )

        XCTAssertEqual(result, .disabled)
        XCTAssertFalse(fixture.preferences.isEnabled(for: fixture.userID))
        XCTAssertFalse(fixture.coordinator.isPrivacyCoverVisible)
        XCTAssertFalse(fixture.coordinator.requiresUnlock)
        XCTAssertEqual(fixture.authenticator.authenticateCallCount, 0)
    }

    func testUsePasswordInsteadInvokesNormalLogoutAndKeepsContentCovered() {
        let fixture = Fixture()
        fixture.preferences.setEnabled(true, for: fixture.userID)
        fixture.coordinator.prepareForAuthenticatedSession(userID: fixture.userID)

        fixture.coordinator.usePasswordInstead()

        XCTAssertEqual(fixture.logoutCallCount, 1)
        XCTAssertTrue(fixture.coordinator.isPrivacyCoverVisible)
    }

    func testUserDefaultsPreferencesAreScopedPerUser() {
        let suiteName = "AppLockCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = UserDefaultsAppLockPreferences(defaults: defaults)
        let firstUserID = UUID()
        let secondUserID = UUID()

        preferences.setEnabled(true, for: firstUserID)

        XCTAssertTrue(preferences.isEnabled(for: firstUserID))
        XCTAssertFalse(preferences.isEnabled(for: secondUserID))

        preferences.removePreference(for: firstUserID)
        XCTAssertFalse(preferences.isEnabled(for: firstUserID))
    }

    func testPrivacyCoverOnlyOverlaysAuthenticatedDashboardContent() {
        XCTAssertTrue(
            RootView.shouldPresentAppLockCover(
                route: .dashboard,
                isCoverVisible: true
            )
        )
        XCTAssertFalse(
            RootView.shouldPresentAppLockCover(
                route: .authentication(.signIn),
                isCoverVisible: true
            )
        )
        XCTAssertFalse(
            RootView.shouldPresentAppLockCover(
                route: .dashboard,
                isCoverVisible: false
            )
        )
    }
}

@MainActor
private final class Fixture {
    let userID = UUID()
    let authenticator = MockAppLockAuthenticator()
    let preferences = InMemoryAppLockPreferences()
    let clock = MutableClock()
    var logoutCallCount = 0

    lazy var coordinator = AppLockCoordinator(
        authenticator: authenticator,
        preferences: preferences,
        now: { [clock] in clock.now },
        logout: { [weak self] in self?.logoutCallCount += 1 }
    )
}

@MainActor
private final class MockAppLockAuthenticator: AppLockAuthenticating {
    var currentAvailability: AppLockAvailability = .available
    var results: [Bool] = []
    private(set) var authenticateCallCount = 0

    func availability() -> AppLockAvailability {
        currentAvailability
    }

    func authenticate(reason: String) async -> Bool {
        authenticateCallCount += 1
        return results.isEmpty ? false : results.removeFirst()
    }
}

private final class InMemoryAppLockPreferences: AppLockPreferencesProtocol {
    private var enabledUserIDs: Set<UUID> = []

    func isEnabled(for userID: UUID) -> Bool {
        enabledUserIDs.contains(userID)
    }

    func setEnabled(_ isEnabled: Bool, for userID: UUID) {
        if isEnabled {
            enabledUserIDs.insert(userID)
        } else {
            enabledUserIDs.remove(userID)
        }
    }

    func removePreference(for userID: UUID) {
        enabledUserIDs.remove(userID)
    }
}

private final class MutableClock {
    private(set) var now = Date(timeIntervalSince1970: 1_000)

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
