import SwiftUI

struct PlanView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @State private var selectedTask: TrainingTask?
    @State private var showReview = false

    var body: some View {
        NavigationStack {
            Group {
                if let plan = appState.currentPlan {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                            // Progress header
                            PlanHeaderCard(plan: plan)
                                .padding(.horizontal, AppTheme.Spacing.l)
                                .padding(.top, AppTheme.Spacing.m)

                            // Current focus (large, prominent)
                            PlanFocusCard(plan: plan, router: router)
                                .padding(.horizontal, AppTheme.Spacing.l)

                            // Today's pending tasks (compact)
                            todaySection(plan: plan)

                            // Tips
                            if !plan.tips.isEmpty {
                                TipsSection(tips: Array(plan.tips.prefix(2)))
                                    .padding(.horizontal, AppTheme.Spacing.l)
                            }

                            // Today completion status
                            todayCompletionFooter(plan: plan)
                                .padding(.horizontal, AppTheme.Spacing.l)

                            // Review link
                            Button {
                                showReview = true
                            } label: {
                                HStack(spacing: AppTheme.Spacing.m) {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(AppTheme.primaryFallback)
                                        .frame(width: 22)
                                    Text("Review Progress")
                                        .font(AppTheme.Font.body(14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(AppTheme.Spacing.m)
                                .cardStyle()
                                .padding(.horizontal, AppTheme.Spacing.l)
                            }
                            .buttonStyle(.plain)

                            Spacer(minLength: AppTheme.Spacing.xl)
                        }
                    }
                } else {
                    LoadingView(message: "No plan yet")
                }
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .navigationTitle("Your Plan")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedTask) { task in
                NavigationStack {
                    TaskDetailView(task: task)
                }
            }
            .sheet(isPresented: $showReview) {
                NavigationStack {
                    WeeklySummaryView()
                }
            }
        }
    }

    @ViewBuilder
    private func todaySection(plan: Plan) -> some View {
        let pending = plan.todaysTasks.filter { $0.status == .pending }
        if !pending.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Text("Today")
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, AppTheme.Spacing.l)
                ForEach(pending) { task in
                    Button {
                        selectedTask = task
                    } label: {
                        HStack(spacing: AppTheme.Spacing.s) {
                            Text(task.category.icon).font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).font(AppTheme.Font.body(14))
                                Text(task.expectedOutcome)
                                    .font(AppTheme.Font.caption(12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(AppTheme.Spacing.m)
                        .cardStyle()
                        .padding(.horizontal, AppTheme.Spacing.l)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func todayCompletionFooter(plan: Plan) -> some View {
        let todayTasks = plan.todaysTasks
        let done = todayTasks.filter { $0.status == .completed || $0.status == .partial }.count
        let total = todayTasks.count

        if total == 0 {
            EmptyView()
        } else if done == total {
            HStack(spacing: AppTheme.Spacing.s) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Great work today!")
                        .font(AppTheme.Font.title(14))
                    Text("Tomorrow's plan will adapt based on today's results.")
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(AppTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08))
            .cornerRadius(AppTheme.Radius.m)
        } else {
            let pending = todayTasks.filter { $0.status != .completed && $0.status != .partial }
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                HStack(spacing: AppTheme.Spacing.s) {
                    Image(systemName: "clock").foregroundColor(.orange)
                    Text("\(pending.count) task\(pending.count == 1 ? "" : "s") still to do today:")
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(.secondary)
                }
                ForEach(pending.prefix(3)) { task in
                    Text("· \(task.title)")
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.leading, AppTheme.Spacing.l)
                }
            }
            .padding(AppTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(AppTheme.Radius.m)
        }
    }

    private func statusCircle(_ status: TrainingTask.TaskStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 8, height: 8)
    }

    private func statusColor(_ status: TrainingTask.TaskStatus) -> Color {
        switch status {
        case .pending:   return Color.gray.opacity(0.4)
        case .completed: return .green
        case .partial:   return .orange
        case .failed:    return .red
        }
    }
}

// MARK: - Plan focus card (current week focus, prominent)

private struct PlanFocusCard: View {
    let plan: Plan
    let router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Text("📍")
                Text("This week's focus")
                    .font(AppTheme.Font.caption(12))
                    .foregroundColor(AppTheme.primaryFallback)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .kerning(0.4)
            }
            Text(plan.weeklyFocus)
                .font(AppTheme.Font.title(16))
                .lineSpacing(3)
            Text(plan.goal)
                .font(AppTheme.Font.body(14))
                .foregroundColor(.secondary)
                .lineSpacing(3)
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct PlanHeaderCard: View {
    let plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.type.displayName)
                        .font(AppTheme.Font.caption())
                        .foregroundColor(AppTheme.primaryFallback)
                        .textCase(.uppercase)
                    Text(plan.title)
                        .font(AppTheme.Font.headline(20))
                }
                Spacer()
                Text("🐾")
                    .font(.system(size: 36))
            }

        }
        .padding(AppTheme.Spacing.m)
        .background(
            LinearGradient(
                colors: [AppTheme.primaryFallback.opacity(0.12), AppTheme.primaryFallback.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppTheme.Radius.l)
    }
}

#Preview {
    PlanView()
        .environmentObject({
            let s = AppState()
            s.currentPlan = MockData.puppyPlan
            return s
        }())
        .environmentObject(AppRouter())
}
