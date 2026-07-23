import Foundation
import UserNotifications

@MainActor
protocol UserNotificationCenterScheduling: AnyObject {
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemUserNotificationCenter: UserNotificationCenterScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
protocol LocalNotificationScheduling: AnyObject {
    func reconcile(
        preferences: NotificationPreferences,
        activeProtocol: ProtocolModel?
    ) async throws
    func removeSettingsRequests() async
}

@MainActor
final class LocalNotificationScheduler: LocalNotificationScheduling {
    static let settingsIdentifierPrefix = "peppy.settings."
    static let checkinIdentifier = "peppy.settings.checkin"
    static let doseRequestLimit = 60

    private let center: UserNotificationCenterScheduling
    private let calendar: Calendar
    private let now: () -> Date
    private var operationTail: Task<Void, Never>?

    init(
        center: UserNotificationCenterScheduling? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center ?? SystemUserNotificationCenter()
        self.calendar = calendar
        self.now = now
    }

    func reconcile(
        preferences: NotificationPreferences,
        activeProtocol: ProtocolModel?
    ) async throws {
        let previous = operationTail
        let operation = Task<Void, Error> { @MainActor in
            await previous?.value
            try await self.performReconcile(
                preferences: preferences,
                activeProtocol: activeProtocol
            )
        }
        operationTail = Task {
            try? await operation.value
        }
        try await operation.value
    }

    private func performReconcile(
        preferences: NotificationPreferences,
        activeProtocol: ProtocolModel?
    ) async throws {
        await performRemoveSettingsRequests()
        if preferences.doseRemindersEnabled,
           let activeProtocol,
           activeProtocol.isActive {
            let requests = doseRequests(
                preferences: preferences,
                activeProtocol: activeProtocol
            )
            for request in requests {
                try await center.add(request)
            }
        }

        if let request = checkinRequest(preferences: preferences) {
            try await center.add(request)
        }
    }

    func removeSettingsRequests() async {
        let previous = operationTail
        let operation = Task { @MainActor in
            await previous?.value
            await self.performRemoveSettingsRequests()
        }
        operationTail = operation
        await operation.value
    }

    private func performRemoveSettingsRequests() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.settingsIdentifierPrefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func doseRequests(
        preferences: NotificationPreferences,
        activeProtocol: ProtocolModel
    ) -> [UNNotificationRequest] {
        let compounds = Dictionary(
            uniqueKeysWithValues: activeProtocol.compounds.map { ($0.id, $0) }
        )
        var scheduled: [(Date, Compound, String)] = []

        for reminder in preferences.doseReminders where reminder.enabled {
            guard let compound = compounds[reminder.compoundID],
                  let localTime = Self.timeComponents(from: reminder.localTime) else {
                continue
            }

            let dates = DoseScheduleCalculator.upcomingDates(
                startingAt: activeProtocol.startDate,
                frequency: compound.frequency,
                localTime: localTime,
                after: now(),
                calendar: calendar,
                limit: Self.doseRequestLimit
            )
            scheduled.append(
                contentsOf: dates.map { ($0, compound, reminder.localTime) }
            )
        }

        return scheduled
            .sorted { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return lhs.0 < rhs.0
                }
                return lhs.1.id.uuidString < rhs.1.id.uuidString
            }
            .prefix(Self.doseRequestLimit)
            .map { date, compound, localTime in
                let content = UNMutableNotificationContent()
                content.sound = .default

                if preferences.detailedPreviewsEnabled {
                    content.title = "Time for your \(compound.name) dose"
                    content.body = "Your \(Self.doseText(compound)) dose is scheduled for \(Self.displayTime(localTime))."
                } else {
                    content.title = "Peppy"
                    content.body = "You have a Peppy reminder"
                }

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: date
                    ),
                    repeats: false
                )
                return UNNotificationRequest(
                    identifier: Self.doseIdentifier(
                        compoundID: compound.id,
                        date: date,
                        calendar: calendar
                    ),
                    content: content,
                    trigger: trigger
                )
            }
    }

    private func checkinRequest(
        preferences: NotificationPreferences
    ) -> UNNotificationRequest? {
        guard preferences.dailyCheckinRemindersEnabled,
              let rawTime = preferences.dailyCheckinTime,
              let time = Self.timeComponents(from: rawTime),
              !Self.isWithinQuietHours(
                time: time,
                start: Self.timeComponents(from: preferences.quietHoursStart),
                end: Self.timeComponents(from: preferences.quietHoursEnd)
              ) else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        if preferences.detailedPreviewsEnabled {
            content.title = "Daily check-in"
            content.body = "Your Peppy check-in is ready."
        } else {
            content.title = "Peppy"
            content.body = "You have a Peppy reminder"
        }

        return UNNotificationRequest(
            identifier: Self.checkinIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: DateComponents(
                    hour: time.hour,
                    minute: time.minute
                ),
                repeats: true
            )
        )
    }

    static func timeComponents(from value: String?) -> DateComponents? {
        guard let value else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return DateComponents(hour: hour, minute: minute)
    }

    private static func isWithinQuietHours(
        time: DateComponents,
        start: DateComponents?,
        end: DateComponents?
    ) -> Bool {
        guard let timeMinutes = minutes(from: time),
              let startMinutes = minutes(from: start),
              let endMinutes = minutes(from: end),
              startMinutes != endMinutes else {
            return false
        }

        if startMinutes < endMinutes {
            return timeMinutes >= startMinutes && timeMinutes < endMinutes
        }
        return timeMinutes >= startMinutes || timeMinutes < endMinutes
    }

    private static func minutes(from components: DateComponents?) -> Int? {
        guard let hour = components?.hour, let minute = components?.minute else {
            return nil
        }
        return hour * 60 + minute
    }

    private static func doseIdentifier(
        compoundID: UUID,
        date: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dateValue = String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        return "peppy.settings.dose.\(compoundID.uuidString.lowercased()).\(dateValue)"
    }

    private static func doseText(_ compound: Compound) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
        let amount = formatter.string(
            from: NSNumber(value: compound.doseMg)
        ) ?? "\(compound.doseMg)"
        return "\(amount) \(compound.doseUnit)"
    }

    private static func displayTime(_ value: String) -> String {
        guard let components = timeComponents(from: value),
              let hour = components.hour,
              let minute = components.minute else {
            return value
        }
        let date = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2000, month: 1, day: 1, hour: hour, minute: minute)
        ) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

