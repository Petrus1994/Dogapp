import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @StateObject private var vm: TaskViewModel
    @State private var didSucceed = false
    @State private var didNote = false       // for prep plans after partial/failed
    let task: TrainingTask

    init(task: TrainingTask) {
        self.task = task
        self._vm = StateObject(wrappedValue: TaskViewModel(taskId: task.id))
    }

    // Prep plans don't benefit from dog-training clarification questions
    private var isPreparationPlan: Bool {
        let type = appState.currentPlan?.type
        return type == .preDogPreparationPlan || type == .breedPreparationPlan
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if didSucceed || didNote {
                VStack(spacing: AppTheme.Spacing.m) {
                    Text(didSucceed ? "✅" : "📝")
                        .font(.system(size: 64))
                    Text(didSucceed ? "Task complete!" : "Noted — keep going")
                        .font(AppTheme.Font.headline())
                    Text(didSucceed ? "Well done. Keep it up!" : "Every step counts, even the tricky ones.")
                        .font(AppTheme.Font.body())
                        .foregroundColor(.secondary)

                    if let message = appState.antiCheatMessage {
                        HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                                .font(.system(size: 13))
                            Text(message)
                                .font(AppTheme.Font.caption(13))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                        .padding(AppTheme.Spacing.m)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(AppTheme.Radius.s)
                        .padding(.horizontal, AppTheme.Spacing.l)
                        .transition(.opacity)
                    }
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: AppTheme.Spacing.l) {
                    Text("🐾").font(.system(size: 52))

                    VStack(spacing: AppTheme.Spacing.s) {
                        Text("How did it go?")
                            .font(AppTheme.Font.headline())
                        Text("\"\(task.title)\"")
                            .font(AppTheme.Font.body())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Text("Honest feedback helps your AI coach give better advice — even if it didn't go well.")
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }
            }

            Spacer()

            if vm.isLoading {
                ProgressView().scaleEffect(1.4).tint(AppTheme.primaryFallback)
            } else if !didSucceed && !didNote {
                VStack(spacing: AppTheme.Spacing.m) {
                    FeedbackButton(icon: "✅", title: "Success!", subtitle: "It went well", color: .green) {
                        Task {
                            let ok = await vm.submitFeedback(appState: appState, result: .success)
                            if ok {
                                withAnimation { didSucceed = true }
                                try? await Task.sleep(nanoseconds: 1_600_000_000)
                                router.popToTodayRoot()
                            }
                        }
                    }

                    FeedbackButton(icon: "🔶", title: "Partial success", subtitle: "Made some progress", color: .orange) {
                        Task {
                            let ok = await vm.submitFeedback(appState: appState, result: .partial)
                            if ok {
                                if isPreparationPlan {
                                    withAnimation { didNote = true }
                                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                                    router.popToTodayRoot()
                                } else {
                                    router.navigateToday(to: .clarification(task.id, .partial))
                                }
                            }
                        }
                    }

                    FeedbackButton(icon: "❌", title: "Didn't work", subtitle: "Let's figure out why", color: .red) {
                        Task {
                            let ok = await vm.submitFeedback(appState: appState, result: .failed)
                            if ok {
                                if isPreparationPlan {
                                    withAnimation { didNote = true }
                                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                                    router.popToTodayRoot()
                                } else {
                                    router.navigateToday(to: .clarification(task.id, .failed))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)
            }

            if let error = vm.errorMessage {
                ErrorBanner(message: error).padding(AppTheme.Spacing.l)
            }

            Spacer()
        }
        .navigationTitle("Task Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeedbackButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.m) {
                Text(icon).font(.system(size: 28)).frame(width: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTheme.Font.title(16))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(AppTheme.Font.caption())
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary).font(.caption)
            }
            .padding(AppTheme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                    .fill(color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                            .stroke(color.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FeedbackView(task: MockData.puppyPlan.tasks[0])
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
