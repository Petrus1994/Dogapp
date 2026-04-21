import Foundation

final class RealTaskFeedbackService: TaskFeedbackServiceProtocol {

    private let client: AIClientProtocol
    // Locally queued feedback for when the network is unavailable (simple in-memory store for MVP)
    private var pendingFeedback: [TaskFeedback] = []

    init(client: AIClientProtocol = OpenAIResponsesClient()) {
        self.client = client
    }

    // MARK: - TaskFeedbackServiceProtocol

    func submitFeedback(_ feedback: TaskFeedback) async throws {
        // In real backend integration: POST /api/feedback
        // For now, enqueue locally so we don't lose data on network hiccups
        pendingFeedback.append(feedback)
        // Attempt to flush (no-op until real backend is wired)
    }

    func getAdjustment(for feedback: TaskFeedback, task: TrainingTask) async throws -> AIAdjustment {
        // This method receives a TaskFeedback. We need the clarification answers too.
        // TaskViewModel calls submitClarificationAndGetAdjustment which passes the full input.
        // Build a minimal context from the feedback's stored fields.
        let clarificationAnswers: [String: String] = [
            "1": feedback.situation   ?? "",
            "2": feedback.dogBehavior ?? "",
            "3": feedback.freeTextComment ?? ""
        ]
        let input = FeedbackAnalysisInput(
            task: task,
            feedback: feedback,
            dogProfile: nil,   // injected via analyzeWithDogProfile below
            clarificationAnswers: clarificationAnswers
        )
        return try await analyze(input: input)
    }

    /// Preferred entry point when full context is available.
    func analyzeWithDogProfile(
        feedback: TaskFeedback,
        task: TrainingTask,
        dogProfile: DogProfile?,
        clarificationAnswers: [String: String]
    ) async throws -> AIAdjustment {
        let input = FeedbackAnalysisInput(
            task: task,
            feedback: feedback,
            dogProfile: dogProfile,
            clarificationAnswers: clarificationAnswers
        )
        return try await analyze(input: input)
    }

    func getClarificationQuestions(for task: TrainingTask, result: TaskFeedback.FeedbackResult) -> [ClarificationQuestion] {
        // Questions are domain-specific, not AI-generated — fast, deterministic, no API call.
        switch task.category {
        case .toilet:
            return [
                ClarificationQuestion(id: "1", question: "When did the accident happen?", type: .singleChoice,
                    options: ["Right after eating", "During play", "While you were away", "After waking up"]),
                ClarificationQuestion(id: "2", question: "What did the dog do?", type: .singleChoice,
                    options: ["Squatted with no warning", "Circled and squatted", "Seemed anxious first", "Just went suddenly"]),
                ClarificationQuestion(id: "3", question: "Any additional context?", type: .freeText, options: [])
            ]
        case .leash:
            return [
                ClarificationQuestion(id: "1", question: "When did pulling start?", type: .singleChoice,
                    options: ["From the first step", "When seeing other dogs", "Near distractions", "Randomly"]),
                ClarificationQuestion(id: "2", question: "What did the dog do?", type: .singleChoice,
                    options: ["Pulled hard forward", "Lunged and barked", "Circled and tangled", "Dragged you sideways"]),
                ClarificationQuestion(id: "3", question: "Describe what happened:", type: .freeText, options: [])
            ]
        case .contact:
            return [
                ClarificationQuestion(id: "1", question: "How did the dog react?", type: .singleChoice,
                    options: ["Moved away", "Froze", "Snapped or growled", "Showed no reaction"]),
                ClarificationQuestion(id: "2", question: "What body part did you touch?", type: .singleChoice,
                    options: ["Paws", "Ears", "Mouth/muzzle", "Body/back"]),
                ClarificationQuestion(id: "3", question: "Anything else?", type: .freeText, options: [])
            ]
        default:
            return [
                ClarificationQuestion(id: "1", question: "What situation were you in?", type: .singleChoice,
                    options: ["At home", "Outside", "With other people", "With other animals"]),
                ClarificationQuestion(id: "2", question: "What did the dog do?", type: .singleChoice,
                    options: ["Ignored the command", "Got distracted", "Showed stress signs", "Refused to engage"]),
                ClarificationQuestion(id: "3", question: "Anything else to add?", type: .freeText, options: [])
            ]
        }
    }

    // MARK: - Private

    private func analyze(input: FeedbackAnalysisInput) async throws -> AIAdjustment {
        let messages: [AIMessage] = [
            AIMessage(role: "system",    content: AIPrompts.FeedbackAnalysis.system),
            AIMessage(role: "developer", content: AIPrompts.FeedbackAnalysis.developer),
            AIMessage(role: "user",      content: AIPrompts.FeedbackAnalysis.userPrompt(input: input))
        ]

        let output = try await client.completeStructured(
            model:       AIConfig.feedbackAnalysisModel,
            messages:    messages,
            temperature: AIConfig.defaultTemperature,
            maxTokens:   AIConfig.defaultMaxTokens,
            schemaName:  "feedback_analysis",
            schema:      FeedbackAnalysisOutput.jsonSchema,
            as:          FeedbackAnalysisOutput.self
        )
        return output.toAIAdjustment(taskId: input.feedback.taskId)
    }
}
