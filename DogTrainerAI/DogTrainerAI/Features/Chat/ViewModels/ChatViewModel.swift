import SwiftUI

enum ChatState {
    case idle, sending, failed
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText  = ""
    @Published var chatState: ChatState = .idle
    @Published var errorMessage: String?

    private let chatService: AIChatServiceProtocol

    init(chatService: AIChatServiceProtocol = AIServiceContainer.shared.chatService) {
        self.chatService = chatService
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hi! I'm your AI dog trainer. Ask me anything about your dog's behavior, training techniques, or your current plan. I'm here to help 🐾"
        ))
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && chatState != .sending
    }

    func sendMessage(context: ChatContext) async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        inputText = ""
        chatState = .sending
        errorMessage = nil

        let loadingMsg = ChatMessage(role: .assistant, content: "", isLoading: true)
        messages.append(loadingMsg)

        do {
            let response = try await chatService.sendMessage(
                text,
                history: messages.dropLast(),
                context: context
            )
            messages.removeLast()
            messages.append(ChatMessage(role: .assistant, content: response))
            chatState = .idle
        } catch let error as AIError {
            messages.removeLast()
            chatState = .failed
            errorMessage = error.errorDescription
        } catch {
            messages.removeLast()
            chatState = .failed
            errorMessage = "Couldn't reach the coach. Please try again."
        }
    }

    func retry(context: ChatContext) async {
        guard let last = messages.last, last.role == .user else { return }
        inputText = last.content
        messages.removeLast()
        await sendMessage(context: context)
    }

    func useSuggestion(_ text: String) {
        inputText = text
    }
}
