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
    let protocolStore: ProtocolStore
    let protocolNavigation: ProtocolNavigationCoordinator
    let insightsStore: InsightsStore

    init(
        api: APIClientProtocol,
        keychain: KeychainServiceProtocol,
        appState: AppState,
        onboardingStore: OnboardingStoreProtocol,
        healthKit: HealthKitServiceProtocol,
        notifications: NotificationPermissionServiceProtocol,
        flow: AppFlowCoordinator,
        onboardingViewModel: OnboardingViewModel,
        protocolStore: ProtocolStore,
        protocolNavigation: ProtocolNavigationCoordinator,
        insightsStore: InsightsStore
    ) {
        self.api = api
        self.keychain = keychain
        self.appState = appState
        self.onboardingStore = onboardingStore
        self.healthKit = healthKit
        self.notifications = notifications
        self.flow = flow
        self.onboardingViewModel = onboardingViewModel
        self.protocolStore = protocolStore
        self.protocolNavigation = protocolNavigation
        self.insightsStore = insightsStore
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
        let protocolStore = ProtocolStore(api: api)
        let insightsStore = InsightsStore(api: api)

        return Dependencies(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore,
            healthKit: healthKit,
            notifications: notifications,
            flow: flow,
            onboardingViewModel: onboardingViewModel,
            protocolStore: protocolStore,
            protocolNavigation: ProtocolNavigationCoordinator(),
            insightsStore: insightsStore
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
        let protocolStore = ProtocolStore(api: api)
        let insightsStore = InsightsStore(api: api)

        return Dependencies(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore,
            healthKit: healthKit,
            notifications: notifications,
            flow: flow,
            onboardingViewModel: onboardingViewModel,
            protocolStore: protocolStore,
            protocolNavigation: ProtocolNavigationCoordinator(),
            insightsStore: insightsStore
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
