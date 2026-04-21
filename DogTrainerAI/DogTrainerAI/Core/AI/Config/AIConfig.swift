import Foundation

// MARK: - Model identifiers
// Update these when new OpenAI model versions are released.
// "GPT-5.4 mini / nano / full" in the product spec map to these IDs.
enum AIModel: String {
    /// Main workhorse — plan generation, chat, explanations, corrections.
    case mini = "gpt-4.1-mini"
    /// Lightweight — intent parsing, classification, structured extraction.
    case nano = "gpt-4.1-nano"
    /// Premium — deep reasoning, complex multi-step analysis (optional tier).
    case full = "gpt-4.1"
}

// MARK: - Global AI configuration
struct AIConfig {

    // MARK: Endpoints
    /// When proxyBaseURL is set all calls go through your backend instead of
    /// hitting OpenAI directly. For MVP, direct calls are used.
    static var baseURL: String {
        APIKeyProvider.proxyBaseURL ?? "https://api.openai.com/v1"
    }
    static let responsesPath = "/responses"

    // MARK: Defaults per task
    static let planGenerationModel    = AIModel.mini
    static let chatModel              = AIModel.mini
    static let breedRecommendModel    = AIModel.mini
    static let feedbackAnalysisModel  = AIModel.mini
    static let intentParsingModel     = AIModel.nano

    // MARK: Generation params
    static let defaultTemperature: Double = 0.4   // low = deterministic plans
    static let chatTemperature:    Double = 0.7   // higher = natural conversation
    static let defaultMaxTokens:   Int    = 2048
    static let chatMaxTokens:      Int    = 1500

    // MARK: Retry
    static let maxRetries      = 3
    static let retryBaseDelay  = 1.5 // seconds; doubles each attempt

    // MARK: Cache TTL (seconds)
    static let breedCacheTTL: TimeInterval = 3600  // 1 hour
    static let planCacheTTL:  TimeInterval = 300   // 5 min
}
