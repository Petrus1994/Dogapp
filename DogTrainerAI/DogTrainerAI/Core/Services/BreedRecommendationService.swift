import Foundation

protocol BreedRecommendationServiceProtocol {
    func getRecommendations(for profile: BreedSelectionProfile) async throws -> [BreedRecommendation]
    func getAllBreeds() async throws -> [String]
}

final class MockBreedRecommendationService: BreedRecommendationServiceProtocol {
    func getRecommendations(for profile: BreedSelectionProfile) async throws -> [BreedRecommendation] {
        try await Task.sleep(nanoseconds: 1_500_000_000)

        switch profile.lifestyle {
        case .calm:
            return MockData.calmBreeds
        case .moderate:
            return MockData.moderateBreeds
        case .active:
            return MockData.activeBreeds
        }
    }

    func getAllBreeds() async throws -> [String] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return MockData.allBreedNames
    }
}
