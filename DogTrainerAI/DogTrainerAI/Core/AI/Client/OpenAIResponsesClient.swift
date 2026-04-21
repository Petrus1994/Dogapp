import Foundation

/// Production AI client targeting the OpenAI Responses API.
/// Endpoint: POST /v1/responses
/// Docs: https://platform.openai.com/docs/api-reference/responses
final class OpenAIResponsesClient: AIClientProtocol {

    private let session: URLSession
    private let baseURL: String
    private let apiKey: String

    init(
        apiKey: String = APIKeyProvider.openAIKey,
        baseURL: String = AIConfig.baseURL,
        session: URLSession = .shared
    ) {
        self.apiKey  = apiKey
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Plain text

    func complete(
        model: AIModel,
        messages: [AIMessage],
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        try await withRetry {
            let request = OpenAIResponsesRequest(
                model: model.rawValue,
                input: messages,
                temperature: temperature,
                maxOutputTokens: maxTokens,
                text: nil
            )
            let response: OpenAIResponse = try await self.send(request)
            guard let text = response.firstTextContent else {
                throw AIError.emptyResponse
            }
            return text
        }
    }

    // MARK: - Structured output

    func completeStructured<T: Decodable>(
        model: AIModel,
        messages: [AIMessage],
        temperature: Double,
        maxTokens: Int,
        schemaName: String,
        schema: JSONValue,
        as type: T.Type
    ) async throws -> T {
        try await withRetry {
            let textFormat = OpenAIResponsesRequest.TextFormat(
                format: .init(
                    type: "json_schema",
                    name: schemaName,
                    schema: schema,
                    strict: true
                )
            )
            let request = OpenAIResponsesRequest(
                model: model.rawValue,
                input: messages,
                temperature: temperature,
                maxOutputTokens: maxTokens,
                text: textFormat
            )
            let response: OpenAIResponse = try await self.send(request)
            guard let jsonText = response.firstTextContent else {
                throw AIError.emptyResponse
            }
            guard let data = jsonText.data(using: .utf8) else {
                throw AIError.structuredOutputParsingFailed("Response text is not valid UTF-8")
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw AIError.decodingError(error)
            }
        }
    }

    // MARK: - HTTP transport

    private func send<T: Decodable>(_ body: some Encodable) async throws -> T {
        guard !apiKey.isEmpty, apiKey != "PASTE_YOUR_NEW_KEY_HERE" else {
            throw AIError.missingAPIKey
        }

        guard let url = URL(string: baseURL + AIConfig.responsesPath) else {
            throw AIError.providerError("Invalid base URL: \(baseURL)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 60

        do {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AIError.providerError("Failed to encode request: \(error)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw AIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIError.providerError("Non-HTTP response")
        }

        if http.statusCode == 429 { throw AIError.rateLimited }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AIError.httpError(statusCode: http.statusCode, body: body)
        }

        // First decode into the Responses API envelope
        let envelope: OpenAIResponse
        do {
            envelope = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            throw AIError.decodingError(error)
        }

        // Surface provider-level errors
        if let err = envelope.error {
            throw AIError.providerError(err.message)
        }

        // Then try to decode directly into T (used when T == OpenAIResponse)
        if let result = envelope as? T { return result }

        // Caller expects T == OpenAIResponse in our usage pattern
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AIError.decodingError(error)
        }
    }
}
