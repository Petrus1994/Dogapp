import Foundation

final class RealBreedRecommendationService: BreedRecommendationServiceProtocol {

    private let client: AIClientProtocol
    private var cache = ResponseCache<String, [BreedRecommendation]>()

    init(client: AIClientProtocol = OpenAIResponsesClient()) {
        self.client = client
    }

    func getRecommendations(for profile: BreedSelectionProfile) async throws -> [BreedRecommendation] {
        // Cache key: fingerprint of the profile fields
        let key = "\(profile.lifestyle.rawValue)-\(profile.homeType.rawValue)-\(profile.experienceLevel.rawValue)-\(profile.availableTime.rawValue)-\(profile.hasChildren)-\(profile.goal.rawValue)-\(profile.sizePreference.rawValue)-\(profile.weightPreference.rawValue)-\(profile.coatType.rawValue)-\(profile.groomingTolerance.rawValue)-\(profile.noiseTolerance.rawValue)-\(profile.energyExpectation.rawValue)"
        if let cached = cache.get(key, ttl: AIConfig.breedCacheTTL) { return cached }

        let messages: [AIMessage] = [
            AIMessage(role: "system",    content: AIPrompts.BreedRecommendation.system),
            AIMessage(role: "developer", content: AIPrompts.BreedRecommendation.developer),
            AIMessage(role: "user",      content: AIPrompts.BreedRecommendation.userPrompt(profile: profile))
        ]

        let output = try await client.completeStructured(
            model:       AIConfig.breedRecommendModel,
            messages:    messages,
            temperature: AIConfig.defaultTemperature,
            maxTokens:   1024,
            schemaName:  "breed_recommendations",
            schema:      BreedRecommendationOutput.jsonSchema,
            as:          BreedRecommendationOutput.self
        )

        let results = output.toRecommendations()
        cache.set(results, for: key)
        return results
    }

    func getAllBreeds() async throws -> [String] {
        // Static list — no AI call needed. Could be fetched from backend/CDN in v2.
        return MockData.allBreedNames
    }
}
