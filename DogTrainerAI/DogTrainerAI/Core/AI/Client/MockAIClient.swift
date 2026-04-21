import Foundation

/// Drop-in mock for SwiftUI previews, unit tests, and offline development.
/// Returns deterministic, realistic responses without any network calls.
final class MockAIClient: AIClientProtocol {

    var simulatedDelay: UInt64 = 1_500_000_000  // 1.5 s
    var shouldFail     = false
    var failureError: AIError = .networkError(URLError(.notConnectedToInternet))

    func complete(
        model: AIModel,
        messages: [AIMessage],
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        try await delay()
        if shouldFail { throw failureError }
        return mockChatResponse(for: messages.last?.content ?? "")
    }

    func completeStructured<T: Decodable>(
        model: AIModel,
        messages: [AIMessage],
        temperature: Double,
        maxTokens: Int,
        schemaName: String,
        schema: JSONValue,
        as type: T.Type
    ) async throws -> T {
        try await delay()
        if shouldFail { throw failureError }

        let json: String
        switch schemaName {
        case "plan_response":            json = mockPlanJSON
        case "feedback_analysis":        json = mockFeedbackJSON
        case "breed_recommendations":    json = mockBreedJSON
        default:                         json = "{}"
        }

        guard let data = json.data(using: .utf8) else { throw AIError.emptyResponse }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AIError.decodingError(error)
        }
    }

    // MARK: - Mock payloads

    private func delay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func mockChatResponse(for input: String) -> String {
        let responses = [
            "Great question! Consistency is key with puppies. Practice the command 3–4 times per session, rewarding immediately after the desired behavior.",
            "That's completely normal at this age. Redirect calmly and reward settling behavior. Avoid punishments — they increase anxiety.",
            "For leash pulling: stop the moment the leash tightens. Wait for slack, then continue. Dogs learn fast that pulling stops the walk.",
            "Socialization during the first 3 months is critical. Expose your puppy to sounds, surfaces, and people in a calm, positive way.",
            "Short, positive sessions are far more effective than long ones. 5 focused minutes beats 30 frustrated minutes.",
        ]
        return responses.randomElement()!
    }

    private var mockPlanJSON: String { """
    {
      "title": "Puppy Foundation Plan",
      "plan_type": "puppy_plan",
      "goal": "Build a calm, trusting relationship and establish key habits in the first weeks.",
      "weekly_focus": "Toilet training & basic contact",
      "tasks": [
        {
          "title": "Morning Potty Routine",
          "description": "Take your puppy outside immediately after waking up. Use a consistent cue word like 'outside' and reward within 3 seconds of them going.",
          "category": "toilet",
          "difficulty": 1,
          "expected_outcome": "Puppy goes outside and receives immediate reward. Begin building the association."
        },
        {
          "title": "Name Recognition",
          "description": "Say the dog's name once clearly. The moment they look at you, mark with 'yes!' and give a treat. Repeat 5 times. Do not repeat the name if ignored.",
          "category": "contact",
          "difficulty": 1,
          "expected_outcome": "Puppy turns toward you when they hear their name at least 3/5 times."
        },
        {
          "title": "Handling & Touch",
          "description": "Gently touch paws, ears, and mouth for 1–2 seconds each. Pair each touch with a treat. Keep sessions under 5 minutes.",
          "category": "contact",
          "difficulty": 2,
          "expected_outcome": "Puppy tolerates handling without pulling away or showing stress."
        },
        {
          "title": "Scheduled Feeding",
          "description": "Feed at the same times each day. Remove the bowl after 15 minutes whether finished or not.",
          "category": "feeding",
          "difficulty": 1,
          "expected_outcome": "Puppy eats at set times, making toilet schedule predictable."
        },
        {
          "title": "Collar Introduction",
          "description": "Let the puppy sniff the collar before putting it on. Leave it on for 10 minutes, reward calm behavior.",
          "category": "leash",
          "difficulty": 2,
          "expected_outcome": "Puppy accepts collar without pawing at it."
        }
      ],
      "tips": [
        "Keep training sessions to 5 minutes maximum at this age.",
        "Always end on a win — ask for something easy before finishing.",
        "Puppies need 16–18 hours of sleep. Overtired puppies can't learn.",
        "Reward with tiny treats. Too much food reduces motivation."
      ]
    }
    """ }

    private var mockFeedbackJSON: String { """
    {
      "probable_cause": "The dog was likely distracted or overstimulated by the environment during the session.",
      "probable_mistake": "The training session was too long and the reward timing was slightly delayed.",
      "do_now": [
        "Take a 10-minute break before the next attempt",
        "Reduce the session to 3–5 minutes maximum",
        "Use higher-value treats such as chicken or cheese"
      ],
      "avoid": [
        "Repeating the command more than twice without a response",
        "Training when the dog is tired or right after eating",
        "Showing frustration — dogs read your energy"
      ],
      "next_attempt": "Try in a quieter environment with no distractions. Start with something the dog already knows to build confidence, then introduce this task when they are engaged."
    }
    """ }

    private var mockBreedJSON: String { """
    {
      "breeds": [
        {
          "name": "Labrador Retriever",
          "short_description": "Friendly, highly trainable, and adaptable to most lifestyles.",
          "why_it_fits": "Responds excellently to positive reinforcement, making it ideal for first-time owners. Its moderate energy level suits your available training time perfectly."
        },
        {
          "name": "Golden Retriever",
          "short_description": "Patient, gentle, and exceptionally good with families.",
          "why_it_fits": "One of the most forgiving breeds for new owners. Its calm temperament matches your lifestyle and it bonds deeply with children."
        },
        {
          "name": "Cavalier King Charles Spaniel",
          "short_description": "Affectionate, low-energy companion that thrives indoors.",
          "why_it_fits": "Perfect for apartment living with limited outdoor time. Minimal exercise demands align with your schedule, and it is famously gentle with children."
        }
      ]
    }
    """ }
}
