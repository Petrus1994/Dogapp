import Foundation

struct AIAdjustment: Codable, Identifiable, Hashable {
    var id: String
    var taskId: String
    var probableCause: String
    var probableMistake: String
    var doNow: [String]
    var avoid: [String]
    var nextAttempt: String
}
