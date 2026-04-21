import Foundation

struct TaskFeedback: Codable, Identifiable {
    var id: String
    var taskId: String
    var date: Date
    var result: FeedbackResult
    var timing: String?
    var situation: String?
    var dogBehavior: String?
    var freeTextComment: String?

    enum FeedbackResult: String, Codable {
        case success, partial, failed

        var displayName: String {
            switch self {
            case .success: return "Success"
            case .partial: return "Partial success"
            case .failed:  return "Failed"
            }
        }

        var icon: String {
            switch self {
            case .success: return "✅"
            case .partial: return "🔶"
            case .failed:  return "❌"
            }
        }
    }
}
