import UIKit
import UserNotifications

enum NotificationAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unavailable

    var canDeliverNotifications: Bool {
        self == .authorized || self == .provisional || self == .ephemeral
    }
}

@MainActor
protocol NotificationPermissionServiceProtocol {
    func requestAuthorization() async -> PermissionOutcome
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func openSystemSettings()
}

@MainActor
final class NotificationPermissionService: NotificationPermissionServiceProtocol {
    private let center: UNUserNotificationCenter
    private let settingsOpener: @MainActor () -> Void

    init(
        center: UNUserNotificationCenter = .current(),
        settingsOpener: (@MainActor () -> Void)? = nil
    ) {
        self.center = center
        self.settingsOpener = settingsOpener ?? {
            guard let url = URL(
                string: UIApplication.openNotificationSettingsURLString
            ) else {
                return
            }
            UIApplication.shared.open(url)
        }
    }

    func requestAuthorization() async -> PermissionOutcome {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .authorized : .denied
        } catch {
            return .failed
        }
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unavailable
        }
    }

    func openSystemSettings() {
        settingsOpener()
    }
}

@MainActor
final class MockNotificationPermissionService: NotificationPermissionServiceProtocol {
    var outcome: PermissionOutcome
    var status: NotificationAuthorizationStatus
    private(set) var didOpenSystemSettings = false

    init(
        outcome: PermissionOutcome,
        authorizationStatus: NotificationAuthorizationStatus? = nil
    ) {
        self.outcome = outcome
        status = authorizationStatus ?? Self.status(for: outcome)
    }

    func requestAuthorization() async -> PermissionOutcome {
        status = Self.status(for: outcome)
        return outcome
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func openSystemSettings() {
        didOpenSystemSettings = true
    }

    private static func status(
        for outcome: PermissionOutcome
    ) -> NotificationAuthorizationStatus {
        switch outcome {
        case .authorized, .requested:
            return .authorized
        case .denied:
            return .denied
        case .unavailable, .failed:
            return .unavailable
        case .notDetermined:
            return .notDetermined
        }
    }
}
