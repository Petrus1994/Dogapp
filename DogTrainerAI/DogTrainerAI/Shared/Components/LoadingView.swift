import SwiftUI

struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(AppTheme.primaryFallback)
            Text(message)
                .font(AppTheme.Font.body())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlanGeneratingView: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var dots: String { String(repeating: ".", count: dotCount + 1) }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            Text("🐾")
                .font(.system(size: 60))

            VStack(spacing: AppTheme.Spacing.s) {
                Text("Building your plan\(dots)")
                    .font(AppTheme.Font.headline())
                    .onReceive(timer) { _ in
                        dotCount = (dotCount + 1) % 3
                    }

                Text("Your AI trainer is analyzing your inputs and crafting a personalized training path.")
                    .font(AppTheme.Font.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }

            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.primaryFallback)
                .padding(.top, AppTheme.Spacing.m)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    PlanGeneratingView()
}
