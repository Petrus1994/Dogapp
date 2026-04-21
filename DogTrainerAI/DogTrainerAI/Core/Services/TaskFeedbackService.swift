import Foundation

protocol TaskFeedbackServiceProtocol {
    func submitFeedback(_ feedback: TaskFeedback) async throws
    func getAdjustment(for feedback: TaskFeedback, task: TrainingTask) async throws -> AIAdjustment
    func getClarificationQuestions(for task: TrainingTask, result: TaskFeedback.FeedbackResult) -> [ClarificationQuestion]
}

struct ClarificationQuestion: Identifiable {
    let id: String
    let question: String
    let type: QuestionType
    let options: [String]

    enum QuestionType {
        case singleChoice
        case freeText
    }
}

final class MockTaskFeedbackService: TaskFeedbackServiceProtocol {
    func submitFeedback(_ feedback: TaskFeedback) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        // In real app: POST to /feedback endpoint
    }

    func getAdjustment(for feedback: TaskFeedback, task: TrainingTask) async throws -> AIAdjustment {
        try await Task.sleep(nanoseconds: 1_500_000_000)
        return AIAdjustment(
            id: UUID().uuidString,
            taskId: task.id,
            probableCause: "The dog may have been distracted or overstimulated during training.",
            probableMistake: "Training session was likely too long or the reward timing was slightly off.",
            doNow: [
                "Take a 10-minute break before the next attempt",
                "Reduce the session to 3–5 minutes maximum",
                "Use higher-value treats (chicken, cheese) as reward"
            ],
            avoid: [
                "Repeating the command more than twice",
                "Training when the dog is tired or just ate",
                "Showing frustration — dogs read your energy"
            ],
            nextAttempt: "Try in a quieter environment with no distractions. Start with something the dog already knows well to build confidence, then introduce the problematic task."
        )
    }

    func getClarificationQuestions(for task: TrainingTask, result: TaskFeedback.FeedbackResult) -> [ClarificationQuestion] {
        switch task.category {
        case .toilet:
            return [
                ClarificationQuestion(
                    id: "1", question: "When did the accident happen?",
                    type: .singleChoice,
                    options: ["Right after eating", "During play", "While you were away", "After waking up"]
                ),
                ClarificationQuestion(
                    id: "2", question: "Where did it happen?",
                    type: .singleChoice,
                    options: ["Living room", "Bedroom", "Hallway", "Other"]
                ),
                ClarificationQuestion(
                    id: "3", question: "Any additional context?",
                    type: .freeText,
                    options: []
                )
            ]
        case .leash:
            return [
                ClarificationQuestion(
                    id: "1", question: "When did the pulling start?",
                    type: .singleChoice,
                    options: ["From the first step", "When seeing other dogs", "Near distractions", "Randomly"]
                ),
                ClarificationQuestion(
                    id: "2", question: "What did the dog do?",
                    type: .singleChoice,
                    options: ["Pulled hard", "Lunged forward", "Barked and pulled", "Circled and tangled"]
                ),
                ClarificationQuestion(
                    id: "3", question: "Describe what happened:",
                    type: .freeText,
                    options: []
                )
            ]
        default:
            return [
                ClarificationQuestion(
                    id: "1", question: "What situation were you in?",
                    type: .singleChoice,
                    options: ["At home", "Outside", "With other people", "With other animals"]
                ),
                ClarificationQuestion(
                    id: "2", question: "What did the dog do?",
                    type: .singleChoice,
                    options: ["Ignored the command", "Got distracted", "Showed stress signals", "Refused to engage"]
                ),
                ClarificationQuestion(
                    id: "3", question: "Anything else to add?",
                    type: .freeText,
                    options: []
                )
            ]
        }
    }
}
