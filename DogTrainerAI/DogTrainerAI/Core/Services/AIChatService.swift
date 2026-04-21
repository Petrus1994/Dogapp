import Foundation

protocol AIChatServiceProtocol {
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        context: ChatContext
    ) async throws -> String
}

struct ChatContext {
    var dogProfile: DogProfile?
    var plan: Plan?
    var scenarioType: User.ScenarioType?
    var recentFeedback: [TaskFeedback]
    var behaviorProgress: BehaviorProgress = .initial
    var todayActivities: [DailyActivity] = []
    var recentBehaviorEvents: [BehaviorEvent] = []
}

final class MockAIChatService: AIChatServiceProtocol {
    private let responses = [
        "Great question! Consistency is key with puppies. Try practicing the same command 3-4 times per session, always rewarding with a small treat immediately after the desired behavior.",
        "That's completely normal for this age. The key is to redirect attention calmly and reward when they settle. Avoid punishments — they increase anxiety.",
        "For leash pulling, stop walking completely the moment they pull. Wait for slack in the leash, then continue. Dogs learn quickly that pulling stops the walk.",
        "Socialization during the first 3 months is critical. Expose your puppy to different sounds, surfaces, and people in a calm, positive way.",
        "The best feeding schedule for a puppy this age is 3 times daily at fixed times. This also helps with toilet training since digestion becomes predictable.",
        "Try the 'sit' command before every meal. It teaches impulse control and creates a calm routine around feeding time.",
        "Remember: short, positive sessions are far more effective than long ones. 5 minutes of focused training beats 30 minutes of frustration.",
    ]

    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        context: ChatContext
    ) async throws -> String {
        try await Task.sleep(nanoseconds: 1_500_000_000)
        return responses.randomElement() ?? "I'm here to help! Could you tell me more?"
    }
}

// MARK: - Real Claude / OpenAI integration
/*
 To integrate with Claude API:
 1. Store API key in Keychain (never in source)
 2. Build a system prompt combining:
    - Dog profile context
    - Current plan summary
    - Recent feedback
    - Training methodology base prompt (stored server-side or in Prompts/)
 3. POST to https://api.anthropic.com/v1/messages with:
    - model: "claude-opus-4-7"
    - system: <built system prompt>
    - messages: history + new user message
    - max_tokens: 1024

 Prompt template (Prompts/chat_system.txt):
 You are a certified dog trainer assistant. You follow positive reinforcement methodology.
 The user's dog: {{dogName}}, {{ageGroup}} {{breed}}.
 Current training focus: {{weeklyFocus}}.
 Recent issues: {{recentIssues}}.
 Answer concisely, practically, and warmly.
*/
