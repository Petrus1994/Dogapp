import SwiftUI

struct NoDogScenarioView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            OnboardingStepDots(current: 2, total: 3)
                .padding(.top, AppTheme.Spacing.s)

            Spacer()

            VStack(spacing: AppTheme.Spacing.m) {
                Text("🔍")
                    .font(.system(size: 64))

                Text("Do you need help choosing a breed?")
                    .font(AppTheme.Font.headline())
                    .multilineTextAlignment(.center)

                Text("We can match you with the perfect dog for your lifestyle, or you can jump straight to preparation.")
                    .font(AppTheme.Font.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.l)
            }

            Spacer()

            VStack(spacing: AppTheme.Spacing.m) {
                ChoiceCard(
                    icon: "✨",
                    title: "Help me choose a breed",
                    subtitle: "Answer a few questions — we'll match you"
                ) {
                    appState.currentUser?.scenarioType = .noDogChoosingBreed
                    router.navigateOnboarding(to: .breedQuestionnaire)
                }

                ChoiceCard(
                    icon: "✅",
                    title: "I already know the breed",
                    subtitle: "Select your breed and get a prep plan"
                ) {
                    appState.currentUser?.scenarioType = .noDogBreedSelected
                    router.navigateOnboarding(to: .breedPicker)
                }

                ChoiceCard(
                    icon: "⏩",
                    title: "Skip for now",
                    subtitle: "Get a universal preparation plan"
                ) {
                    appState.currentUser?.scenarioType = .noDogSkipped
                    router.navigateOnboarding(to: .planGeneration)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            Spacer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NoDogScenarioView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
