import Foundation

/// Dependency injection container for all AI services.
/// Swap useMock to get full offline/test mode with zero network calls.
final class AIServiceContainer {

    static let shared = AIServiceContainer()

    // MARK: - Configuration

    /// Set to `true` in previews and tests. Uses MockAIClient for all services.
    var useMock: Bool {
#if DEBUG
        return ProcessInfo.processInfo.environment["USE_MOCK_AI"] == "1"
#else
        return false
#endif
    }

    // MARK: - Shared AI client

    private lazy var liveClient: AIClientProtocol = OpenAIResponsesClient()
    private lazy var mockClient: AIClientProtocol = MockAIClient()

    var activeClient: AIClientProtocol {
        useMock ? mockClient : liveClient
    }

    // MARK: - Services (lazily constructed so the client choice is resolved at first use)

    lazy var planService: PlanServiceProtocol = {
        if useMock { return MockPlanService() }
        return RealPlanGenerationService(client: liveClient)
    }()

    lazy var breedRecommendationService: BreedRecommendationServiceProtocol = {
        if useMock { return MockBreedRecommendationService() }
        return RealBreedRecommendationService(client: liveClient)
    }()

    lazy var taskFeedbackService: TaskFeedbackServiceProtocol = {
        if useMock { return MockTaskFeedbackService() }
        return RealTaskFeedbackService(client: liveClient)
    }()

    lazy var chatService: AIChatServiceProtocol = {
        if useMock { return MockAIChatService() }
        return RealAIChatService(client: liveClient)
    }()

    // MARK: - Convenience accessor for the real feedback service (typed)

    var realFeedbackService: RealTaskFeedbackService? {
        taskFeedbackService as? RealTaskFeedbackService
    }
}

// MARK: - How to toggle mock mode in Xcode
//
// Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
// Add:  USE_MOCK_AI = 1   (enables mock)
// Remove or set to 0    (uses real OpenAI client)
