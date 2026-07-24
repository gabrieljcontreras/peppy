import Foundation
import Observation

struct NotificationSettingsDraft: Equatable {
    var insightsEnabled: Bool
    var alertSeverityOnly: Bool
    var doseRemindersEnabled: Bool
    var dailyCheckinRemindersEnabled: Bool
    var dailyCheckinTime: String?
    var detailedPreviewsEnabled: Bool
    var quietHoursStart: String?
    var quietHoursEnd: String?
    var doseReminders: [DoseReminderPreference]

    init(preferences: NotificationPreferences) {
        insightsEnabled = preferences.insightsEnabled
        alertSeverityOnly = preferences.alertSeverityOnly
        doseRemindersEnabled = preferences.doseRemindersEnabled
        dailyCheckinRemindersEnabled = preferences.dailyCheckinRemindersEnabled
        dailyCheckinTime = preferences.dailyCheckinTime
        detailedPreviewsEnabled = preferences.detailedPreviewsEnabled
        quietHoursStart = preferences.quietHoursStart
        quietHoursEnd = preferences.quietHoursEnd
        doseReminders = preferences.doseReminders
    }

    var request: UpdateNotificationPreferencesRequest {
        UpdateNotificationPreferencesRequest(
            insightsEnabled: insightsEnabled,
            alertSeverityOnly: insightsEnabled && alertSeverityOnly,
            doseRemindersEnabled: doseRemindersEnabled,
            dailyCheckinRemindersEnabled: dailyCheckinRemindersEnabled,
            dailyCheckinTime: dailyCheckinTime,
            detailedPreviewsEnabled: detailedPreviewsEnabled,
            quietHoursStart: quietHoursStart,
            quietHoursEnd: quietHoursEnd,
            doseReminders: doseReminders
        )
    }
}

enum NotificationReminderSetup: Identifiable {
    case dose
    case dailyCheckin
    case detailedPreviews

    var id: Int {
        switch self {
        case .dose: 0
        case .dailyCheckin: 1
        case .detailedPreviews: 2
        }
    }
}

@MainActor
@Observable
final class NotificationSettingsViewModel {
    private let store: SettingsStore
    private let protocolStore: ProtocolStore
    private let permissionService: NotificationPermissionServiceProtocol
    private let scheduler: LocalNotificationScheduling
    private let registerForRemoteNotifications: () -> Void

    private(set) var confirmedDraft: NotificationSettingsDraft
    var draft: NotificationSettingsDraft
    var activeSetup: NotificationReminderSetup?
    private(set) var isLoading = true
    var isSaving = false
    var errorMessage: String?
    var repairMessage: String?
    var showsOpenSystemSettingsAction = false

    init(
        store: SettingsStore,
        protocolStore: ProtocolStore,
        permissionService: NotificationPermissionServiceProtocol,
        scheduler: LocalNotificationScheduling,
        registerForRemoteNotifications: @escaping () -> Void = {}
    ) {
        self.store = store
        self.protocolStore = protocolStore
        self.permissionService = permissionService
        self.scheduler = scheduler
        self.registerForRemoteNotifications = registerForRemoteNotifications

        let preferences = store.notificationPreferences ?? Self.defaultPreferences
        let initialDraft = NotificationSettingsDraft(preferences: preferences)
        confirmedDraft = initialDraft
        draft = initialDraft
    }

    var hasUnsavedChanges: Bool {
        draft != confirmedDraft
    }

    var canSave: Bool {
        hasUnsavedChanges && !isLoading && !isSaving
    }

    var activeProtocol: ProtocolModel? {
        protocolStore.protocols.first(where: \.isActive)
            ?? protocolStore.selectedProtocol.flatMap { $0.isActive ? $0 : nil }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        if store.notificationPreferences == nil {
            await store.refresh()
        }
        await protocolStore.loadProtocols()

        if !hasUnsavedChanges,
           let preferences = store.notificationPreferences {
            let loadedDraft = NotificationSettingsDraft(preferences: preferences)
            confirmedDraft = loadedDraft
            draft = loadedDraft
        }
        await refreshPermissionStatus()
    }

    func setDoseRemindersEnabled(_ enabled: Bool) {
        guard !isLoading else { return }
        if enabled {
            activeSetup = .dose
        } else {
            draft.doseRemindersEnabled = false
        }
    }

