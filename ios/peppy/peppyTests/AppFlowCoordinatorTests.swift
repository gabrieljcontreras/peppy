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
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
        try fixture.keychain.save("access", for: KeychainKeys.accessToken)
        fixture.api.setMockResponse(user, for: "/auth/me")

        await fixture.coordinator.resolveLaunch()

        XCTAssertEqual(fixture.coordinator.route, .dashboard)
        XCTAssertTrue(fixture.appState.isAuthenticated)
        XCTAssertEqual(fixture.appState.currentUser?.id, user.id)
        XCTAssertTrue(fixture.store.hasKnownAccount)
    }

    func testUnauthorizedSessionClearsCredentialsAndUsesSignedOutRoute() async throws {
        let fixture = Fixture()
        try fixture.keychain.save("access", for: KeychainKeys.accessToken)
        try fixture.keychain.save("refresh", for: KeychainKeys.refreshToken)
        fixture.api.setMockError(.unauthorized, for: "/auth/me")

        await fixture.coordinator.resolveLaunch()

        XCTAssertEqual(fixture.coordinator.route, .onboarding)
        XCTAssertNil(fixture.keychain.get(KeychainKeys.accessToken))
        XCTAssertNil(fixture.keychain.get(KeychainKeys.refreshToken))
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

    func testManualAuthenticationRoutesAreExplicit() {
        let fixture = Fixture()

        fixture.coordinator.showSignIn()
        XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))

        fixture.coordinator.showRegistration()
        XCTAssertEqual(fixture.coordinator.route, .authentication(.register))
    }

    func testReadySummaryAdvancesThroughFuturePaywallBypassToRegistration() {
        let fixture = Fixture()

        fixture.coordinator.showReadySummary()
        XCTAssertEqual(fixture.coordinator.route, .readySummary)

        fixture.coordinator.continueFromReadySummary()
        XCTAssertEqual(fixture.coordinator.route, .futurePaywall)

        fixture.coordinator.advancePastFuturePaywall()
        XCTAssertEqual(fixture.coordinator.route, .authentication(.register))
    }

    func testDidAuthenticateAssociatesDraftAndRoutesToDashboard() {
        let fixture = Fixture()
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
        var draft = OnboardingDraft()
        draft.selectedPeptides = ["Retatrutide"]
        fixture.store.saveAnonymousDraft(draft)

        fixture.coordinator.didAuthenticate(user: user)

        XCTAssertEqual(fixture.coordinator.route, .dashboard)
        XCTAssertTrue(fixture.appState.isAuthenticated)
        XCTAssertEqual(fixture.appState.currentUser?.id, user.id)
        XCTAssertNil(fixture.store.loadAnonymousDraft())
        XCTAssertEqual(fixture.store.loadDraft(for: user.id)?.selectedPeptides, ["Retatrutide"])
        XCTAssertTrue(fixture.store.hasKnownAccount)
    }

    func testLogoutClearsCredentialsAndRoutesToSignIn() throws {
        let fixture = Fixture()
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
        fixture.appState.login(user: user)
        try fixture.keychain.save("access", for: KeychainKeys.accessToken)
        try fixture.keychain.save("refresh", for: KeychainKeys.refreshToken)

        fixture.coordinator.logout()

        XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
        XCTAssertFalse(fixture.appState.isAuthenticated)
        XCTAssertNil(fixture.keychain.get(KeychainKeys.accessToken))
        XCTAssertNil(fixture.keychain.get(KeychainKeys.refreshToken))
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
