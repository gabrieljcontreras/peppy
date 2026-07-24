import Foundation
import Observation
import SwiftUI

enum AppLockEnableResult: Equatable {
    case enabled
    case disabled
    case cancelled
    case unavailable(AppLockUnavailabilityReason)
}

@MainActor
@Observable
final class AppLockCoordinator {
    static let timeout: TimeInterval = 300
    static let authenticationReason =
        "Unlock Peppy to access your health information."

    private(set) var isPrivacyCoverVisible = false
    private(set) var requiresUnlock = false
    private(set) var unavailabilityReason: AppLockUnavailabilityReason?

    private let authenticator: AppLockAuthenticating
    private let preferences: AppLockPreferencesProtocol
    private let now: () -> Date
    private let logout: () -> Void

    private var currentUserID: UUID?
    private var backgroundEnteredAt: Date?
    private var isAuthenticating = false
    private var isSceneActive = true

    init(
        authenticator: AppLockAuthenticating,
        preferences: AppLockPreferencesProtocol,
        now: @escaping () -> Date = Date.init,
        logout: @escaping () -> Void
    ) {
        self.authenticator = authenticator
        self.preferences = preferences
        self.now = now
        self.logout = logout
    }

    func isEnabled(for userID: UUID) -> Bool {
        preferences.isEnabled(for: userID)
    }

    func availability() -> AppLockAvailability {
        authenticator.availability()
    }

    /// Called before the authenticated route is presented so health content is
    /// already obscured when an opted-in session becomes visible.
    func prepareForAuthenticatedSession(userID: UUID) {
        currentUserID = userID
        backgroundEnteredAt = nil
        unavailabilityReason = nil

        let isEnabled = preferences.isEnabled(for: userID)
        isPrivacyCoverVisible = isEnabled
        requiresUnlock = isEnabled
    }

    func authenticatedSessionBecameVisible(userID: UUID) async {
        if currentUserID != userID {
            prepareForAuthenticatedSession(userID: userID)
        }

        guard preferences.isEnabled(for: userID) else {
            isPrivacyCoverVisible = false
            requiresUnlock = false
            unavailabilityReason = nil
            return
        }

        if requiresUnlock {
            await attemptUnlock()
        }
    }

    /// Synchronously obscures content before iOS captures an app-switcher
    /// snapshot. The async phase handler performs any follow-up authentication.
    func scenePhaseWillChange(_ phase: ScenePhase) {
        guard let currentUserID,
              preferences.isEnabled(for: currentUserID) else {
            return
        }

        switch phase {
        case .inactive:
            isSceneActive = false
            isPrivacyCoverVisible = true
        case .background:
            isSceneActive = false
            isPrivacyCoverVisible = true
            if backgroundEnteredAt == nil {
                backgroundEnteredAt = now()
            }
        case .active:
            isSceneActive = true
        @unknown default:
            isSceneActive = false
            isPrivacyCoverVisible = true
        }
    }

    func scenePhaseChanged(_ phase: ScenePhase) async {
        guard let currentUserID,
              preferences.isEnabled(for: currentUserID) else {
            return
        }

        scenePhaseWillChange(phase)

        switch phase {
        case .inactive:
            return
        case .background:
            return
        case .active:
            guard !isAuthenticating else { return }

            if let backgroundEnteredAt {
                let elapsed = max(0, now().timeIntervalSince(backgroundEnteredAt))
                self.backgroundEnteredAt = nil

                if requiresUnlock || elapsed >= Self.timeout {
                    requiresUnlock = true
                    isPrivacyCoverVisible = true
                    await attemptUnlock()
                } else {
                    requiresUnlock = false
                    isPrivacyCoverVisible = false
                }
            } else if requiresUnlock {
                await attemptUnlock()
            } else {
                isPrivacyCoverVisible = false
            }
        @unknown default:
            return
        }
    }

    func retryUnlock() async {
        guard currentUserID != nil, requiresUnlock else { return }
        await attemptUnlock()
    }

    func setEnabled(
        _ isEnabled: Bool,
        for userID: UUID
    ) async -> AppLockEnableResult {
        guard isEnabled else {
            preferences.setEnabled(false, for: userID)
            if currentUserID == userID {
                isPrivacyCoverVisible = false
                requiresUnlock = false
                unavailabilityReason = nil
                backgroundEnteredAt = nil
            }
            return .disabled
        }

        let availability = authenticator.availability()
        guard case .available = availability else {
            let reason = availability.unavailabilityReason ?? .notAvailable
            unavailabilityReason = reason
            return .unavailable(reason)
        }

        guard await authenticator.authenticate(
            reason: "Confirm Face ID to protect Peppy."
        ) else {
            return .cancelled
        }

        preferences.setEnabled(true, for: userID)
        currentUserID = userID
        backgroundEnteredAt = nil
        unavailabilityReason = nil
        isPrivacyCoverVisible = false
        requiresUnlock = false
        return .enabled
    }

    func usePasswordInstead() {
        isPrivacyCoverVisible = true
        requiresUnlock = true
        logout()
    }

    func resetSession() {
        currentUserID = nil
        backgroundEnteredAt = nil
        unavailabilityReason = nil
        isAuthenticating = false
        isSceneActive = true
        isPrivacyCoverVisible = false
        requiresUnlock = false
    }

    func removePreference(for userID: UUID) {
        preferences.removePreference(for: userID)
        if currentUserID == userID {
            resetSession()
        }
    }

    private func attemptUnlock() async {
        guard !isAuthenticating else { return }

        let availability = authenticator.availability()
        guard case .available = availability else {
            unavailabilityReason =
                availability.unavailabilityReason ?? .notAvailable
            isPrivacyCoverVisible = true
            requiresUnlock = true
            return
        }

        unavailabilityReason = nil
        isAuthenticating = true
        let authenticated = await authenticator.authenticate(
            reason: Self.authenticationReason
        )
        isAuthenticating = false

        if authenticated {
            requiresUnlock = false
            backgroundEnteredAt = nil
            isPrivacyCoverVisible = !isSceneActive
        } else {
            requiresUnlock = true
            isPrivacyCoverVisible = true
        }
    }
}

private extension AppLockAvailability {
    var unavailabilityReason: AppLockUnavailabilityReason? {
        guard case .unavailable(let reason) = self else { return nil }
        return reason
    }
}
