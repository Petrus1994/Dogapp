import Foundation

final class RealAIChatService: AIChatServiceProtocol {

    private let client: AIClientProtocol
    // Simple debounce: track the last send timestamp per context key
    private var lastSentAt: Date?
    private let debounceInterval: TimeInterval = 0.3

    init(client: AIClientProtocol = OpenAIResponsesClient()) {
        self.client = client
    }

    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        context: ChatContext
    ) async throws -> String {
        // Debounce: prevent double-sends from rapid taps
        if let last = lastSentAt, Date().timeIntervalSince(last) < debounceInterval {
            try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
        }
        lastSentAt = Date()

        var messages: [AIMessage] = [
            // Prompt 1: AI trainer identity + full methodology
            AIMessage(role: "system",    content: AIPrompts.Chat.system),
            // Prompt 2 + 4: behavioral routing rules + mobile response format
            AIMessage(role: "developer", content: AIPrompts.Chat.developer),
            // Prompt 3: live dog memory + context (filled from real data)
            AIMessage(role: "developer", content: AIPrompts.Chat.memoryInjection(context: context))
        ]

        // Inject conversation history (last 10 exchanges to control token cost)
        let historyWindow = history.suffix(10)
        for msg in historyWindow where !msg.isLoading {
            messages.append(AIMessage(
                role:    msg.role == .user ? "user" : "assistant",
                content: msg.content
            ))
        }

        // Add the new user message
        messages.append(AIMessage(role: "user", content: message))

        return try await client.complete(
            model:       AIConfig.chatModel,
            messages:    messages,
            temperature: AIConfig.chatTemperature,
            maxTokens:   AIConfig.chatMaxTokens
        )
    }
}
