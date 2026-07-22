import Foundation
import Security

struct StoredCredentials: Codable {
    let refreshToken: String
    let energySiteId: Int
}

/// Persists the refresh token + resolved energy site id in the macOS
/// Keychain rather than a plain file, matching what safeStorage did on the
/// Electron side — the token never leaves this machine.
final class CredentialStore {
    private let service = "ai.peaklab.wattson"
    private let account = "tesla-credentials"

    func save(_ credentials: StoredCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        SecItemDelete(baseQuery() as CFDictionary)
        var query = baseQuery()
        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    func load() -> StoredCredentials? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredCredentials.self, from: data)
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
