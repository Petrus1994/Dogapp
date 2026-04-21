import Foundation

/// Reads API credentials from Secrets.plist (git-ignored).
/// In production, replace this with a call to your backend proxy — the key
/// should never ship inside the app binary.
enum APIKeyProvider {

    /// The active OpenAI key for direct calls (MVP only).
    static var openAIKey: String {
        value(for: "OPENAI_API_KEY")
    }

    /// Optional proxy base URL. When non-empty, all AI calls are routed through
    /// your backend rather than hitting OpenAI directly — strongly recommended
    /// before launching to production.
    static var proxyBaseURL: String? {
        let v = value(for: "AI_PROXY_BASE_URL")
        return v.isEmpty ? nil : v
    }

    /// Railway backend base URL (no trailing slash).
    static var backendBaseURL: String {
        let v = value(for: "BACKEND_BASE_URL")
        return v.isEmpty ? "https://localhost:3000" : v
    }

    // MARK: - Private

    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any]
        else {
            assertionFailure("""
                ⚠️  Secrets.plist not found in the app bundle.
                    Copy Secrets.plist.example → Secrets.plist, fill in your key,
                    and make sure Xcode includes it in the target's 'Copy Bundle Resources'.
                """)
            return [:]
        }
        return dict
    }()

    private static func value(for key: String) -> String {
        (secrets[key] as? String) ?? ""
    }
}
