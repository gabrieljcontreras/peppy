import Foundation
import Observation

enum AuthenticationMode: Equatable {
    case register
    case signIn
}

enum AppRoute: Equatable {
    case launching
    case onboarding
    case readySummary
    case paywall
    case authentication(AuthenticationMode)
    case dashboard
}

@MainActor
@Observable
final class AppFlowCoordinator {
    var route: AppRoute = .launching
    var launchError: APIError?
    var hasProfileAttachFailure = false
    private var authenticationBackStack: [AppRoute] = []

    private let api: APIClientProtocol
    private let keychain: KeychainServiceProtocol
    private let appState: AppState
    private let onboardingStore: OnboardingStoreProtocol
    private let prepareSessionData: @MainActor (User) -> Void
    private let resetSessionData: @MainActor () -> Void
    private let cleanupAuthenticatedSessionData:
        @MainActor (String?) async -> Void

    init(
        api: APIClientProtocol,
        keychain: KeychainServiceProtocol,
        appState: AppState,
        onboardingStore: OnboardingStoreProtocol,
        prepareSessionData: @escaping @MainActor (User) -> Void = { _ in },
        resetSessionData: @escaping @MainActor () -> Void = {},
        cleanupAuthenticatedSessionData:
            @escaping @MainActor (String?) async -> Void = { _ in }
    ) {
        self.api = api
        self.keychain = keychain
        self.appState = appState
        self.onboardingStore = onboardingStore
        self.prepareSessionData = prepareSessionData
        self.resetSessionData = resetSessionData
        self.cleanupAuthenticatedSessionData = cleanupAuthenticatedSessionData
    }

    func resolveLaunch() async {
        launchError = nil
        authenticationBackStack = []

        guard keychain.get(KeychainKeys.accessToken) != nil else {
            await cleanupAuthenticatedSessionData(nil)
            resetSessionData()
            keychain.invalidateAuthenticatedSession()
            resolveSignedOutRoute()
            return
        }

        do {
            let user: User = try await api.execute(.me)
            await resetForNewSession(ifNeeded: user.id)
            prepareSessionData(user)
            appState.login(user: user)
            onboardingStore.hasKnownAccount = true
            route = .dashboard
        } catch {
            await resolveFailedSessionRestoration()
        }
    }

    func showSignIn() {
        switch route {
        case .onboarding:
            authenticationBackStack = [.onboarding]
        case .readySummary:
            authenticationBackStack = [.readySummary]
        case .authentication(.register):
            if authenticationBackStack.last == .authentication(.signIn) {
                authenticationBackStack.removeLast()
            } else if authenticationBackStack.isEmpty && hasCompletedAnonymousDraft {
                authenticationBackStack = [.readySummary]
            }
        default:
            if hasCompletedAnonymousDraft {
                authenticationBackStack = [.readySummary]
            }
        }
        route = .authentication(.signIn)
    }

    func showRegistration() {
        switch route {
        case .readySummary:
            authenticationBackStack = [.readySummary]
        case .authentication(.signIn):
            authenticationBackStack.append(.authentication(.signIn))
        default:
            authenticationBackStack = hasCompletedAnonymousDraft ? [.readySummary] : []
        }
        route = .authentication(.register)
    }

    func showReadySummary() {
        authenticationBackStack = []
        route = .readySummary
    }

    func continueFromReadySummary() {
        authenticationBackStack = [.readySummary]
        route = .authentication(.register)
    }

    /// Leaves the post-registration paywall without purchasing. Free accounts
    /// are a real tier — Check-ins and Protocols still work.
    func dismissPaywall() {
        route = .dashboard
    }

    func didAuthenticate(user: User, isNewAccount: Bool = false) async {
        await resetForNewSession(ifNeeded: user.id)
        hasProfileAttachFailure = false
        if let draft = onboardingStore.loadAnonymousDraft(), draft.isComplete {
            do {
                let _: OnboardingProfilePayload = try await api.execute(
                    .attachOnboardingProfile(OnboardingProfileAttachRequest(draft: draft))
                )
                onboardingStore.associateAnonymousDraft(with: user.id)
            } catch {
                hasProfileAttachFailure = true
                onboardingStore.hasKnownAccount = true
            }
        } else {
            onboardingStore.associateAnonymousDraft(with: user.id)
        }
        prepareSessionData(user)
        appState.login(user: user)
        authenticationBackStack = []
        route = isNewAccount ? .paywall : .dashboard
    }

    func logout() async {
        let accessToken = keychain.get(KeychainKeys.accessToken)
        let refreshToken = keychain.get(KeychainKeys.refreshToken)
        guard appState.isAuthenticated
            || accessToken != nil
            || refreshToken != nil else {
            return
        }

        // Clear shared credentials before exposing sign-in. Remote cleanup uses
        // only this immutable access-token snapshot and can never refresh or
        // mutate credentials belonging to a later session.
        finishLocalSignedOutSession()
        await cleanupAuthenticatedSessionData(accessToken)
        if let accessToken {
            try? await api.executeVoid(
                .logout,
                authenticatedBy: accessToken
            )
        }
    }

    /// Completes a server-confirmed password rotation or account deletion.
    /// Remote notification cleanup remains best effort, while local cleanup is
    /// unconditional and centralized in one transition.
    func finishSignedOutSession() async {
        finishLocalSignedOutSession()
        await cleanupAuthenticatedSessionData(nil)
    }

    private func finishLocalSignedOutSession() {
        resetSessionData()
        keychain.invalidateAuthenticatedSession()
        appState.logout()
        authenticationBackStack = []
        route = .authentication(.signIn)
    }

    /// The app-facing logout path. Authenticated cleanup runs before credentials
    /// are deleted so APNs can unregister the exact server device record.
    func logoutAndWait() async {
        await logout()
    }

    var shouldShowAuthenticationBackButton: Bool {
        !authenticationBackStack.isEmpty
    }

    func goBackFromAuthentication() {
        guard let previousRoute = authenticationBackStack.popLast() else { return }
        route = previousRoute
    }

    private func resolveFailedSessionRestoration() async {
        await cleanupAuthenticatedSessionData(
            keychain.get(KeychainKeys.accessToken)
        )
        resetSessionData()
        keychain.invalidateAuthenticatedSession()
        onboardingStore.hasKnownAccount = true
        appState.logout()
        launchError = nil
        authenticationBackStack = []
        route = .authentication(.signIn)
    }

    private func resolveSignedOutRoute() {
        if onboardingStore.hasKnownAccount {
            authenticationBackStack = []
            route = .authentication(.signIn)
        } else if onboardingStore.loadAnonymousDraft()?.isComplete == true {
            route = .readySummary
        } else {
            route = .onboarding
        }
    }

    private var hasCompletedAnonymousDraft: Bool {
        onboardingStore.loadAnonymousDraft()?.isComplete == true
    }

    private func resetForNewSession(ifNeeded userID: UUID) async {
        guard appState.currentUser?.id != userID else { return }
        if appState.currentUser != nil {
            await cleanupAuthenticatedSessionData(
                keychain.get(KeychainKeys.accessToken)
            )
        }
        resetSessionData()
    }
}
