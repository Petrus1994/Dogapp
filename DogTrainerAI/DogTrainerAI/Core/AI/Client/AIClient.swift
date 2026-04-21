import Foundation

// MARK: - Core AI client protocol
// Swap OpenAIResponsesClient for any other provider by conforming to this protocol.

protocol AIClientProtocol {
    /// Plain-text completion (for chat, explanations).
    func complete(
        model: AIModel,
        messages: [AIMessage],
        temperature: Double,
        maxTokens: Int
    ) async throws -> String

    /// Structured JSON completion. The schema is sent to the model's
    /// structured-output feature; the response is decoded into T.
    func completeStructured<T: Decodable>(
        model: AIModel,
        messages: [AIMessage],
        temperature: Double,
        maxTokens: Int,
        schemaName: String,
        schema: JSONValue,
        as type: T.Type
    ) async throws -> T
}

// MARK: - Shared retry helper

extension AIClientProtocol {
    /// Retries `work` up to AIConfig.maxRetries times with exponential back-off.
    func withRetry<T>(work: () async throws -> T) async throws -> T {
        var lastError: Error = AIError.maxRetriesExceeded
        for attempt in 0..<AIConfig.maxRetries {
            do {
                return try await work()
            } catch let error as AIError where error.isRetryable {
                lastError = error
                let delay = AIConfig.retryBaseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                throw error  // non-retryable errors bubble immediately
            }
        }
        throw lastError
    }
}