@MainActor
final class NotificationReconciliationCoordinator {
    private let settingsStore: SettingsStore
    private let protocolStore: ProtocolStore
    private let scheduler: LocalNotificationScheduling
    private let pushRegistration: PushRegistrationCoordinating
    private let permissionService: NotificationPermissionServiceProtocol?
    private let remoteNotificationRegistrar: RemoteNotificationRegistering?
    private let timeZoneIdentifier: () -> String
    private var operationTail: Task<Void, Never>?

    init(
        settingsStore: SettingsStore,
        protocolStore: ProtocolStore,
        scheduler: LocalNotificationScheduling,
        pushRegistration: PushRegistrationCoordinating,
        permissionService: NotificationPermissionServiceProtocol? = nil,
        remoteNotificationRegistrar: RemoteNotificationRegistering? = nil,
        timeZoneIdentifier: @escaping () -> String = {
            TimeZone.current.identifier
        }
    ) {
        self.settingsStore = settingsStore
        self.protocolStore = protocolStore
        self.scheduler = scheduler
        self.pushRegistration = pushRegistration
        self.permissionService = permissionService
        self.remoteNotificationRegistrar = remoteNotificationRegistrar
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    func startSession() async {
        await enqueue {
            await self.settingsStore.refresh()
            await self.protocolStore.loadProtocols(force: true)
            await self.performReconcile()
        }
    }

    func reconcile() async {
        await enqueue {
            await self.performReconcile()
        }
    }

    func resetSession() async {
        await enqueue {
            await self.scheduler.removeSettingsRequests()
            await self.pushRegistration.unregister()
        }
    }

    private func performReconcile() async {
        let status = await permissionService?.authorizationStatus()

        if status?.canDeliverNotifications ?? true {
            if let preferences = settingsStore.notificationPreferences {
                try? await scheduler.reconcile(
                    preferences: preferences,
                    activeProtocol: activeProtocol
                )
            }
        } else {
            await scheduler.removeSettingsRequests()
        }

        try? await settingsStore.updateTimezoneIfNeeded(timeZoneIdentifier())

        if status?.canDeliverNotifications == true {
            remoteNotificationRegistrar?.registerForRemoteNotifications()
        }

        await pushRegistration.registerPendingTokenIfPossible()
    }

    private func enqueue(
        _ operation: @escaping @MainActor () async -> Void
    ) async {
        let previous = operationTail
        let next = Task { @MainActor in
            await previous?.value
            await operation()
        }
        operationTail = next
        await next.value
    }

    private var activeProtocol: ProtocolModel? {
        protocolStore.protocols.first(where: \.isActive)
            ?? protocolStore.selectedProtocol.flatMap {
                $0.isActive ? $0 : nil
            }
    }
}
