import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let planService: PlanServiceProtocol
    private var hasStartedGeneration = false

    init(planService: PlanServiceProtocol = AIServiceContainer.shared.planService) {
        self.planService = planService
    }

    func generatePlan(appState: AppState) async {
        guard !hasStartedGeneration else { return }
        hasStartedGeneration = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let plan: Plan
            if let dogProfile = appState.dogProfile {
                plan = try await planService.generatePlan(for: dogProfile)
            } else {
                let scenario = appState.currentUser?.scenarioType ?? .noDogSkipped
                let breedName = appState.selectedBreed?.name
                plan = try await planService.generatePlanForNoDog(
                    scenarioType: scenario,
                    breed: breedName
                )
            }
            appState.completeOnboarding(plan: plan)
        } catch let error as AIError {
            hasStartedGeneration = false
            errorMessage = error.errorDescription
        } catch {
            hasStartedGeneration = false
            errorMessage = error.localizedDescription
        }
    }
}
