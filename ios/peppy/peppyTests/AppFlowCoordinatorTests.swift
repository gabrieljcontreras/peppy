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

    func testUserDecodesAuthMeResponseWithoutCreatedAt() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "email": "alex@example.com",
          "display_name": null,
          "is_verified": false
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(User.self, from: json)

        XCTAssertEqual(user.id.uuidString.lowercased(), "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(user.email, "alex@example.com")
    }

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

    func testFailedSessionRestorationCleansAuthenticatedDataBeforeDeletingCredentials() async throws {
        let api = MockAPIClient()
        let keychain = MockKeychainService()
        let appState = AppState()
        let store = InMemoryOnboardingStore()
        var cleanupCallCount = 0
        var tokenWasAvailableDuringCleanup = false
        let coordinator = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: store,
            cleanupAuthenticatedSessionData: { _ in
                cleanupCallCount += 1
                tokenWasAvailableDuringCleanup =
                    keychain.get(KeychainKeys.accessToken) != nil
            }
        )
        try keychain.save("access", for: KeychainKeys.accessToken)
        api.setMockError(.unauthorized, for: "/auth/me")

        await coordinator.resolveLaunch()

        XCTAssertEqual(cleanupCallCount, 1)
        XCTAssertTrue(tokenWasAvailableDuringCleanup)
        XCTAssertNil(keychain.get(KeychainKeys.accessToken))
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

    func testManualAuthenticationRoutesAreExplicit() {
        let fixture = Fixture()

        fixture.coordinator.showSignIn()
        XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))

        fixture.coordinator.showRegistration()
        XCTAssertEqual(fixture.coordinator.route, .authentication(.register))
    }

    func testRegistrationRoutesToPaywall() async {
        let fixture = Fixture()
        let user = User(
            id: UUID(), email: "new@example.com", displayName: nil, isVerified: false
        )

        await fixture.coordinator.didAuthenticate(user: user, isNewAccount: true)

        XCTAssertEqual(fixture.coordinator.route, .paywall)
    }

    func testSignInSkipsPaywall() async {
        let fixture = Fixture()
        let user = User(
            id: UUID(), email: "returning@example.com", displayName: nil, isVerified: true
        )

        await fixture.coordinator.didAuthenticate(user: user)

        XCTAssertEqual(fixture.coordinator.route, .dashboard)
    }

    func testDismissingPaywallReachesDashboard() async {
        let fixture = Fixture()
        let user = User(
            id: UUID(), email: "new@example.com", displayName: nil, isVerified: false
        )
        await fixture.coordinator.didAuthenticate(user: user, isNewAccount: true)

        fixture.coordinator.dismissPaywall()

        XCTAssertEqual(fixture.coordinator.route, .dashboard)
    }

    func testReadySummaryContinuesStraightToRegistration() {
        let fixture = Fixture()
        fixture.coordinator.showReadySummary()

        fixture.coordinator.continueFromReadySummary()

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

    func testLogoutClearsCredentialsAndRoutesToSignIn() async throws {
        let fixture = Fixture()
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())
        fixture.appState.login(user: user)
        try fixture.keychain.save("access", for: KeychainKeys.accessToken)
        try fixture.keychain.save("refresh", for: KeychainKeys.refreshToken)

        await fixture.coordinator.logout()

        XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
        XCTAssertFalse(fixture.appState.isAuthenticated)
        XCTAssertNil(fixture.keychain.get(KeychainKeys.accessToken))
        XCTAssertNil(fixture.keychain.get(KeychainKeys.refreshToken))
    }

    func testLogoutRoutesToSignInWithoutClearingKnownAccount() async {
        let fixture = Fixture()
        let user = User(id: UUID(), email: "alex@example.com", createdAt: Date())

        await fixture.coordinator.didAuthenticate(user: user)
        await fixture.coordinator.logout()

        XCTAssertEqual(fixture.coordinator.route, .authentication(.signIn))
        XCTAssertTrue(fixture.store.hasKnownAccount)
    }

    func testLogoutAttemptsRemoteLogoutAndAlwaysClearsLocalSession() async throws {
        let api = MockAPIClient()
        let keychain = MockKeychainService()
        let appState = AppState()
        let store = InMemoryOnboardingStore()
        var cleanupCallCount = 0
        var cleanupAccessToken: String?
        let coordinator = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: store,
            cleanupAuthenticatedSessionData: { accessToken in
                cleanupCallCount += 1
                cleanupAccessToken = accessToken
            }
        )
        appState.login(
            user: User(id: UUID(), email: "alex@example.com")
        )
        try keychain.save("access", for: KeychainKeys.accessToken)
        try keychain.save("refresh", for: KeychainKeys.refreshToken)
        api.setMockError(.networkUnavailable, for: .logout)

        await coordinator.logout()

        XCTAssertEqual(cleanupCallCount, 1)
        XCTAssertEqual(cleanupAccessToken, "access")
        XCTAssertEqual(api.requestLog.map(\.requestID), ["POST /auth/logout"])
        XCTAssertEqual(
            api.authenticatedRequestLog.map(\.accessToken),
            ["access"]
        )
        XCTAssertNil(keychain.get(KeychainKeys.accessToken))
        XCTAssertNil(keychain.get(KeychainKeys.refreshToken))
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertEqual(coordinator.route, .authentication(.signIn))
    }

    func testLogoutLeavesAuthenticatedUIBeforeRemoteCleanupFinishes() async throws {
        let api = MockAPIClient()
        let keychain = MockKeychainService()
        let appState = AppState()
        let store = InMemoryOnboardingStore()
        let cleanupStarted = expectation(description: "cleanup started")
        var releaseCleanup: CheckedContinuation<Void, Never>?
        let coordinator = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: store,
            cleanupAuthenticatedSessionData: { _ in
                cleanupStarted.fulfill()
                await withCheckedContinuation { continuation in
                    releaseCleanup = continuation
                }
            }
        )
        appState.login(user: User(id: UUID(), email: "alex@example.com"))
        coordinator.route = .dashboard
        try keychain.save("access", for: KeychainKeys.accessToken)
        try keychain.save("refresh", for: KeychainKeys.refreshToken)

        let logout = Task { await coordinator.logout() }
        await fulfillment(of: [cleanupStarted])

        XCTAssertEqual(coordinator.route, .authentication(.signIn))
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(keychain.get(KeychainKeys.accessToken))
        XCTAssertNil(keychain.get(KeychainKeys.refreshToken))

        releaseCleanup?.resume()
        await logout.value

        XCTAssertNil(keychain.get(KeychainKeys.accessToken))
        XCTAssertNil(keychain.get(KeychainKeys.refreshToken))
    }

    func testNewSessionCanLogoutWhilePreviousSessionCleanupFinishes() async throws {
        let api = MockAPIClient()
        let keychain = MockKeychainService()
        let appState = AppState()
        let store = InMemoryOnboardingStore()
        let firstCleanupStarted = expectation(
            description: "first cleanup started"
        )
        var cleanupCallCount = 0
        var releaseFirstCleanup: CheckedContinuation<Void, Never>?
        let coordinator = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: store,
            cleanupAuthenticatedSessionData: { _ in
                cleanupCallCount += 1
                guard cleanupCallCount == 1 else { return }
                firstCleanupStarted.fulfill()
                await withCheckedContinuation { continuation in
                    releaseFirstCleanup = continuation
                }
            }
        )
        appState.login(user: User(id: UUID(), email: "old@example.com"))
        coordinator.route = .dashboard
        try keychain.save("old-access", for: KeychainKeys.accessToken)
        try keychain.save("old-refresh", for: KeychainKeys.refreshToken)

        let firstLogout = Task { await coordinator.logout() }
        await fulfillment(of: [firstCleanupStarted])

        let newUser = User(id: UUID(), email: "new@example.com")
        try keychain.save("new-access", for: KeychainKeys.accessToken)
        try keychain.save("new-refresh", for: KeychainKeys.refreshToken)
        await coordinator.didAuthenticate(user: newUser)

        let secondLogout = Task { await coordinator.logout() }
        await Task.yield()

        XCTAssertEqual(coordinator.route, .authentication(.signIn))
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(keychain.get(KeychainKeys.accessToken))
        XCTAssertNil(keychain.get(KeychainKeys.refreshToken))
        XCTAssertEqual(cleanupCallCount, 2)

        releaseFirstCleanup?.resume()
        await firstLogout.value
        await secondLogout.value

        XCTAssertEqual(
            Set(api.authenticatedRequestLog.map(\.accessToken)),
            Set(["old-access", "new-access"])
        )
    }

    func testConcurrentLogoutCallsShareOneRemoteCleanup() async throws {
        let api = MockAPIClient()
        let keychain = MockKeychainService()
        let appState = AppState()
        let store = InMemoryOnboardingStore()
        let cleanupStarted = expectation(description: "cleanup started")
        var cleanupCallCount = 0
        var releaseCleanup: CheckedContinuation<Void, Never>?
        let coordinator = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: store,
            cleanupAuthenticatedSessionData: { _ in
                cleanupCallCount += 1
                guard cleanupCallCount == 1 else { return }
                cleanupStarted.fulfill()
                await withCheckedContinuation { continuation in
                    releaseCleanup = continuation
                }
            }
        )
        appState.login(user: User(id: UUID(), email: "alex@example.com"))
        coordinator.route = .dashboard
        try keychain.save("access", for: KeychainKeys.accessToken)

        let firstLogout = Task { await coordinator.logout() }
        await fulfillment(of: [cleanupStarted])
        let secondLogout = Task { await coordinator.logout() }
        await Task.yield()

        XCTAssertEqual(cleanupCallCount, 1)

        releaseCleanup?.resume()
        await firstLogout.value
        await secondLogout.value

        XCTAssertEqual(cleanupCallCount, 1)
        XCTAssertEqual(api.requestLog.map(\.requestID), ["POST /auth/logout"])
    }

    func testServerConfirmedSignOutLeavesAuthenticatedUIBeforeCleanupFinishes() async throws {
        let keychain = MockKeychainService()
        let appState = AppState()
        let cleanupStarted = expectation(description: "cleanup started")
        var releaseCleanup: CheckedContinuation<Void, Never>?
        let coordinator = AppFlowCoordinator(
            api: MockAPIClient(),
            keychain: keychain,
            appState: appState,
            onboardingStore: InMemoryOnboardingStore(),
            cleanupAuthenticatedSessionData: { _ in
                cleanupStarted.fulfill()
                await withCheckedContinuation { continuation in
                    releaseCleanup = continuation
                }
            }
        )
        appState.login(user: User(id: UUID(), email: "alex@example.com"))
        coordinator.route = .dashboard
        try keychain.save("access", for: KeychainKeys.accessToken)
        try keychain.save("refresh", for: KeychainKeys.refreshToken)

        let finish = Task { await coordinator.finishSignedOutSession() }
        await fulfillment(of: [cleanupStarted])

        XCTAssertEqual(coordinator.route, .authentication(.signIn))
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(keychain.get(KeychainKeys.accessToken))
        XCTAssertNil(keychain.get(KeychainKeys.refreshToken))

        releaseCleanup?.resume()
        await finish.value
    }

    func testFailedPushUnregisterDoesNotTrapLogout() async throws {
        let api = MockAPIClient()
        let keychain = MockKeychainService()
        let appState = AppState()
        let store = InMemoryOnboardingStore()
        let deviceID = UUID()
        let registrationStore = TestPushRegistrationStore()
        registrationStore.deviceID = deviceID
        let pushRegistration = PushRegistrationCoordinator(
            api: api,
            registrationStore: registrationStore,
            isSignedIn: { appState.isAuthenticated }
        )
        let coordinator = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: store,
            cleanupAuthenticatedSessionData: { accessToken in
                await pushRegistration.unregister(
                    authenticatedBy: accessToken
                )
            }
        )
        appState.login(
            user: User(id: UUID(), email: "alex@example.com")
        )
        try keychain.save("access", for: KeychainKeys.accessToken)
        try keychain.save("refresh", for: KeychainKeys.refreshToken)
        api.setMockError(
            .networkUnavailable,
            for: .deleteDevice(id: deviceID)
        )

        await coordinator.logout()

        XCTAssertEqual(
            api.requestLog.map(\.requestID),
            [
                "DELETE /notifications/devices/\(deviceID)",
                "POST /auth/logout"
            ]
        )
        XCTAssertEqual(
            api.authenticatedRequestLog.map(\.accessToken),
            ["access", "access"]
        )
        XCTAssertNil(registrationStore.deviceID)
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertEqual(coordinator.route, .authentication(.signIn))
    }

    func testLogoutClearsInsightCache() async {
        let dependencies = Dependencies.mock()
        let api = dependencies.api as! MockAPIClient
        let user = User(id: UUID(), email: "alex@example.com")
        let insight = Insight.fixture()
        dependencies.appState.login(user: user)
        api.setMockResponse(
            [insight],
            for: Endpoint.getInsights(
                unreadOnly: nil,
                type: nil,
                severity: nil
            )
        )
        await dependencies.insightsStore.loadInsights()
        XCTAssertEqual(dependencies.insightsStore.insights.map(\.id), [insight.id])

        await dependencies.flow.logout()

        XCTAssertTrue(dependencies.insightsStore.insights.isEmpty)
        XCTAssertNil(dependencies.insightsStore.weekly)
        XCTAssertNil(dependencies.insightsStore.errorMessage)
    }

    func testLogoutClearsUserACheckinsAndNavigationBeforeUserBLoads() async {
        let dependencies = Dependencies.mock()
        let api = dependencies.api as! MockAPIClient
        let userA = User(id: UUID(), email: "user-a@example.com", createdAt: Date())
        let userB = User(id: UUID(), email: "user-b@example.com", createdAt: Date())
        let userACheckin = makeCheckin(userID: userA.id, energyLevel: 4)
        let userBCheckin = makeCheckin(userID: userB.id, energyLevel: 9)
        dependencies.appState.login(user: userA)
        api.setMockResponse(
            [userACheckin],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await dependencies.checkinStore.load()
        api.setMockResponse(
            userACheckin,
            for: Endpoint.getCheckin(id: userACheckin.id)
        )
        await dependencies.checkinStore.loadDetail(userACheckin.id)
        dependencies.protocolNavigation.selectedTab = .checkin
        dependencies.protocolNavigation.checkinPath = [.detail(userACheckin.id)]

        await dependencies.flow.logout()

        XCTAssertTrue(dependencies.checkinStore.checkins.isEmpty)
        XCTAssertNil(dependencies.checkinStore.selectedCheckin)
        XCTAssertTrue(dependencies.protocolNavigation.checkinPath.isEmpty)
        XCTAssertEqual(dependencies.protocolNavigation.selectedTab, .home)

        await dependencies.flow.didAuthenticate(user: userB)
        api.setMockResponse(
            [userBCheckin],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await dependencies.checkinStore.load()

        XCTAssertEqual(dependencies.checkinStore.checkins, [userBCheckin])
        XCTAssertFalse(dependencies.checkinStore.checkins.contains(userACheckin))
        XCTAssertEqual(
            api.requestLog.filter { endpoint in
                if case .getCheckins = endpoint { return true }
                return false
            }.count,
            2
        )
    }

    func testFailedSessionRestorationClearsCheckinsErrorsAndNavigation() async throws {
        let dependencies = Dependencies.mock()
        let api = dependencies.api as! MockAPIClient
        let record = makeCheckin(userID: UUID(), energyLevel: 4)
        api.setMockResponse(
            [record],
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await dependencies.checkinStore.load()
        api.setMockError(
            .networkUnavailable,
            for: Endpoint.getCheckins(startDate: nil, endDate: nil)
        )
        await dependencies.checkinStore.load(force: true)
        dependencies.protocolNavigation.selectedTab = .checkin
        dependencies.protocolNavigation.checkinPath = [.detail(record.id)]
        try dependencies.keychain.save("access", for: KeychainKeys.accessToken)
        api.setMockError(.unauthorized, for: Endpoint.me)

        await dependencies.flow.resolveLaunch()

        XCTAssertEqual(dependencies.flow.route, .authentication(.signIn))
        XCTAssertTrue(dependencies.checkinStore.checkins.isEmpty)
        XCTAssertNil(dependencies.checkinStore.selectedCheckin)
        XCTAssertNil(dependencies.checkinStore.errorMessage)
        XCTAssertFalse(dependencies.checkinStore.isLoading)
        XCTAssertTrue(dependencies.protocolNavigation.checkinPath.isEmpty)
        XCTAssertEqual(dependencies.protocolNavigation.selectedTab, .home)
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

        deps.flow.route = .paywall
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

        XCTAssertEqual(deps.flow.route, .paywall)
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

        func executeVoid(
            _ endpoint: Endpoint,
            authenticatedBy accessToken: String
        ) async throws {
            throw error
        }

        func download(_ endpoint: Endpoint) async throws -> DownloadedFile {
            throw error
        }
    }

    private final class TestPushRegistrationStore:
        PushRegistrationStoring
    {
        var deviceID: UUID?
    }

    private func makeCheckin(userID: UUID, energyLevel: Int) -> Checkin {
        Checkin(
            id: UUID(),
            userId: userID,
            date: Date(),
            weightKg: nil,
            energyLevel: energyLevel,
            sleepQuality: nil,
            appetiteLevel: nil,
            mood: nil,
            nausea: nil,
            injectionSiteReaction: nil,
            fatigue: nil,
            headache: nil,
            giIssues: nil,
            notes: nil,
            createdAt: nil,
            updatedAt: nil
        )
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
