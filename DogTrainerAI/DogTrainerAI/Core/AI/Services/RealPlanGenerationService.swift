import Foundation

final class RealPlanGenerationService: PlanServiceProtocol {

    private let client: AIClientProtocol
    private var cache = ResponseCache<String, Plan>()

    init(client: AIClientProtocol = OpenAIResponsesClient()) {
        self.client = client
    }

    // MARK: - PlanServiceProtocol

    func generatePlan(for dogProfile: DogProfile) async throws -> Plan {
        let cacheKey = "dog-\(dogProfile.id)-\(dogProfile.issues.map(\.rawValue).sorted().joined())"
        if let cached = cache.get(cacheKey, ttl: AIConfig.planCacheTTL) { return cached }

        let input = PlanGenerationInput(
            scenario: .hasDog,
            dogProfile: dogProfile,
            selectedBreed: nil
        )
        let plan = try await generate(input: input)
        cache.set(plan, for: cacheKey)
        return plan
    }

    func generatePlanForNoDog(scenarioType: User.ScenarioType, breed: String?) async throws -> Plan {
        let cacheKey = "nodog-\(scenarioType.rawValue)-\(breed ?? "none")"
        if let cached = cache.get(cacheKey, ttl: AIConfig.planCacheTTL) { return cached }

        let input = PlanGenerationInput(
            scenario: scenarioType,
            dogProfile: nil,
            selectedBreed: breed
        )
        let plan = try await generate(input: input)
        cache.set(plan, for: cacheKey)
        return plan
    }

    // MARK: - Private

    private func generate(input: PlanGenerationInput) async throws -> Plan {
        let messages: [AIMessage] = [
            AIMessage(role: "system",    content: AIPrompts.PlanGeneration.system),
            AIMessage(role: "developer", content: AIPrompts.PlanGeneration.developer),
            AIMessage(role: "user",      content: AIPrompts.PlanGeneration.userPrompt(input: input))
        ]

        let output = try await client.completeStructured(
            model:       AIConfig.planGenerationModel,
            messages:    messages,
            temperature: AIConfig.defaultTemperature,
            maxTokens:   AIConfig.defaultMaxTokens,
            schemaName:  "plan_response",
            schema:      PlanGenerationOutput.jsonSchema,
            as:          PlanGenerationOutput.self
        )
        return output.toPlan()
    }
}
