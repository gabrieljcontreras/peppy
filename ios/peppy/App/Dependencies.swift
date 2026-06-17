import SwiftUI

@Observable
final class Dependencies {
    let api: APIClientProtocol
    let keychain: KeychainServiceProtocol
    let appState: AppState
    let onboardingStore: OnboardingStoreProtocol
    let healthKit: HealthKitServiceProtocol
    let notifications: NotificationPermissionServiceProtocol
    let flow: AppFlowCoordinator
    let onboardingViewModel: OnboardingViewModel

    init(
        api: APIClientProtocol,
        keychain: KeychainServiceProtocol,
        appState: AppState,
        onboardingStore: OnboardingStoreProtocol,
        healthKit: HealthKitServiceProtocol,
        notifications: NotificationPermissionServiceProtocol,
        flow: AppFlowCoordinator,
        onboardingViewModel: OnboardingViewModel
    ) {
        self.api = api
        self.keychain = keychain
        self.appState = appState
        self.onboardingStore = onboardingStore
        self.healthKit = healthKit
        self.notifications = notifications
        self.flow = flow
        self.onboardingViewModel = onboardingViewModel
    }

    static func live() -> Dependencies {
        let keychain = KeychainService()
        let appState = AppState()
        let api = APIClient(keychain: keychain)
        let onboardingStore = UserDefaultsOnboardingStore()
        let healthKit = HealthKitService()
        let notifications = NotificationPermissionService()
        let flow = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore
        )
        let onboardingViewModel = OnboardingViewModel(
            store: onboardingStore,
            healthKit: healthKit,
            notifications: notifications
        )

        return Dependencies(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore,
            healthKit: healthKit,
            notifications: notifications,
            flow: flow,
            onboardingViewModel: onboardingViewModel
        )
    }

    static func mock() -> Dependencies {
        let keychain = MockKeychainService()
        let appState = AppState()
        let api = MockAPIClient()
        let onboardingStore = InMemoryOnboardingStore()
        let healthKit = MockHealthKitService(outcome: .requested)
        let notifications = MockNotificationPermissionService(outcome: .authorized)
        let flow = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore
        )
        let onboardingViewModel = OnboardingViewModel(
            store: onboardingStore,
            healthKit: healthKit,
            notifications: notifications
        )

        return Dependencies(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore,
            healthKit: healthKit,
            notifications: notifications,
            flow: flow,
            onboardingViewModel: onboardingViewModel
        )
    }
}

// MARK: - Environment Key

private struct DependenciesKey: EnvironmentKey {
    static let defaultValue: Dependencies = .mock()
}

extension EnvironmentValues {
    var dependencies: Dependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}

extension View {
    func withDependencies(_ dependencies: Dependencies) -> some View {
        self.environment(\.dependencies, dependencies)
    }
}
