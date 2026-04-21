import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @StateObject private var onboardingVM = OnboardingViewModel()
    @StateObject private var dogProfileVM = DogProfileViewModel()
    @StateObject private var breedVM      = BreedSelectionViewModel()

    var body: some View {
        NavigationStack(path: $router.onboardingPath) {
            OnboardingIntroView()
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .hasDogQuestion:
                        HasDogQuestionView()

                    case .dogProfile:
                        DogProfileView(vm: dogProfileVM)

                    case .noDogScenario:
                        NoDogScenarioView()

                    case .breedQuestionnaire:
                        BreedQuestionnaireView(vm: breedVM)

                    case .breedRecommendations:
                        BreedRecommendationsView(vm: breedVM)

                    case .breedPicker:
                        BreedPickerView(vm: breedVM)

                    case .planGeneration:
                        PlanGenerationView(vm: onboardingVM)
                    }
                }
        }
        .environmentObject(dogProfileVM)
        .environmentObject(breedVM)
        .environmentObject(onboardingVM)
    }
}
