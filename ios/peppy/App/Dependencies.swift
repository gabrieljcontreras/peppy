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
    let checkinStore: CheckinStore
    let weightUnitPreferences: WeightUnitPreferences

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
        insightsStore: InsightsStore,
        checkinStore: CheckinStore,
        weightUnitPreferences: WeightUnitPreferences
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
        self.checkinStore = checkinStore
        self.weightUnitPreferences = weightUnitPreferences
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
        let checkinStore = CheckinStore(api: api)
        let weightUnitPreferences = WeightUnitPreferences {
            if let userID = appState.currentUser?.id,
               let draft = onboardingStore.loadDraft(for: userID) {
                return draft.preferredWeightUnit
            }
            return onboardingStore.loadAnonymousDraft()?.preferredWeightUnit
        }

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
            insightsStore: insightsStore,
            checkinStore: checkinStore,
            weightUnitPreferences: weightUnitPreferences
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
        let checkinStore = CheckinStore(api: api)
        let weightUnitPreferences = WeightUnitPreferences {
            if let userID = appState.currentUser?.id,
               let draft = onboardingStore.loadDraft(for: userID) {
                return draft.preferredWeightUnit
            }
            return onboardingStore.loadAnonymousDraft()?.preferredWeightUnit
        }

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
            insightsStore: insightsStore,
            checkinStore: checkinStore,
            weightUnitPreferences: weightUnitPreferences
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
