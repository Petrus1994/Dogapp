import SwiftUI

struct PlanGenerationView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: OnboardingViewModel

    @State private var showSlowWarning = false

    var body: some View {
        Group {
            if vm.isLoading {
                VStack(spacing: AppTheme.Spacing.l) {
                    PlanGeneratingView()
                    if showSlowWarning {
                        Text("Taking longer than expected…\nAlmost there!")
                            .font(AppTheme.Font.body(14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut, value: showSlowWarning)
            } else if let error = vm.errorMessage {
                VStack(spacing: AppTheme.Spacing.l) {
                    ErrorBanner(message: error)
                        .padding(.horizontal, AppTheme.Spacing.l)
                    PrimaryButton(title: "Try Again") {
                        showSlowWarning = false
                        Task { await vm.generatePlan(appState: appState) }
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                }
            } else {
                PlanGeneratingView()
            }
        }
        .task {
            await vm.generatePlan(appState: appState)
        }
        .onChange(of: vm.isLoading) { _, loading in
            if loading {
                showSlowWarning = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    if vm.isLoading { showSlowWarning = true }
                }
            }
        }
    }
}
