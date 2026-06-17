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
