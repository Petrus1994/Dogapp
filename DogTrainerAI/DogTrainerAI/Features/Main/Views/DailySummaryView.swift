import SwiftUI

struct DailySummaryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    private var norms: ActivityNorms? { appState.activityNorms }

    private var overallCompletion: Double {
        guard let norms else {
            let done = DailyActivity.ActivityType.allCases.filter { type in
                appState.todayActivities.contains { $0.type == type && $0.completed }
            }.count
            return Double(done) / Double(DailyActivity.ActivityType.allCases.count)
        }
        return NormCalculationService.overallCompletion(activities: appState.todayActivities, norms: norms)
    }

    private var taskCompletion: (completed: Int, partial: Int, failed: Int, total: Int) {
        guard let plan = appState.currentPlan else { return (0, 0, 0, 0) }
        let all = plan.tasks.filter { $0.status != .pending }
        return (
            all.filter { $0.status == .completed }.count,
            all.filter { $0.status == .partial }.count,
            all.filter { $0.status == .failed }.count,
            all.count
        )
    }

    private var todayIssues: [BehaviorEvent.BehaviorIssue] {
        let events = appState.allBehaviorEvents.filter { Calendar.current.isDateInToday($0.date) }
        var counts: [BehaviorEvent.BehaviorIssue: Int] = [:]
        for event in events {
            for issue in event.issues where issue != .noIssues {
                counts[issue, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { $0.key }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                // Header
                VStack(spacing: AppTheme.Spacing.s) {
                    Text("Today's Summary")
                        .font(AppTheme.Font.headline())
                    Text(Date(), style: .date)
                        .font(AppTheme.Font.body())
                        .foregroundColor(.secondary)
                }
                .padding(.top, AppTheme.Spacing.m)

                // Completion ring
                CompletionRingSection(fraction: overallCompletion, isNormBased: norms != nil)
                    .padding(.horizontal, AppTheme.Spacing.l)

                // Routine completion
                if let routine = appState.dailyRoutine {
                    RoutineSummarySection(routine: routine)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // Norm breakdown (if dog profile exists)
                if let norms {
                    NormBreakdownSection(activities: appState.todayActivities, norms: norms)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // Activity balance
                let balance = appState.activityBalance
                if balance.overallBalance != .balanced {
                    SummarySection(title: "Activity Balance") {
                        BalanceMiniRow(label: "Physical", minutes: balance.physicalMinutes,
                                       target: balance.physicalTarget,
                                       fraction: balance.physicalFraction)
                        BalanceMiniRow(label: "Mental", minutes: balance.mentalMinutes,
                                       target: balance.mentalTarget,
                                       fraction: balance.mentalFraction)
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                }

                // Dog state
                if let name = appState.dogProfile?.name {
                    DogStateCard(dogState: appState.dogState, dogName: name)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // Task results
                let t = taskCompletion
                if t.total > 0 {
                    SummarySection(title: "Training Tasks") {
                        SummaryRow(icon: "✅", label: "Completed", value: "\(t.completed)")
                        SummaryRow(icon: "🔶", label: "Partial",   value: "\(t.partial)")
                        SummaryRow(icon: "❌", label: "Missed",    value: "\(t.failed)")
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                }

                // Behavior issues
                if !todayIssues.isEmpty {
                    SummarySection(title: "Behavior Issues Detected") {
                        ForEach(todayIssues.prefix(5), id: \.self) { issue in
                            SummaryRow(icon: issue.icon, label: issue.displayName, value: "")
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                }

                // Progress
                SummarySection(title: "Progress") {
                    SummaryRow(icon: appState.userProgress.level.icon,
                               label: appState.userProgress.level.displayName,
                               value: "\(appState.userProgress.totalPoints) pts total")
                    SummaryRow(icon: "🔥", label: "Streak",
                               value: "\(appState.userProgress.currentStreak) days")
                }
                .padding(.horizontal, AppTheme.Spacing.l)

                // AI coaching insight
                let tip = appState.coachingInsight ?? staticTip
                VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                    Label("Coach's Take", systemImage: "brain.head.profile")
                        .font(AppTheme.Font.title(15))
                        .foregroundColor(AppTheme.primaryFallback)

                    Text(tip)
                        .font(AppTheme.Font.body(15))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                .padding(AppTheme.Spacing.m)
                .cardStyle()
                .padding(.horizontal, AppTheme.Spacing.l)

                Spacer(minLength: AppTheme.Spacing.xl)
            }
        }
        .navigationTitle("Daily Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var staticTip: String {
        // Routine-aware tip comes first
        if let routine = appState.dailyRoutine,
           let msg = RoutineEngineService.balanceMessage(routine: routine,
                                                         activities: appState.todayActivities) {
            return msg
        }
        // Balance-aware tip
        if let msg = appState.activityBalance.coachingMessage { return msg }
        // Fallback
        if appState.dogState.energyLevel > 0.75 {
            return "High energy today — start tomorrow with a longer walk before training."
        } else if appState.dogState.calmness < 0.35 {
            return "Unsettled day. Focus on calm, predictable routine tomorrow."
        } else if overallCompletion < 0.5 {
            return "Less than half of daily activities completed. Even short sessions build the routine."
        }
        return "Good progress. Consistency over 7–14 days creates lasting behavior change."
    }
}

// MARK: - Norm breakdown

private struct NormBreakdownSection: View {
    let activities: [DailyActivity]
    let norms: ActivityNorms

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Activity vs Targets")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)

            VStack(spacing: AppTheme.Spacing.s) {
                NormRow(
                    icon: "🦮", label: "Walk",
                    actual: walkActual,
                    target: "\(norms.walkMinPerDay) min",
                    fraction: NormCalculationService.walkCompletion(activities: activities, norms: norms)
                )
                NormRow(
                    icon: "🎾", label: "Play",
                    actual: playActual,
                    target: "\(norms.playMinPerDay) min",
                    fraction: NormCalculationService.playCompletion(activities: activities, norms: norms)
                )
                NormRow(
                    icon: "🍖", label: "Feeding",
                    actual: feedingActual,
                    target: "\(norms.feedingsPerDay)x",
                    fraction: NormCalculationService.feedingCompletion(activities: activities, norms: norms)
                )
                NormRow(
                    icon: "🎯", label: "Training",
                    actual: trainingActual,
                    target: "\(norms.trainingSessionsPerDay) session\(norms.trainingSessionsPerDay > 1 ? "s" : "")",
                    fraction: NormCalculationService.trainingCompletion(activities: activities, norms: norms)
                )
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
        }
    }

    private var walkActual: String {
        let min = activities.filter { $0.type == .walking && $0.completed }
            .reduce(0) { $0 + $1.durationMinutes }
        let km  = activities.filter { $0.type == .walking && $0.completed }
            .compactMap { $0.distanceKm }.reduce(0, +)
        if km > 0 { return "\(min) min · \(String(format: "%.1f", km)) km" }
        return min > 0 ? "\(min) min" : "Not logged"
    }

    private var playActual: String {
        let min = activities.filter { $0.type == .playing && $0.completed }
            .reduce(0) { $0 + $1.durationMinutes }
        return min > 0 ? "\(min) min" : "Not logged"
    }

    private var feedingActual: String {
        let count = activities.filter { $0.type == .feeding && $0.completed }.count
        return count > 0 ? "\(count)x" : "Not logged"
    }

    private var trainingActual: String {
        let sessions = activities.filter { $0.type == .training && $0.completed }.count
        return sessions > 0 ? "\(sessions) session\(sessions > 1 ? "s" : "")" : "Not logged"
    }
}

private struct NormRow: View {
    let icon: String
    let label: String
    let actual: String
    let target: String
    let fraction: Double

    var color: Color {
        fraction >= 1.0 ? .green : fraction >= 0.5 ? .orange : .red
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(icon).font(.system(size: 14))
                Text(label).font(AppTheme.Font.body(14))
                Spacer()
                Text(actual)
                    .font(AppTheme.Font.caption(12))
                    .foregroundColor(fraction > 0 ? color : .secondary)
                Text("/ \(target)")
                    .font(AppTheme.Font.caption(12))
                    .foregroundColor(.secondary)
            }
            NormProgressBar(fraction: fraction, color: color)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

// MARK: - Routine summary

private struct RoutineSummarySection: View {
    let routine: DailyRoutine

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Daily Routine")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)

            VStack(spacing: AppTheme.Spacing.xs) {
                HStack {
                    Text("Cycles completed")
                        .font(AppTheme.Font.body(14))
                    Spacer()
                    Text("\(routine.completedCount) / \(routine.totalCount)")
                        .font(AppTheme.Font.body(14))
                        .foregroundColor(.secondary)
                }
                NormProgressBar(fraction: routine.completionFraction,
                                color: routine.completionFraction >= 0.8 ? .green : AppTheme.primaryFallback)

                if !routine.overduePhases.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("\(routine.overduePhases.count) phase\(routine.overduePhases.count > 1 ? "s" : "") skipped or missed")
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
        }
    }
}

// MARK: - Balance row

private struct BalanceMiniRow: View {
    let label: String
    let minutes: Int
    let target: Int
    let fraction: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(AppTheme.Font.body(14))
                Spacer()
                Text("\(minutes) / \(target) min")
                    .font(AppTheme.Font.caption(12))
                    .foregroundColor(fraction >= 1 ? .green : fraction >= 0.5 ? .orange : .red)
            }
            NormProgressBar(fraction: fraction,
                            color: fraction >= 1 ? .green : fraction >= 0.5 ? .orange : .red)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .padding(.horizontal, AppTheme.Spacing.s)
    }
}

// MARK: - Completion ring

private struct CompletionRingSection: View {
    let fraction: Double
    let isNormBased: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.l) {
            ZStack {
                Circle()
                    .stroke(Color(UIColor.tertiarySystemBackground), lineWidth: 10)
                    .frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        fraction >= 0.8 ? Color.green : AppTheme.primaryFallback,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 90, height: 90)
                    .animation(.easeInOut(duration: 0.8), value: fraction)
                VStack(spacing: 2) {
                    Text("\(Int(fraction * 100))%")
                        .font(AppTheme.Font.title(18))
                    Text(isNormBased ? "targets" : "done")
                        .font(AppTheme.Font.caption(11))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Text(isNormBased ? "Daily targets" : "Activities")
                    .font(AppTheme.Font.title(14))
                Text(fraction >= 1.0
                     ? "All targets met! 🎉"
                     : fraction >= 0.5
                        ? "Making good progress"
                        : "More activities needed")
                    .font(AppTheme.Font.body(13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
    }
}

// MARK: - Reusable sub-components

struct SummarySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text(title)
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
            VStack(spacing: 0) {
                content()
            }
            .padding(AppTheme.Spacing.s)
            .cardStyle()
        }
    }
}

struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(icon).font(.system(size: 16))
            Text(label).font(AppTheme.Font.body(14))
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(AppTheme.Font.body(14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .padding(.horizontal, AppTheme.Spacing.s)
    }
}

#Preview {
    NavigationStack {
        DailySummaryView()
            .environmentObject(AppState())
            .environmentObject(AppRouter())
    }
}
