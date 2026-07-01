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

    func testDidAuthenticateAssociatesDraftAndRoutesToDashboard() async {
        let fixture = Fixture()
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
        var draft = OnboardingDraft()
        draft.selectedPeptides = ["Retatrutide"]
        fixture.store.saveAnonymousDraft(draft)

        await fixture.coordinator.didAuthenticate(user: user)

        XCTAssertEqual(fixture.coordinator.route, .dashboard)
        XCTAssertTrue(fixture.appState.isAuthenticated)
        XCTAssertEqual(fixture.appState.currentUser?.id, user.id)
        XCTAssertNil(fixture.store.loadAnonymousDraft())
        XCTAssertEqual(fixture.store.loadDraft(for: user.id)?.selectedPeptides, ["Retatrutide"])
        XCTAssertTrue(fixture.store.hasKnownAccount)
    }

    func testDidAuthenticateAttemptsProfileAttachAndStillRoutesDashboardOnFailure() async {
        let fixture = Fixture()
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
        var draft = OnboardingDraft()
        draft.isComplete = true
        draft.selectedPeptides = ["Retatrutide"]
        fixture.store.saveAnonymousDraft(draft)
        fixture.api.setMockError(.serverError, for: "/profile/onboarding/attach")

        await fixture.coordinator.didAuthenticate(user: user)

        XCTAssertEqual(fixture.coordinator.route, .dashboard)
        XCTAssertTrue(fixture.coordinator.hasProfileAttachFailure)
        XCTAssertNotNil(fixture.store.loadAnonymousDraft())
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

    func testLogoutRoutesToSignInWithoutClearingKnownAccount() async {
        let fixture = Fixture()
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())

        await fixture.coordinator.didAuthenticate(user: user)
        fixture.coordinator.logout()

        XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
        XCTAssertTrue(fixture.store.hasKnownAccount)
    }

    func testAuthenticationBackRouteReturnsCompletedDraftToReadySummary() {
        let fixture = Fixture()
        var draft = OnboardingDraft()
        draft.isComplete = true
        fixture.store.saveAnonymousDraft(draft)

        fixture.coordinator.showRegistration()

        XCTAssertTrue(fixture.coordinator.shouldShowAuthenticationBackButton)
        fixture.coordinator.goBackFromAuthentication()
        XCTAssertEqual(fixture.coordinator.route, .readySummary)
    }

    func testKnownSignedOutSignInDoesNotShowBackButton() async {
        let fixture = Fixture()
        fixture.store.hasKnownAccount = true

        await fixture.coordinator.resolveLaunch()

        XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
        XCTAssertFalse(fixture.coordinator.shouldShowAuthenticationBackButton)
    }

    func testOnboardingSignInBackReturnsToOnboarding() {
        let fixture = Fixture()
        fixture.coordinator.route = .onboarding

        fixture.coordinator.showSignIn()

        XCTAssertTrue(fixture.coordinator.shouldShowAuthenticationBackButton)
        fixture.coordinator.goBackFromAuthentication()
        XCTAssertEqual(fixture.coordinator.route, .onboarding)
    }

    func testRegistrationBackPreservesOnboardingSignInBackRoute() {
        let fixture = Fixture()
        fixture.coordinator.route = .onboarding
        fixture.coordinator.showSignIn()

        fixture.coordinator.showRegistration()
        fixture.coordinator.goBackFromAuthentication()

        XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
        XCTAssertTrue(fixture.coordinator.shouldShowAuthenticationBackButton)
        fixture.coordinator.goBackFromAuthentication()
        XCTAssertEqual(fixture.coordinator.route, .onboarding)
    }

    func testRootDestinationFollowsCoordinatorRouteInsteadOfAppState() {
        let deps = Dependencies.mock()
        deps.appState.login(
            user: User(id: UUID(), email: "alex@example.com", createdAt: Date())
        )
        deps.flow.route = .onboarding

        XCTAssertEqual(RootView.destination(for: deps), .onboarding)
    }

    func testRootOnlyResolvesLaunchWhileLaunching() {
        let deps = Dependencies.mock()

        deps.flow.route = .futurePaywall
        XCTAssertFalse(RootView.shouldResolveLaunch(for: deps))

        deps.flow.route = .launching
        XCTAssertTrue(RootView.shouldResolveLaunch(for: deps))
    }

    func testLoginCompletionUsesCoordinatorAuthenticationHandoff() async {
        let deps = Dependencies.mock()
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
        var draft = OnboardingDraft()
        draft.isComplete = true
        deps.onboardingStore.saveAnonymousDraft(draft)
        let api = deps.api as! MockAPIClient
        api.setMockResponse(
            OnboardingProfilePayload(draft: draft),
            for: "/profile/onboarding/attach"
        )

        await LoginView.completeLogin(user: user, deps: deps)

        XCTAssertEqual(deps.flow.route, .dashboard)
        XCTAssertTrue(deps.appState.isAuthenticated)
        XCTAssertFalse(deps.flow.hasProfileAttachFailure)
        XCTAssertNil(deps.onboardingStore.loadAnonymousDraft())
        XCTAssertNotNil(deps.onboardingStore.loadDraft(for: user.id))
    }

    func testRegistrationCompletionUsesCoordinatorAuthenticationHandoffAndToast() async {
        let deps = Dependencies.mock()
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
        var draft = OnboardingDraft()
        draft.isComplete = true
        deps.onboardingStore.saveAnonymousDraft(draft)
        let api = deps.api as! MockAPIClient
        api.setMockResponse(
            OnboardingProfilePayload(draft: draft),
            for: "/profile/onboarding/attach"
        )

        await RegisterView.completeRegistration(user: user, deps: deps)

        XCTAssertEqual(deps.flow.route, .dashboard)
        XCTAssertTrue(deps.appState.isAuthenticated)
        XCTAssertFalse(deps.flow.hasProfileAttachFailure)
        XCTAssertNil(deps.onboardingStore.loadAnonymousDraft())
        XCTAssertNotNil(deps.onboardingStore.loadDraft(for: user.id))
        XCTAssertEqual(deps.appState.toast?.message, "Welcome to Peppy!")
    }

    func testAuthBackButtonsExposeAccessibleBackLabel() {
        XCTAssertEqual(LoginView.backButtonAccessibilityLabel, "Back")
        XCTAssertEqual(RegisterView.backButtonAccessibilityLabel, "Back")
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
