import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: AuthViewModel
    let onSwitch: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer(minLength: AppTheme.Spacing.xxl)

                // Header
                VStack(spacing: AppTheme.Spacing.s) {
                    Text("🐾")
                        .font(.system(size: 52))
                    Text("Create Account")
                        .font(AppTheme.Font.headline())
                    Text("Start your dog training journey today.")
                        .font(AppTheme.Font.body())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Form
                VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                    AuthTextField(placeholder: "Email address", text: $vm.email, keyboardType: .emailAddress)
                    AuthTextField(placeholder: "Password", text: $vm.password, isSecure: true)
                    if !vm.password.isEmpty && vm.password.count < 6 {
                        Text("Password must be at least 6 characters")
                            .font(AppTheme.Font.caption())
                            .foregroundColor(.orange)
                            .padding(.horizontal, AppTheme.Spacing.xs)
                    }
                    if !vm.email.isEmpty && !vm.email.contains("@") {
                        Text("Please enter a valid email address")
                            .font(AppTheme.Font.caption())
                            .foregroundColor(.orange)
                            .padding(.horizontal, AppTheme.Spacing.xs)
                    }
                }

                // Error
                if let error = vm.errorMessage {
                    ErrorBanner(message: error)
                }

                // Actions
                VStack(spacing: AppTheme.Spacing.s) {
                    PrimaryButton(title: "Create Account", action: {
                        Task { await vm.register(appState: appState) }
                    }, isLoading: vm.isLoading, isDisabled: !vm.isLoginValid)

                    Button(action: onSwitch) {
                        Text("Already have an account? ")
                            .foregroundColor(.secondary)
                        + Text("Log in")
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

// MARK: - Shared Auth Components

struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    @State private var showText = false

    var body: some View {
        HStack {
            Group {
                if isSecure && !showText {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .font(AppTheme.Font.body())

            if isSecure {
                Button(action: { showText.toggle() }) {
                    Image(systemName: showText ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(AppTheme.Spacing.m)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppTheme.Radius.m)
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.red)
            Text(message)
                .font(AppTheme.Font.body(14))
                .foregroundColor(.red)
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .cornerRadius(AppTheme.Radius.s)
    }
}

#Preview {
    RegisterView(vm: AuthViewModel(), onSwitch: {})
        .environmentObject(AppState())
}
