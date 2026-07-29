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
    let localNotificationScheduler: LocalNotificationScheduling
    let remoteNotificationRegistrar: RemoteNotificationRegistering
    let pushRegistrationCoordinator: PushRegistrationCoordinator
    let notificationReconciliation: NotificationReconciliationCoordinator
    let appLock: AppLockCoordinator
    let exportFileService: ExportFileServicing
    let subscriptionService: SubscriptionServicing
    let entitlements: EntitlementStore

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
        weightUnitPreferences: WeightUnitPreferences,
        localNotificationScheduler: LocalNotificationScheduling,
        remoteNotificationRegistrar: RemoteNotificationRegistering,
        pushRegistrationCoordinator: PushRegistrationCoordinator,
        notificationReconciliation: NotificationReconciliationCoordinator,
        appLock: AppLockCoordinator,
        exportFileService: ExportFileServicing,
        subscriptionService: SubscriptionServicing,
        entitlements: EntitlementStore
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
        self.localNotificationScheduler = localNotificationScheduler
        self.remoteNotificationRegistrar = remoteNotificationRegistrar
        self.pushRegistrationCoordinator = pushRegistrationCoordinator
        self.notificationReconciliation = notificationReconciliation
        self.appLock = appLock
        self.exportFileService = exportFileService
        self.subscriptionService = subscriptionService
        self.entitlements = entitlements
    }

    static func live() -> Dependencies {
        let keychain = KeychainService()
        let appState = AppState()
        let api = APIClient(keychain: keychain)
        let exportFileService = ExportFileService()
        try? exportFileService.removeStaleFiles()
        let onboardingStore = UserDefaultsOnboardingStore()
        let healthKit = HealthKitService()
        let notifications = NotificationPermissionService()
        let protocolNavigation = ProtocolNavigationCoordinator()
        let checkinStore = CheckinStore(api: api)
        let settingsStore = SettingsStore(api: api)
        let protocolStore = ProtocolStore(api: api)
        let insightsStore = InsightsStore(api: api)
        let localNotificationScheduler = LocalNotificationScheduler()
        let remoteNotificationRegistrar = ApplicationRemoteNotificationRegistrar()
        let pushRegistrationCoordinator = PushRegistrationCoordinator(
            api: api,
            isSignedIn: { appState.isAuthenticated }
        )
        let notificationReconciliation = NotificationReconciliationCoordinator(
            settingsStore: settingsStore,
            protocolStore: protocolStore,
            scheduler: localNotificationScheduler,
            pushRegistration: pushRegistrationCoordinator,
            permissionService: notifications,
            remoteNotificationRegistrar: remoteNotificationRegistrar
        )
        let weightUnitPreferences = WeightUnitPreferences {
            if let userID = appState.currentUser?.id,
               let draft = onboardingStore.loadDraft(for: userID) {
                return draft.preferredWeightUnit
            }
            return onboardingStore.loadAnonymousDraft()?.preferredWeightUnit
        }
        weak var flowReference: AppFlowCoordinator?
        let appLock = AppLockCoordinator(
            authenticator: LocalAuthenticationAppLockService(),
            preferences: UserDefaultsAppLockPreferences(),
            logout: {
                Task { await flowReference?.logoutAndWait() }
            }
        )
        let subscriptionService = StoreKitSubscriptionService()
        let entitlements = EntitlementStore(service: subscriptionService, api: api)
        let flow = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore,
            prepareSessionData: { [weak settingsStore, weak weightUnitPreferences] user in
                appLock.prepareForAuthenticatedSession(userID: user.id)
                settingsStore?.beginSession(user: user)
                weightUnitPreferences?.activate(userID: user.id, serverUnit: nil)
                Task { await entitlements.refresh() }
            },
            resetSessionData: { [
                weak checkinStore,
                weak insightsStore,
                weak protocolNavigation,
                weak protocolStore,
                weak settingsStore,
                weak weightUnitPreferences,
                weak appLock
            ] in
                checkinStore?.resetSession()
                insightsStore?.resetSession()
                protocolNavigation?.resetCheckinNavigation()
                protocolStore?.resetSession()
                settingsStore?.resetSession()
                weightUnitPreferences?.resetSession()
                appLock?.resetSession()
                entitlements.resetSession()
                try? exportFileService.removeStaleFiles()
            },
            cleanupAuthenticatedSessionData: { [
                weak notificationReconciliation
            ] accessToken in
                await notificationReconciliation?.resetSession(
                    authenticatedBy: accessToken
                )
            }
        )
        flowReference = flow
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
            onboardingViewModel: onboardingViewModel,
            protocolStore: protocolStore,
            protocolNavigation: protocolNavigation,
            insightsStore: insightsStore,
            checkinStore: checkinStore,
            settingsStore: settingsStore,
            weightUnitPreferences: weightUnitPreferences,
            localNotificationScheduler: localNotificationScheduler,
            remoteNotificationRegistrar: remoteNotificationRegistrar,
            pushRegistrationCoordinator: pushRegistrationCoordinator,
            notificationReconciliation: notificationReconciliation,
            appLock: appLock,
            exportFileService: exportFileService,
            subscriptionService: subscriptionService,
            entitlements: entitlements
        )
    }

    static func mock() -> Dependencies {
        let keychain = MockKeychainService()
        let appState = AppState()
        let api = MockAPIClient()
        let exportFileService = ExportFileService(
            rootDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "peppy-preview-exports",
                    isDirectory: true
                )
        )
        try? exportFileService.removeStaleFiles()
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
            heightCm: 177.8,
            preferredHeightUnit: "ft_in",
            weightKg: 84.55,
            preferredWeightUnit: "lb",
            baselineDate: APIDateOnly.date(from: "2025-05-01"),
            primaryGoal: "track_protocols",
            secondaryGoal: "build_habits",
            focusArea: "understand_body"
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
        let weightUnitPreferences = WeightUnitPreferences {
            if let userID = appState.currentUser?.id,
               let draft = onboardingStore.loadDraft(for: userID) {
                return draft.preferredWeightUnit
            }
            return onboardingStore.loadAnonymousDraft()?.preferredWeightUnit
        }
        let settingsStore = SettingsStore(
            api: api,
            initialUser: previewUser,
            cachedProfile: previewProfile,
            cachedNotificationPreferences: previewPreferences
        )
        let protocolStore = ProtocolStore(api: api)
        let insightsStore = InsightsStore(api: api)
        let localNotificationScheduler = LocalNotificationScheduler()
        let remoteNotificationRegistrar = ApplicationRemoteNotificationRegistrar()
        let pushRegistrationCoordinator = PushRegistrationCoordinator(
            api: api,
            isSignedIn: { appState.isAuthenticated }
        )
        let notificationReconciliation = NotificationReconciliationCoordinator(
            settingsStore: settingsStore,
            protocolStore: protocolStore,
            scheduler: localNotificationScheduler,
            pushRegistration: pushRegistrationCoordinator,
            permissionService: notifications,
            remoteNotificationRegistrar: remoteNotificationRegistrar
        )
        weak var flowReference: AppFlowCoordinator?
        let appLock = AppLockCoordinator(
            authenticator: LocalAuthenticationAppLockService(),
            preferences: UserDefaultsAppLockPreferences(),
            logout: {
                Task { await flowReference?.logoutAndWait() }
            }
        )
        let subscriptionService = MockSubscriptionService()
        let entitlements = EntitlementStore(service: subscriptionService, api: api)
        let flow = AppFlowCoordinator(
            api: api,
            keychain: keychain,
            appState: appState,
            onboardingStore: onboardingStore,
            prepareSessionData: { [weak settingsStore, weak weightUnitPreferences] user in
                appLock.prepareForAuthenticatedSession(userID: user.id)
                settingsStore?.beginSession(user: user)
                weightUnitPreferences?.activate(userID: user.id, serverUnit: nil)
                Task { await entitlements.refresh() }
            },
            resetSessionData: { [
                weak checkinStore,
                weak insightsStore,
                weak protocolNavigation,
                weak protocolStore,
                weak settingsStore,
                weak weightUnitPreferences,
                weak appLock
            ] in
                checkinStore?.resetSession()
                insightsStore?.resetSession()
                protocolNavigation?.resetCheckinNavigation()
                protocolStore?.resetSession()
                settingsStore?.resetSession()
                weightUnitPreferences?.resetSession()
                appLock?.resetSession()
                entitlements.resetSession()
                try? exportFileService.removeStaleFiles()
            },
            cleanupAuthenticatedSessionData: { [
                weak notificationReconciliation
            ] accessToken in
                await notificationReconciliation?.resetSession(
                    authenticatedBy: accessToken
                )
            }
        )
        flowReference = flow
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
            onboardingViewModel: onboardingViewModel,
            protocolStore: protocolStore,
            protocolNavigation: protocolNavigation,
            insightsStore: insightsStore,
            checkinStore: checkinStore,
            settingsStore: settingsStore,
            weightUnitPreferences: weightUnitPreferences,
            localNotificationScheduler: localNotificationScheduler,
            remoteNotificationRegistrar: remoteNotificationRegistrar,
            pushRegistrationCoordinator: pushRegistrationCoordinator,
            notificationReconciliation: notificationReconciliation,
            appLock: appLock,
            exportFileService: exportFileService,
            subscriptionService: subscriptionService,
            entitlements: entitlements
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
