import SwiftUI

struct AuthFlowView: View {
    @State private var showLogin = false
    @StateObject private var vm = AuthViewModel()

    var body: some View {
        NavigationStack {
            if showLogin {
                LoginView(vm: vm, onSwitch: {
                    vm.clearError()
                    showLogin = false
                })
            } else {
                RegisterView(vm: vm, onSwitch: {
                    vm.clearError()
                    showLogin = true
                })
            }
        }
    }
}