    func setDailyCheckinRemindersEnabled(_ enabled: Bool) {
        guard !isLoading else { return }
        if enabled {
            activeSetup = .dailyCheckin
        } else {
            draft.dailyCheckinRemindersEnabled = false
        }
    }

    func setInsightsEnabled(_ enabled: Bool) {
        guard !isLoading else { return }
        draft.insightsEnabled = enabled
        if !enabled {
            draft.alertSeverityOnly = false
        }
    }

    func setAlertSeverityOnly(_ enabled: Bool) {
        guard !isLoading else { return }
        draft.alertSeverityOnly = draft.insightsEnabled && enabled
    }

    func setQuietHours(start: String?, end: String?) {
        guard !isLoading else { return }
        draft.quietHoursStart = start
        draft.quietHoursEnd = end
    }

    func confirmDoseSetup(
        reminders: [DoseReminderPreference]
    ) async {
        guard !isLoading, reminders.contains(where: \.enabled) else { return }
        draft.doseReminders = reminders
        draft.doseRemindersEnabled = true
        activeSetup = nil
        await requestPermissionAfterValidSetup()
    }

    func confirmDailyCheckinSetup(localTime: String) async {
        guard !isLoading,
              LocalNotificationScheduler.timeComponents(from: localTime) != nil else {
            return
        }
        draft.dailyCheckinTime = localTime
        draft.dailyCheckinRemindersEnabled = true
        activeSetup = nil
        await requestPermissionAfterValidSetup()
    }

    func confirmDetailedPreviews(_ enabled: Bool) {
        guard !isLoading else { return }
        draft.detailedPreviewsEnabled = enabled
        activeSetup = nil
    }

    func cancelSetup() {
        activeSetup = nil
    }

    func refreshPermissionStatus() async {
        let status = await permissionService.authorizationStatus()
        showsOpenSystemSettingsAction = status == .denied
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    func save() async -> Bool {
        guard canSave else { return false }

        let enablesInsights = draft.insightsEnabled && !confirmedDraft.insightsEnabled
        isSaving = true
        errorMessage = nil
        repairMessage = nil
        defer { isSaving = false }

        do {
            try await store.updateNotifications(draft.request)
            guard let confirmed = store.notificationPreferences else {
                throw APIError.decodingFailed
            }
            let reconciledDraft = NotificationSettingsDraft(preferences: confirmed)
            confirmedDraft = reconciledDraft
            draft = reconciledDraft

            if enablesInsights {
                await requestPermissionAfterValidSetup(
                    offerDetailedPreviews: false
                )
            }
            let status = await permissionService.authorizationStatus()
            showsOpenSystemSettingsAction = status == .denied
            if status.canDeliverNotifications {
                do {
                    try await scheduler.reconcile(
                        preferences: confirmed,
                        activeProtocol: activeProtocol
                    )
                } catch {
                    repairMessage = "Your preferences were saved, but reminders need repair."
                }
            } else {
                await scheduler.removeSettingsRequests()
            }
            return true
        } catch {
            errorMessage = (error as? APIError)?.userMessage
                ?? "We couldn’t save your notification settings."
            return false
        }
    }

    func repairLocalScheduling() async {
        guard let preferences = store.notificationPreferences else { return }
        let status = await permissionService.authorizationStatus()
        showsOpenSystemSettingsAction = status == .denied
        guard status.canDeliverNotifications else {
            await scheduler.removeSettingsRequests()
            repairMessage = nil
            return
        }
        do {
            try await scheduler.reconcile(
                preferences: preferences,
                activeProtocol: activeProtocol
            )
            repairMessage = nil
        } catch {
            repairMessage = "Reminders still need repair. Please try again."
        }
    }

    private func requestPermissionAfterValidSetup(
        offerDetailedPreviews: Bool = true
    ) async {
        var status = await permissionService.authorizationStatus()
        if status == .notDetermined {
            let outcome = await permissionService.requestAuthorization()
            switch outcome {
            case .authorized, .requested:
                status = .authorized
            case .denied:
                status = .denied
            case .unavailable, .failed:
                status = .unavailable
            case .notDetermined:
                status = .notDetermined
            }
        }

        showsOpenSystemSettingsAction = status == .denied
        if status.canDeliverNotifications {
            registerForRemoteNotifications()
            if offerDetailedPreviews {
                activeSetup = .detailedPreviews
            }
        }
    }

    private static let defaultPreferences = NotificationPreferences(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
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
}
