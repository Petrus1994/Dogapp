import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.flow {
            case .splash:
                SplashView()

            case .auth:
                AuthFlowView()

            case .onboarding:
                OnboardingFlowView()

            case .main:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.flow)
    }
}
