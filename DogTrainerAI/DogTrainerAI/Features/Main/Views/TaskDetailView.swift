import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    let task: TrainingTask
    @State private var notesText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                // Hero card
                VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                    HStack {
                        Text(task.category.icon)
                            .font(.system(size: 36))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.category.displayName)
                                .font(AppTheme.Font.caption())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text(task.title)
                                .font(AppTheme.Font.headline(20))
                        }
                        Spacer()
                    }

                    HStack(spacing: AppTheme.Spacing.s) {
                        difficultyBadge
                        statusBadge
                    }
                }
                .padding(AppTheme.Spacing.m)
                .cardStyle()
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.top, AppTheme.Spacing.m)

                // Instructions
                sectionCard(title: "How to do it") {
                    Text(task.description)
                        .font(AppTheme.Font.body())
                        .lineSpacing(5)
                        .foregroundColor(.primary)
                }

                // Expected outcome
                sectionCard(title: "Expected outcome") {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                        Text("🎯")
                        Text(task.expectedOutcome)
                            .font(AppTheme.Font.body())
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                }

                // Notes
                sectionCard(title: "My Notes") {
                    TextField("What happened? What did you observe?", text: $notesText, axis: .vertical)
                        .font(AppTheme.Font.body())
                        .lineLimit(3...6)
                        .padding(AppTheme.Spacing.s)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(AppTheme.Radius.s)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: notesText) { _, newValue in
                            appState.updateTaskNotes(taskId: task.id, notes: newValue)
                        }
                }

                Spacer(minLength: AppTheme.Spacing.l)

                // CTA
                if isFutureTask {
                    HStack(spacing: AppTheme.Spacing.s) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text("Scheduled for Day \(task.scheduledDay) — check back then")
                            .font(AppTheme.Font.body(14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.m)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(AppTheme.Radius.m)
                    .padding(.horizontal, AppTheme.Spacing.l)
                } else if task.status == .pending || task.status == .partial {
                    VStack(spacing: 6) {
                        PrimaryButton(title: "Done — Rate How It Went") {
                            router.navigateToday(to: .feedback(task.id))
                        }
                        Text("You'll rate success or partial next")
                            .font(AppTheme.Font.caption())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                } else if task.status == .failed {
                    VStack(spacing: AppTheme.Spacing.s) {
                        completionBanner
                        SecondaryButton(title: "Try Again") {
                            appState.resetTaskStatus(taskId: task.id)
                            router.navigateToday(to: .feedback(task.id))
                        }
                        .padding(.horizontal, AppTheme.Spacing.l)
                    }
                } else {
                    completionBanner
                }

                Spacer(minLength: AppTheme.Spacing.xl)
            }
        }
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { notesText = task.notes }
    }

    private var currentDay: Int {
        let start = appState.currentPlan?.startDate ?? Date()
        let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(1, days + 1)
    }

    private var isFutureTask: Bool {
        task.scheduledDay > currentDay
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text(title)
                .font(AppTheme.Font.title(14))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
        .padding(.horizontal, AppTheme.Spacing.l)
    }

    private var difficultyBadge: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < task.difficulty ? AppTheme.primaryFallback : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            Text(difficultyLabel)
                .font(AppTheme.Font.caption(12))
                .foregroundColor(.secondary)
        }
    }

    private var difficultyLabel: String {
        switch task.difficulty {
        case 1:    return "Beginner"
        case 2:    return "Easy"
        case 3:    return "Medium"
        case 4:    return "Hard"
        default:   return "Expert"
        }
    }

    private var statusBadge: some View {
        Text(task.status.rawValue.capitalized)
            .font(AppTheme.Font.caption(12))
            .padding(.horizontal, AppTheme.Spacing.s)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
            .cornerRadius(AppTheme.Radius.s)
    }

    private var statusColor: Color {
        switch task.status {
        case .pending:   return .blue
        case .completed: return .green
        case .partial:   return .orange
        case .failed:    return .red
        }
    }

    private var completionBanner: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(task.status == .completed ? .green : .red)
            Text(task.status == .completed ? "Task completed!" : "Marked as \(task.status.rawValue)")
                .font(AppTheme.Font.body())
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                .fill((task.status == .completed ? Color.green : Color.red).opacity(0.1))
        )
        .padding(.horizontal, AppTheme.Spacing.l)
    }
}

#Preview {
    TaskDetailView(task: MockData.puppyPlan.tasks[0])
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
