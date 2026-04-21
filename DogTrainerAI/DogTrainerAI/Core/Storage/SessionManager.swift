import Foundation

final class SessionManager {
    static let shared = SessionManager()

    private enum Keys {
        static let accessToken  = "auth_token"
        static let refreshToken = "auth_refresh_token"
        static let userId       = "user_id"
    }

    // MARK: - Access token (short-lived, 15 min)

    func saveAccessToken(_ token: String) {
        KeychainManager.shared.save(token, for: Keys.accessToken)
    }

    func getAccessToken() -> String? {
        KeychainManager.shared.load(for: Keys.accessToken)
    }

    // MARK: - Refresh token (long-lived, 30 days)

    func saveRefreshToken(_ token: String) {
        KeychainManager.shared.save(token, for: Keys.refreshToken)
    }

    func getRefreshToken() -> String? {
        KeychainManager.shared.load(for: Keys.refreshToken)
    }

    // MARK: - User ID

    func saveUserId(_ id: String) {
        KeychainManager.shared.save(id, for: Keys.userId)
    }

    func getUserId() -> String? {
        KeychainManager.shared.load(for: Keys.userId)
    }

    // MARK: - Helpers

    var isAuthenticated: Bool {
        guard let token = getAccessToken() else { return false }
        return !token.isEmpty
    }

    func saveTokens(accessToken: String, refreshToken: String) {
        saveAccessToken(accessToken)
        saveRefreshToken(refreshToken)
    }

    func clearAll() {
        KeychainManager.shared.delete(for: Keys.accessToken)
        KeychainManager.shared.delete(for: Keys.refreshToken)
        KeychainManager.shared.delete(for: Keys.userId)
    }

    // Legacy alias so existing call sites don't break
    func saveToken(_ token: String)  { saveAccessToken(token) }
    func getToken() -> String?       { getAccessToken() }
    func clearToken()                { clearAll() }
}
