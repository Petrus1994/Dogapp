import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: AuthViewModel
    let onSwitch: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer(minLength: AppTheme.Spacing.xxl)

                VStack(spacing: AppTheme.Spacing.s) {
                    Text("🐾")
                        .font(.system(size: 52))
                    Text("Welcome Back")
                        .font(AppTheme.Font.headline())
                    Text("Continue your training progress.")
                        .font(AppTheme.Font.body())
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                    AuthTextField(placeholder: "Email address", text: $vm.email, keyboardType: .emailAddress)
                    AuthTextField(placeholder: "Password", text: $vm.password, isSecure: true)
                    if !vm.password.isEmpty && vm.password.count < 6 {
                        Text("Password must be at least 6 characters")
                            .font(AppTheme.Font.caption())
                            .foregroundColor(.orange)
                            .padding(.horizontal, AppTheme.Spacing.xs)
                    }
                }

                if let error = vm.errorMessage {
                    ErrorBanner(message: error)
                }

                VStack(spacing: AppTheme.Spacing.s) {
                    PrimaryButton(title: "Log In", action: {
                        Task { await vm.login(appState: appState) }
                    }, isLoading: vm.isLoading, isDisabled: !vm.isLoginValid)

                    Button(action: onSwitch) {
                        Text("Don't have an account? ")
                            .foregroundColor(.secondary)
                        + Text("Sign up")
                            .foregroundColor(AppTheme.primaryFallback)
                            .bold()
                    }
                    .font(AppTheme.Font.body())
                }
            }
            .padding(AppTheme.Spacing.l)
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    LoginView(vm: AuthViewModel(), onSwitch: {})
        .environmentObject(AppState())
}
