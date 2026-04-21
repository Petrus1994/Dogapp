import SwiftUI

struct AIAdjustmentView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var appState: AppState
    let adjustment: AIAdjustment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                // Header
                VStack(spacing: AppTheme.Spacing.s) {
                    Text("🤖")
                        .font(.system(size: 48))
                    Text("AI Trainer Analysis")
                        .font(AppTheme.Font.headline())
                    Text("Here's what likely happened and what to do next.")
                        .font(AppTheme.Font.body())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.Spacing.m)

                adjustmentContent(adjustment)

                PrimaryButton(title: "Back to Today") {
                    router.popToTodayRoot()
                }
                .padding(.horizontal, AppTheme.Spacing.l)

                SecondaryButton(title: "Try Task Again") {
                    appState.resetTaskStatus(taskId: adjustment.taskId)
                    router.popToTodayRoot()
                }
                .padding(.horizontal, AppTheme.Spacing.l)

                Spacer(minLength: AppTheme.Spacing.xl)
            }
        }
        .navigationTitle("AI Advice")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func adjustmentContent(_ adj: AIAdjustment) -> some View {
        // What likely happened
        insightCard(icon: "💡", color: .orange, title: "What likely happened") {
            Text(adj.probableCause)
                .font(AppTheme.Font.body())
                .lineSpacing(4)
        }

        // Possible mistake
        insightCard(icon: "⚠️", color: .red, title: "Possible mistake") {
            Text(adj.probableMistake)
                .font(AppTheme.Font.body())
                .lineSpacing(4)
        }

        // Do now
        insightCard(icon: "✅", color: .green, title: "What to do now") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                ForEach(adj.doNow, id: \.self) { item in
                    bulletRow(text: item, color: .green)
                }
            }
        }

        // Avoid
        insightCard(icon: "🚫", color: .red, title: "What to avoid") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                ForEach(adj.avoid, id: \.self) { item in
                    bulletRow(text: item, color: .red)
                }
            }
        }

        // Next attempt
        insightCard(icon: "🔄", color: .blue, title: "Next attempt") {
            Text(adj.nextAttempt)
                .font(AppTheme.Font.body())
                .lineSpacing(4)
        }
    }

    private func insightCard<Content: View>(icon: String, color: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(spacing: AppTheme.Spacing.s) {
                Text(icon)
                Text(title)
                    .font(AppTheme.Font.title(15))
                    .foregroundColor(color)
            }
            content()
                .foregroundColor(.primary.opacity(0.8))
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
        .padding(.horizontal, AppTheme.Spacing.l)
    }

    private func bulletRow(text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
            Circle().fill(color).frame(width: 6, height: 6).padding(.top, 6)
            Text(text).font(AppTheme.Font.body()).lineSpacing(3)
        }
    }

}

#Preview {
    AIAdjustmentView(adjustment: AIAdjustment(
        id: "adj-1",
        taskId: "t1",
        probableCause: "The dog may have been distracted or overstimulated during the session.",
        probableMistake: "Session was too long or the reward timing was slightly off.",
        doNow: [
            "Take a 10-minute break before the next attempt",
            "Reduce session to 3–5 minutes maximum",
            "Use higher-value treats (chicken, cheese)"
        ],
        avoid: [
            "Repeating the command more than twice",
            "Training when the dog is tired or just ate",
            "Showing frustration"
        ],
        nextAttempt: "Try in a quieter environment with no distractions. Start with something the dog already knows to build confidence, then introduce this task."
    ))
    .environmentObject(AppRouter())
    .environmentObject(AppState())
}
