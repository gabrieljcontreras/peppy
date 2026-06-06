import Foundation
import Security

protocol KeychainServiceProtocol {
    func save(_ value: String, for key: String) throws
    func get(_ key: String) -> String?
    func delete(_ key: String)
    func clear()
}

final class KeychainService: KeychainServiceProtocol {
    private let service: String

    init(service: String = "com.peppy.app") {
        self.service = service
    }

    func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        delete(key)

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

    func get(_ key: String) -> String? {
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

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case encodingFailed
    case saveFailed(OSStatus)
}

// MARK: - Mock for Testing

final class MockKeychainService: KeychainServiceProtocol {
    private var storage: [String: String] = [:]

    func save(_ value: String, for key: String) throws {
        storage[key] = value
    }

    func get(_ key: String) -> String? {
        storage[key]
    }

    func delete(_ key: String) {
        storage.removeValue(forKey: key)
    }

    func clear() {
        storage.removeAll()
    }
}
