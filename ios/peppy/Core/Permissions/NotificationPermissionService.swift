import UserNotifications

protocol NotificationPermissionServiceProtocol {
    func requestAuthorization() async -> PermissionOutcome
}

final class NotificationPermissionService: NotificationPermissionServiceProtocol {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> PermissionOutcome {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .authorized : .denied
        } catch {
            return .failed
        }
    }
}

struct MockNotificationPermissionService: NotificationPermissionServiceProtocol {
    var outcome: PermissionOutcome

    func requestAuthorization() async -> PermissionOutcome {
        outcome
    }
}
