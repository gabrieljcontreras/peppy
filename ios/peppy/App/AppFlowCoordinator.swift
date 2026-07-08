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
    case futurePaywall
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
        case .readySummary, .futurePaywall:
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
        route = .futurePaywall
    }

    func advancePastFuturePaywall() {
        authenticationBackStack = [.readySummary]
        route = .authentication(.register)
    }

    func didAuthenticate(user: User) async {
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
        appState.login(user: user)
        authenticationBackStack = []
        route = .dashboard
    }

    func logout() {
        keychain.delete(KeychainKeys.accessToken)
        keychain.delete(KeychainKeys.refreshToken)
        appState.logout()
        authenticationBackStack = []
        route = .authentication(.signIn)
    }

    var shouldShowAuthenticationBackButton: Bool {
        !authenticationBackStack.isEmpty
    }

    func goBackFromAuthentication() {
        guard let previousRoute = authenticationBackStack.popLast() else { return }
        route = previousRoute
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
}
