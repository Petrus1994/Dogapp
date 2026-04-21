import SwiftUI

@MainActor
final class BreedSelectionViewModel: ObservableObject {
    @Published var lifestyle         = BreedSelectionProfile.Lifestyle.moderate
    @Published var homeType          = BreedSelectionProfile.HomeType.apartment
    @Published var experience        = BreedSelectionProfile.ExperienceLevel.firstDog
    @Published var availableTime     = BreedSelectionProfile.AvailableTime.medium
    @Published var hasChildren       = false
    @Published var goal              = BreedSelectionProfile.DogGoal.companion
    @Published var sizePreference    = BreedSelectionProfile.SizePreference.noPreference
    @Published var weightPreference  = BreedSelectionProfile.WeightPreference.noPreference
    @Published var coatType          = BreedSelectionProfile.CoatType.noPreference
    @Published var groomingTolerance = BreedSelectionProfile.GroomingTolerance.medium
    @Published var noiseTolerance    = BreedSelectionProfile.NoiseTolerance.okWithBarking
    @Published var energyExpectation = BreedSelectionProfile.EnergyExpectation.balanced

    @Published var recommendations: [BreedRecommendation] = []
    @Published var allBreeds:        [String]              = []
    @Published var selectedBreedName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: BreedRecommendationServiceProtocol

    init(service: BreedRecommendationServiceProtocol = AIServiceContainer.shared.breedRecommendationService) {
        self.service = service
    }

    func buildProfile() -> BreedSelectionProfile {
        BreedSelectionProfile(
            lifestyle:         lifestyle,
            homeType:          homeType,
            experienceLevel:   experience,
            availableTime:     availableTime,
            hasChildren:       hasChildren,
            goal:              goal,
            sizePreference:    sizePreference,
            weightPreference:  weightPreference,
            coatType:          coatType,
            groomingTolerance: groomingTolerance,
            noiseTolerance:    noiseTolerance,
            energyExpectation: energyExpectation
        )
    }

    func fetchRecommendations() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            recommendations = try await service.getRecommendations(for: buildProfile())
        } catch let error as AIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchAllBreeds() async {
        do {
            allBreeds = try await service.getAllBreeds()
        } catch {}
    }
}
