import Foundation

struct User: Codable, Identifiable {
    var id: String
    var email: String
    var onboardingCompleted: Bool
    var scenarioType: ScenarioType?

    enum ScenarioType: String, Codable, CaseIterable {
        case hasDog
        case noDogChoosingBreed
        case noDogBreedSelected
        case noDogSkipped
    }
}
