import Foundation

// MARK: - Protocol

protocol AuthServiceProtocol {
    func login(email: String, password: String) async throws -> (user: User, token: String)
    func register(email: String, password: String) async throws -> (user: User, token: String)
    func logout() async throws
}

// MARK: - Response models

private struct AuthResponse: Decodable {
    struct UserPayload: Decodable {
        let id:          String
        let email:       String
        let displayName: String?
    }
    let user:         UserPayload
    let accessToken:  String
    let refreshToken: String
}

// MARK: - Real implementation

final class RealAuthService: AuthServiceProtocol {
    private let client         = APIClient.shared
    private let sessionManager = SessionManager.shared

    func register(email: String, password: String) async throws -> (user: User, token: String) {
        struct Body: Encodable { let email, password: String }

        let response: AuthResponse = try await client.request(
            APIEndpoint(
                path:         "/auth/register",
                method:       "POST",
                body:         Body(email: email, password: password),
                requiresAuth: false
            )
        )
        return storeAndBuild(response)
    }

    func login(email: String, password: String) async throws -> (user: User, token: String) {
        struct Body: Encodable { let email, password: String }

        let response: AuthResponse = try await client.request(
            APIEndpoint(
                path:         "/auth/login",
                method:       "POST",
                body:         Body(email: email, password: password),
                requiresAuth: false
            )
        )
        return storeAndBuild(response)
    }

    func logout() async throws {
        if let refreshToken = sessionManager.getRefreshToken() {
            struct Body: Encodable { let refreshToken: String }
            // Best-effort — don't throw if it fails
            try? await client.send(
                APIEndpoint(
                    path:         "/auth/logout",
                    method:       "POST",
                    body:         Body(refreshToken: refreshToken),
                    requiresAuth: false
                )
            )
        }
        sessionManager.clearAll()
    }

    private func storeAndBuild(_ r: AuthResponse) -> (user: User, token: String) {
        sessionManager.saveTokens(
            accessToken:  r.accessToken,
            refreshToken: r.refreshToken
        )
        sessionManager.saveUserId(r.user.id)

        let user = User(
            id:                  r.user.id,
            email:               r.user.email,
            onboardingCompleted: false,
            scenarioType:        nil
        )
        return (user, r.accessToken)
    }
}

// MARK: - Mock (kept for simulator / preview builds)

final class MockAuthService: AuthServiceProtocol {
    func login(email: String, password: String) async throws -> (user: User, token: String) {
        try await Task.sleep(nanoseconds: 800_000_000)
        return (User(id: "mock-1", email: email, onboardingCompleted: false, scenarioType: nil), "mock-token")
    }

    func register(email: String, password: String) async throws -> (user: User, token: String) {
        try await Task.sleep(nanoseconds: 800_000_000)
        return (User(id: UUID().uuidString, email: email, onboardingCompleted: false, scenarioType: nil), "mock-token")
    }

    func logout() async throws {}
}
