import SwiftUI

struct OnboardingIntroView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: AppTheme.Spacing.l) {
                Text("🐾")
                    .font(.system(size: 80))

                VStack(spacing: AppTheme.Spacing.s) {
                    Text("Your AI Dog Trainer")
                        .font(AppTheme.Font.headline(28))
                        .multilineTextAlignment(.center)

                    Text("This app helps you raise a calm, predictable, and well-behaved dog — guided by an AI trainer that adapts to you and your dog every step of the way.")
                        .font(AppTheme.Font.body())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }
            }

            Spacer()

            VStack(spacing: AppTheme.Spacing.m) {
                featureRow(icon: "📋", text: "Personalized daily training plans")
                featureRow(icon: "✅", text: "Track tasks and progress")
                featureRow(icon: "🤖", text: "AI feedback when things don't go as planned")
                featureRow(icon: "💬", text: "Chat with your AI trainer anytime")
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            Spacer()

            PrimaryButton(title: "Get Started") {
                router.navigateOnboarding(to: .hasDogQuestion)
            }
            .padding(AppTheme.Spacing.l)
        }
        .navigationBarHidden(true)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Text(icon).font(.system(size: 22))
            Text(text)
                .font(AppTheme.Font.body())
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

#Preview {
    OnboardingIntroView()
        .environmentObject(AppRouter())
}
