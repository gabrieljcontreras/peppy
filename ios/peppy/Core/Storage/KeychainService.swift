import Foundation
import Security

protocol KeychainServiceProtocol {
    var authenticationRevision: UInt64 { get }
    func save(_ value: String, for key: String) throws
    func get(_ key: String) -> String?
    func delete(_ key: String)
    func clear()
    func saveAuthentication(
        accessToken: String,
        refreshToken: String,
        ifRevisionMatches expectedRevision: UInt64
    ) throws -> Bool
    func invalidateAuthenticatedSession()
    func invalidateAuthenticatedSession(
        ifRevisionMatches expectedRevision: UInt64
    ) -> Bool
}

final class KeychainService: KeychainServiceProtocol {
    private let service: String
    private let lock = NSLock()
    private var revision: UInt64 = 0

    init(service: String = "com.peppy.app") {
        self.service = service
    }

    var authenticationRevision: UInt64 {
        lock.withCriticalRegion { revision }
    }

    func save(_ value: String, for key: String) throws {
        try lock.withCriticalRegion {
            try saveUnlocked(value, for: key)
            if Self.isAuthenticationKey(key) {
                revision &+= 1
            }
        }
    }

    func get(_ key: String) -> String? {
        lock.withCriticalRegion {
            getUnlocked(key)
        }
    }

    func delete(_ key: String) {
        lock.withCriticalRegion {
            deleteUnlocked(key)
            if Self.isAuthenticationKey(key) {
                revision &+= 1
            }
        }
    }

    func clear() {
        lock.withCriticalRegion {
            clearUnlocked()
            revision &+= 1
        }
    }

    func saveAuthentication(
        accessToken: String,
        refreshToken: String,
        ifRevisionMatches expectedRevision: UInt64
    ) throws -> Bool {
        try lock.withCriticalRegion {
            guard revision == expectedRevision else { return false }

            do {
                try saveUnlocked(
                    accessToken,
                    for: KeychainKeys.accessToken
                )
                try saveUnlocked(
                    refreshToken,
                    for: KeychainKeys.refreshToken
                )
                return true
            } catch {
                deleteUnlocked(KeychainKeys.accessToken)
                deleteUnlocked(KeychainKeys.refreshToken)
                revision &+= 1
                throw error
            }
        }
    }

    func invalidateAuthenticatedSession() {
        lock.withCriticalRegion {
            revision &+= 1
            deleteUnlocked(KeychainKeys.accessToken)
            deleteUnlocked(KeychainKeys.refreshToken)
        }
    }

    func invalidateAuthenticatedSession(
        ifRevisionMatches expectedRevision: UInt64
    ) -> Bool {
        lock.withCriticalRegion {
            guard revision == expectedRevision else { return false }
            revision &+= 1
            deleteUnlocked(KeychainKeys.accessToken)
            deleteUnlocked(KeychainKeys.refreshToken)
            return true
        }
    }

    private func saveUnlocked(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        deleteUnlocked(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func getUnlocked(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteUnlocked(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    private func clearUnlocked() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }

    private static func isAuthenticationKey(_ key: String) -> Bool {
        key == KeychainKeys.accessToken || key == KeychainKeys.refreshToken
    }
}

enum KeychainError: Error {
    case encodingFailed
    case saveFailed(OSStatus)
}

// MARK: - Mock for Testing

final class MockKeychainService: KeychainServiceProtocol {
    private let lock = NSLock()
    private var storage: [String: String] = [:]
    private var revision: UInt64 = 0

    var authenticationRevision: UInt64 {
        lock.withCriticalRegion { revision }
    }

    func save(_ value: String, for key: String) throws {
        lock.withCriticalRegion {
            storage[key] = value
            if Self.isAuthenticationKey(key) {
                revision &+= 1
            }
        }
    }

    func get(_ key: String) -> String? {
        lock.withCriticalRegion { storage[key] }
    }

    func delete(_ key: String) {
        lock.withCriticalRegion {
            storage.removeValue(forKey: key)
            if Self.isAuthenticationKey(key) {
                revision &+= 1
            }
        }
    }

    func clear() {
        lock.withCriticalRegion {
            storage.removeAll()
            revision &+= 1
        }
    }

    func saveAuthentication(
        accessToken: String,
        refreshToken: String,
        ifRevisionMatches expectedRevision: UInt64
    ) throws -> Bool {
        lock.withCriticalRegion {
            guard revision == expectedRevision else { return false }
            storage[KeychainKeys.accessToken] = accessToken
            storage[KeychainKeys.refreshToken] = refreshToken
            return true
        }
    }

    func invalidateAuthenticatedSession() {
        lock.withCriticalRegion {
            revision &+= 1
            storage.removeValue(forKey: KeychainKeys.accessToken)
            storage.removeValue(forKey: KeychainKeys.refreshToken)
        }
    }

    func invalidateAuthenticatedSession(
        ifRevisionMatches expectedRevision: UInt64
    ) -> Bool {
        lock.withCriticalRegion {
            guard revision == expectedRevision else { return false }
            revision &+= 1
            storage.removeValue(forKey: KeychainKeys.accessToken)
            storage.removeValue(forKey: KeychainKeys.refreshToken)
            return true
        }
    }

    private static func isAuthenticationKey(_ key: String) -> Bool {
        key == KeychainKeys.accessToken || key == KeychainKeys.refreshToken
    }
}

private extension NSLock {
    func withCriticalRegion<T>(
        _ operation: () throws -> T
    ) rethrows -> T {
        lock()
        defer { unlock() }
        return try operation()
    }
}
