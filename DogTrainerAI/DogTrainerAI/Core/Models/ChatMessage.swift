import Foundation

struct ChatMessage: Codable, Identifiable {
    var id: String
    var role: MessageRole
    var content: String
    var timestamp: Date
    var isLoading: Bool

    init(id: String = UUID().uuidString,
         role: MessageRole,
         content: String,
         timestamp: Date = Date(),
         isLoading: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isLoading = isLoading
    }

    enum MessageRole: String, Codable {
        case user, assistant
    }
}
