import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var isLoggingOut = false
    @Published var showLogoutConfirm = false
    @Published var showHasDogConfirm = false

    func logout(appState: AppState) async {
        isLoggingOut = true
        appState.logout()
        isLoggingOut = false
    }
}
