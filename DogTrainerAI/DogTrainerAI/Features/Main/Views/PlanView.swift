import SwiftUI

struct PlanView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @State private var showFullPlan = false
    @State private var selectedTask: TrainingTask?

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

                            // Full plan (collapsible)
                            DisclosureGroup(isExpanded: $showFullPlan) {
                                let daysSinceStart = Calendar.current.dateComponents([.day], from: plan.startDate, to: Date()).day ?? 0
                                let currentDay = max(1, daysSinceStart + 1)
                                VStack(spacing: AppTheme.Spacing.l) {
                                    ForEach(1...7, id: \.self) { day in
                                        let dayTasks = plan.tasks.filter { $0.scheduledDay == day }
                                        if !dayTasks.isEmpty {
                                            daySection(
                                                day: day,
                                                currentDay: currentDay,
                                                tasks: dayTasks,
                                                onTap: { taskId in
                                                    selectedTask = plan.tasks.first { $0.id == taskId }
                                                }
                                            )
                                        }
                                    }
                                }
                                .padding(.top, AppTheme.Spacing.s)
                            } label: {
                                HStack {
                                    Text("Full \(dayCount(plan))-day plan")
                                        .font(AppTheme.Font.title(14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(Int(plan.progressFraction * 100))% complete")
                                        .font(AppTheme.Font.caption(12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(AppTheme.Spacing.m)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppTheme.Radius.m)
                            }
                            .padding(.horizontal, AppTheme.Spacing.l)

                            Spacer(minLength: AppTheme.Spacing.xl)
                        }
                    }
                } else {
                    LoadingView(message: "No plan yet")
                }
            }
            .navigationTitle("Your Plan")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedTask) { task in
                NavigationStack {
                    TaskDetailView(task: task)
                }
            }
        }
    }

    private func dayCount(_ plan: Plan) -> Int {
        Set(plan.tasks.map { $0.scheduledDay }).max() ?? 7
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

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(spacing: AppTheme.Spacing.s) {
                Text(icon)
                Text(title).font(AppTheme.Font.title(15))
            }
            content()
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
        .padding(.horizontal, AppTheme.Spacing.l)
    }

    private func daySection(
        day: Int,
        currentDay: Int,
        tasks: [TrainingTask],
        onTap: @escaping (String) -> Void
    ) -> some View {
        let isFuture = day > currentDay
        let isToday  = day == currentDay
        let label    = isToday ? "Today — Day \(day)" : (day < currentDay ? "Day \(day)" : "Day \(day) — Upcoming")

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(spacing: AppTheme.Spacing.s) {
                if isToday {
                    Circle().fill(AppTheme.primaryFallback).frame(width: 8, height: 8)
                }
                Text(label)
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(isFuture ? .secondary : .primary)
                Spacer()
                Text("\(tasks.filter { $0.status == .completed || $0.status == .partial }.count)/\(tasks.count)")
                    .font(AppTheme.Font.caption())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            ForEach(tasks) { task in
                Button(action: { onTap(task.id) }) {
                    HStack(spacing: AppTheme.Spacing.s) {
                        statusCircle(task.status)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                Text(task.category.icon).font(.system(size: 12))
                                Text(task.title)
                                    .font(AppTheme.Font.body(14))
                                    .strikethrough(task.status == .completed)
                                    .foregroundColor(isFuture ? .secondary : .primary)
                            }
                            Text(task.expectedOutcome)
                                .font(AppTheme.Font.caption(12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(isFuture ? 0.4 : 1))
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .opacity(isFuture ? 0.55 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func categorySection(
        category: TrainingTask.TaskCategory,
        tasks: [TrainingTask],
        onTap: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(spacing: AppTheme.Spacing.s) {
                Text(category.icon)
                Text(category.displayName)
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(tasks.filter { $0.status == .completed || $0.status == .partial }.count)/\(tasks.count)")
                    .font(AppTheme.Font.caption())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            ForEach(tasks) { task in
                Button(action: { onTap(task.id) }) {
                    HStack(spacing: AppTheme.Spacing.s) {
                        statusCircle(task.status)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(AppTheme.Font.body(14))
                                .strikethrough(task.status == .completed)
                                .foregroundColor(.primary)
                            Text(task.expectedOutcome)
                                .font(AppTheme.Font.caption(12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
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

            ProgressBarView(progress: plan.progressFraction)
            Text("\(Int(plan.progressFraction * 100))% complete")
                .font(AppTheme.Font.caption())
                .foregroundColor(.secondary)
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
