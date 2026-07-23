import Foundation

protocol AppLockPreferencesProtocol {
    func isEnabled(for userID: UUID) -> Bool
    func setEnabled(_ isEnabled: Bool, for userID: UUID)
    func removePreference(for userID: UUID)
}

final class UserDefaultsAppLockPreferences: AppLockPreferencesProtocol {
    private enum Keys {
        static let prefix = "peppy.app-lock.enabled."
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(for userID: UUID) -> Bool {
        defaults.bool(forKey: key(for: userID))
    }

    func setEnabled(_ isEnabled: Bool, for userID: UUID) {
        defaults.set(isEnabled, forKey: key(for: userID))
    }

    func removePreference(for userID: UUID) {
        defaults.removeObject(forKey: key(for: userID))
    }

    private func key(for userID: UUID) -> String {
        Keys.prefix + userID.uuidString.lowercased()
    }
}
