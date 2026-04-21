import Foundation

// MARK: - OpenAI Responses API inbound response shapes

struct OpenAIResponse: Decodable {
    let id: String
    let object: String
    let model: String
    let output: [OutputItem]
    let usage: Usage?
    let error: OpenAIError?

    struct OutputItem: Decodable {
        let type: String
        let role: String?
        let content: [ContentBlock]?
    }

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens  = "input_tokens"
            case outputTokens = "output_tokens"
            case totalTokens  = "total_tokens"
        }
    }

    struct OpenAIError: Decodable {
        let code: String?
        let message: String
        let type: String?
    }

    /// Extracts the first assistant text block from output.
    var firstTextContent: String? {
        output
            .filter { $0.type == "message" }
            .compactMap { $0.content }
            .flatMap { $0 }
            .filter { $0.type == "output_text" }
            .compactMap { $0.text }
            .first
    }
}

// MARK: - AI-layer errors

enum AIError: LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case httpError(statusCode: Int, body: String)
    case emptyResponse
    case decodingError(Error)
    case structuredOutputParsingFailed(String)
    case rateLimited
    case maxRetriesExceeded
    case providerError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "AI service is not configured. Please contact support."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .httpError(let code, _):
            return "Server returned error \(code). Please try again."
        case .emptyResponse:
            return "The AI returned an empty response. Please try again."
        case .decodingError:
            return "Unexpected response format from AI. Please try again."
        case .structuredOutputParsingFailed:
            return "Could not parse the AI response. Please try again."
        case .rateLimited:
            return "You've reached the request limit. Please wait a moment."
        case .maxRetriesExceeded:
            return "The service is temporarily unavailable. Please try again later."
        case .providerError(let msg):
            return msg
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .httpError(statusCode: 500..., _), .rateLimited:
            return true
        default:
            return false
        }
    }
}
