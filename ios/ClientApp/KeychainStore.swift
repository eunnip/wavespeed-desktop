import Foundation
import Security

enum KeychainStore {
    private static let service = "com.altarisgroup.photogstudio.session"
    private static let accessTokenAccount = "access_token"
    private static let refreshTokenAccount = "refresh_token"
    private static let sessionBlobAccount = "session_blob"

    static func loadAccessToken() -> String {
        loadValue(account: accessTokenAccount)
    }

    static func loadRefreshToken() -> String {
        loadValue(account: refreshTokenAccount)
    }

    static func saveTokens(accessToken: String, refreshToken: String) {
        saveValue(accessToken, account: accessTokenAccount)
        if refreshToken.isEmpty {
            clearValue(account: refreshTokenAccount)
        } else {
            saveValue(refreshToken, account: refreshTokenAccount)
        }
    }

    static func loadSessionTokens() -> SessionTokens? {
        let rawValue = loadValue(account: sessionBlobAccount)
        guard !rawValue.isEmpty, let data = rawValue.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(SessionTokens.self, from: data)
    }

    static func saveSessionTokens(_ sessionTokens: SessionTokens) {
        guard let data = try? JSONEncoder().encode(sessionTokens),
              let value = String(data: data, encoding: .utf8)
        else {
            return
        }
        saveValue(value, account: sessionBlobAccount)
        saveTokens(
            accessToken: sessionTokens.accessToken,
            refreshToken: sessionTokens.refreshToken ?? ""
        )
    }

    static func clearTokens() {
        clearValue(account: accessTokenAccount)
        clearValue(account: refreshTokenAccount)
        clearValue(account: sessionBlobAccount)
    }

    private static func loadValue(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func saveValue(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func clearValue(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
