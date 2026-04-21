import SwiftUI

@MainActor
final class TaskViewModel: ObservableObject {
    @Published var feedback: TaskFeedback
    @Published var clarificationAnswers: [String: String] = [:]
    @Published var adjustment: AIAdjustment?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let feedbackService: TaskFeedbackServiceProtocol

    init(
        taskId: String,
        result: TaskFeedback.FeedbackResult = .success,
        feedbackService: TaskFeedbackServiceProtocol = AIServiceContainer.shared.taskFeedbackService
    ) {
        self.feedbackService = feedbackService
        self.feedback = TaskFeedback(
            id: UUID().uuidString,
            taskId: taskId,
            date: Date(),
            result: result
        )
    }

    func questions(for task: TrainingTask) -> [ClarificationQuestion] {
        feedbackService.getClarificationQuestions(for: task, result: feedback.result)
    }

    func submitFeedback(appState: AppState, result: TaskFeedback.FeedbackResult) async -> Bool {
        guard !isLoading else { return false }
        feedback.result = result
        isLoading = true
        defer { isLoading = false }
        do {
            try await feedbackService.submitFeedback(feedback)
            appState.updateTaskStatus(taskId: feedback.taskId, status: taskStatus(from: result))
            appState.recordFeedback(feedback)
            return true
        } catch let error as AIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Called after clarification questions are answered.
    /// Uses the richer `analyzeWithDogProfile` entry point when available.
    func submitClarificationAndGetAdjustment(task: TrainingTask, dogProfile: DogProfile?) async {
        isLoading = true
        defer { isLoading = false }

        feedback.situation        = clarificationAnswers["1"]
        feedback.dogBehavior      = clarificationAnswers["2"]
        feedback.freeTextComment  = clarificationAnswers["3"]

        do {
            if let realService = feedbackService as? RealTaskFeedbackService {
                adjustment = try await realService.analyzeWithDogProfile(
                    feedback:               feedback,
                    task:                   task,
                    dogProfile:             dogProfile,
                    clarificationAnswers:   clarificationAnswers
                )
            } else {
                adjustment = try await feedbackService.getAdjustment(for: feedback, task: task)
            }
        } catch let error as AIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func taskStatus(from result: TaskFeedback.FeedbackResult) -> TrainingTask.TaskStatus {
        switch result {
        case .success: return .completed
        case .partial: return .partial
        case .failed:  return .failed
        }
    }
}
