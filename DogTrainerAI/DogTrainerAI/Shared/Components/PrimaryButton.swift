import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                    .fill(isDisabled ? Color.gray.opacity(0.4) : AppTheme.primaryFallback)
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(AppTheme.Font.title(16))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .disabled(isDisabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Font.title(16))
                .foregroundColor(AppTheme.primaryFallback)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                        .stroke(AppTheme.primaryFallback, lineWidth: 1.5)
                )
        }
    }
}

struct TextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Font.body())
                .foregroundColor(AppTheme.primaryFallback)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue") {}
        PrimaryButton(title: "Loading…", action: {}, isLoading: true)
        SecondaryButton(title: "Skip") {}
        TextButton(title: "Already have an account? Log in") {}
    }
    .padding()
}
