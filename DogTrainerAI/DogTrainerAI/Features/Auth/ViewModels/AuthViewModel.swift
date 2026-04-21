import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email    = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol = RealAuthService()) {
        self.authService = authService
    }

    var isLoginValid: Bool {
        email.contains("@") && password.count >= 6
    }

    func login(appState: AppState) async {
        guard isLoginValid else {
            errorMessage = "Please enter a valid email and password (6+ characters)."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await authService.login(email: email, password: password)
            appState.loginSuccess(user: result.user, token: result.token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(appState: AppState) async {
        guard isLoginValid else {
            errorMessage = "Please enter a valid email and password (6+ characters)."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await authService.register(email: email, password: password)
            appState.loginSuccess(user: result.user, token: result.token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() { errorMessage = nil }
}
