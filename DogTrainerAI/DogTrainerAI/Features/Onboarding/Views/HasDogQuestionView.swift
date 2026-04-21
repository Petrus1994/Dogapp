import SwiftUI

struct OnboardingStepDots: View {
    let current: Int
    var total: Int = 3

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...max(total, current), id: \.self) { step in
                Circle()
                    .fill(step <= current ? AppTheme.primaryFallback : Color(UIColor.tertiarySystemBackground))
                    .frame(width: step == current ? 10 : 7, height: step == current ? 10 : 7)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }
}

struct HasDogQuestionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            OnboardingStepDots(current: 1, total: 3)
                .padding(.top, AppTheme.Spacing.s)

            Spacer()

            VStack(spacing: AppTheme.Spacing.m) {
                Text("🐶")
                    .font(.system(size: 64))

                Text("Do you already have a dog?")
                    .font(AppTheme.Font.headline())
                    .multilineTextAlignment(.center)

                Text("This helps us build the right plan for you.")
                    .font(AppTheme.Font.body())
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: AppTheme.Spacing.m) {
                ChoiceCard(
                    icon: "🐕",
                    title: "Yes, I have a dog",
                    subtitle: "Build a training plan for my current dog"
                ) {
                    appState.currentUser?.scenarioType = .hasDog
                    router.navigateOnboarding(to: .dogProfile)
                }

                ChoiceCard(
                    icon: "🔍",
                    title: "Not yet",
                    subtitle: "I'm preparing to get a dog"
                ) {
                    router.navigateOnboarding(to: .noDogScenario)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            Spacer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ChoiceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.m) {
                Text(icon)
                    .font(.system(size: 32))
                    .frame(width: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.Font.title(16))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(AppTheme.Font.caption())
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    HasDogQuestionView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
