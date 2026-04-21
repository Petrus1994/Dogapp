import Foundation

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case noToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Invalid URL"
        case .invalidResponse:         return "Invalid server response"
        case .httpError(let c, let m): return m ?? "Server error (\(c))"
        case .decodingError:           return "Failed to parse response"
        case .networkError(let e):     return e.localizedDescription
        case .unauthorized:            return "Session expired. Please log in again."
        case .noToken:                 return "Not authenticated"
        }
    }
}

// MARK: - Endpoint

struct APIEndpoint {
    let path:   String
    let method: String
    let body:   (any Encodable)?
    let requiresAuth: Bool

    init(path: String, method: String = "GET", body: (any Encodable)? = nil, requiresAuth: Bool = true) {
        self.path         = path
        self.method       = method
        self.body         = body
        self.requiresAuth = requiresAuth
    }
}

// MARK: - Server error shape

private struct ServerError: Decodable {
    let message: String?
    let error:   String?
}

// MARK: - Client

final class APIClient {
    static let shared = APIClient()

    private let session        = URLSession.shared
    private let sessionManager = SessionManager.shared
    private let decoder        = JSONDecoder()
    private let encoder        = JSONEncoder()

    var baseURL: String { APIKeyProvider.backendBaseURL + "/v1" }

    private init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Primary request method

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await rawRequest(endpoint, retryOnUnauthorized: true)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Fire-and-forget variant — does not parse a response body.
    func send(_ endpoint: APIEndpoint) async throws {
        _ = try await rawRequest(endpoint, retryOnUnauthorized: true)
    }

    // MARK: - Internal

    private func rawRequest(_ endpoint: APIEndpoint, retryOnUnauthorized: Bool) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method(for: endpoint)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if endpoint.requiresAuth {
            guard let token = sessionManager.getAccessToken() else { throw APIError.noToken }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await perform(req)

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if http.statusCode == 401 && retryOnUnauthorized {
            // Try refreshing the token once
            if let newToken = try? await refreshAccessToken() {
                sessionManager.saveAccessToken(newToken)
                return try await rawRequest(endpoint, retryOnUnauthorized: false)
            } else {
                throw APIError.unauthorized
            }
        }

        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? decoder.decode(ServerError.self, from: data))?.message
            throw APIError.httpError(http.statusCode, msg)
        }

        return data
    }

    private func perform(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func method(for endpoint: APIEndpoint) -> String {
        // Allow explicit method override; default based on body presence
        if endpoint.method != "GET" { return endpoint.method }
        return endpoint.body != nil ? "POST" : "GET"
    }

    // MARK: - Token refresh

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = sessionManager.getRefreshToken() else { throw APIError.unauthorized }
        guard let url = URL(string: baseURL + "/auth/refresh") else { throw APIError.invalidURL }

        struct Body: Encodable  { let refreshToken: String }
        struct Response: Decodable { let accessToken: String; let refreshToken: String }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(Body(refreshToken: refreshToken))

        let (data, response) = try await perform(req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.unauthorized
        }
        let decoded = try decoder.decode(Response.self, from: data)
        sessionManager.saveRefreshToken(decoded.refreshToken)
        return decoded.accessToken
    }
}

// MARK: - Type-erased Encodable helper

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: any Encodable) { _encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
