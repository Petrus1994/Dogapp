import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.m) {
                Text("🐾")
                    .font(.system(size: 72))

                Text("PawCoach")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryFallback)

                Text("Your AI Dog Training Partner")
                    .font(AppTheme.Font.body())
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview { SplashView() }
