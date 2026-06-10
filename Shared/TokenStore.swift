import Foundation
import Security

/// Speichert das Kilocode-API-Token im Keychain, geteilt zwischen App und Widget
/// über die Keychain Access Group.
enum TokenStore {
    private static let service = "com.janjezek.kilocodecredits"
    private static let account = "kilocode-api-token"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: AppConstants.keychainAccessGroup,
        ]
    }

    static func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty
        else { return nil }
        return token
    }

    static func save(_ token: String) throws {
        let data = Data(token.utf8)
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw TokenStoreError.keychain(updateStatus)
            }
        } else if status != errSecSuccess {
            throw TokenStoreError.keychain(status)
        }
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

enum TokenStoreError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            return String(format: L10n.current.keychainError, status)
        }
    }
}
