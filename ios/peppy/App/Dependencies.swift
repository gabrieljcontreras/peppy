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
    let settingsStore: SettingsStore
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
        settingsStore: SettingsStore,
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
        self.settingsStore = settingsStore
        self.weightUnitPreferences = weightUnitPreferences
    }

    static func live() -> Dependencies {
        let keychain = KeychainService()
        let appState = AppState()
        let api = APIClient(keychain: keychain)
        let onboardingStore = UserDefaultsOnboardingStore()
        let healthKit = HealthKitService()
        let notifications = NotificationPermissionService()
        let protocolNavigation = ProtocolNavigationCoordinator()
        let checkinStore = CheckinStore(api: api)
        let settingsStore = SettingsStore(api: api)
        let flow = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore,
            prepareSessionData: { [weak settingsStore] user in
                settingsStore?.beginSession(user: user)
            },
            resetSessionData: { [
                weak checkinStore,
                weak protocolNavigation,
                weak settingsStore
            ] in
                checkinStore?.resetSession()
                protocolNavigation?.resetCheckinNavigation()
                settingsStore?.resetSession()
            }
        )
        let onboardingViewModel = OnboardingViewModel(
            store: onboardingStore,
            healthKit: healthKit,
            notifications: notifications
        )
        let protocolStore = ProtocolStore(api: api)
        let insightsStore = InsightsStore(api: api)
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
            protocolNavigation: protocolNavigation,
            insightsStore: insightsStore,
            checkinStore: checkinStore,
            settingsStore: settingsStore,
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
        let protocolNavigation = ProtocolNavigationCoordinator()
        let checkinStore = CheckinStore(api: api)
        let previewUser = User(
            id: UUID(uuidString: "B95BB392-4761-496D-9C0E-FF80B358C7C7")!,
            email: "alex.morgan@example.com",
            displayName: "Alex Morgan",
            isVerified: true
        )
        let previewProfile = AccountProfile(
            id: previewUser.id,
            schemaVersion: 1,
            heightCm: 180,
            preferredHeightUnit: "cm",
            weightKg: 82,
            preferredWeightUnit: "kg",
            baselineDate: APIDateOnly.date(from: "2026-07-20"),
            primaryGoal: "track_protocols",
            secondaryGoal: nil,
            focusArea: nil
        )
        let previewPreferences = NotificationPreferences(
            id: UUID(uuidString: "7BCE24BB-54D5-4EC4-A157-C46B05D3043A")!,
            insightsEnabled: true,
            alertSeverityOnly: false,
            doseRemindersEnabled: false,
            dailyCheckinRemindersEnabled: false,
            dailyCheckinTime: nil,
            detailedPreviewsEnabled: false,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            doseReminders: []
        )
        api.setMockResponse(previewProfile, for: .getProfile)
        api.setMockResponse(previewPreferences, for: .getNotificationPreferences)
        let settingsStore = SettingsStore(
            api: api,
            initialUser: previewUser,
            cachedProfile: previewProfile,
            cachedNotificationPreferences: previewPreferences
        )
        let flow = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore,
            prepareSessionData: { [weak settingsStore] user in
                settingsStore?.beginSession(user: user)
            },
            resetSessionData: { [
                weak checkinStore,
                weak protocolNavigation,
                weak settingsStore
            ] in
                checkinStore?.resetSession()
                protocolNavigation?.resetCheckinNavigation()
                settingsStore?.resetSession()
            }
        )
        let onboardingViewModel = OnboardingViewModel(
            store: onboardingStore,
            healthKit: healthKit,
            notifications: notifications
        )
        let protocolStore = ProtocolStore(api: api)
        let insightsStore = InsightsStore(api: api)
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
            protocolNavigation: protocolNavigation,
            insightsStore: insightsStore,
            checkinStore: checkinStore,
            settingsStore: settingsStore,
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
