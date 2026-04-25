import SwiftUI

// MARK: - Weekly Summary Model

private struct WeeklySummaryData {
    struct DaySlot: Identifiable {
        let id: Int  // 0 = 6 days ago … 6 = today
        let date: Date
        let logged: Set<DailyActivity.ActivityType>

        var shortLabel: String {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEE"
            return String(fmt.string(from: date).prefix(2))
        }
        var isToday: Bool { Calendar.current.isDateInToday(date) }
    }

    let days: [DaySlot]
    let totalWalkMin: Int
    let totalPlayMin: Int
    let totalTrainingSessions: Int
    let totalFeedings: Int
    let toughEventCount: Int
    let issueFreeDays: Int

    static func compute(activities: [DailyActivity], events: [BehaviorEvent]) -> WeeklySummaryData {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let days: [DaySlot] = (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let logged = Set(activities.filter {
                cal.isDate($0.date, inSameDayAs: date) && $0.completed
            }.map { $0.type })
            return DaySlot(id: 6 - offset, date: date, logged: logged)
        }

        let walkMin  = activities.filter { $0.type == .walking }.reduce(0) { $0 + $1.durationMinutes }
        let playMin  = activities.filter { $0.type == .playing }.reduce(0) { $0 + $1.durationMinutes }
        let training = activities.filter { $0.type == .training }.count
        let feedings = activities.filter { $0.type == .feeding }.count
        let tough    = events.filter { $0.hasRealIssues }.count

        var issueFreeDays = 0
        for slot in days {
            let dayEvents = events.filter { cal.isDate($0.date, inSameDayAs: slot.date) }
            if dayEvents.allSatisfy({ !$0.hasRealIssues }) {
                issueFreeDays += 1
            }
        }

        return WeeklySummaryData(
            days: days,
            totalWalkMin: walkMin,
            totalPlayMin: playMin,
            totalTrainingSessions: training,
            totalFeedings: feedings,
            toughEventCount: tough,
            issueFreeDays: issueFreeDays
        )
    }
}

// MARK: - View

struct WeeklySummaryView: View {
    @EnvironmentObject var appState: AppState

    private var summary: WeeklySummaryData {
        WeeklySummaryData.compute(
            activities: appState.weeklyActivities,
            events: appState.weeklyBehaviorEvents
        )
    }

    private var dogName: String { appState.dogProfile?.name ?? "your dog" }

    private var weekLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        return "\(fmt.string(from: start)) – \(fmt.string(from: Date()))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {

                // Header
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("Week of \(weekLabel)")
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(.secondary)
                    Text("\(dogName)'s Weekly Review")
                        .font(AppTheme.Font.headline(22))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.Spacing.m)
                .padding(.horizontal, AppTheme.Spacing.l)

                // 7-day activity grid
                activityGrid

                // Stats row
                statsRow

                // Behavior trends
                behaviorTrendsCard

                // Streak & shields
                streakCard

                // Empathy note if needed
                if let msg = appState.empathyMessage {
                    EmpathyBanner(message: msg)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                Spacer(minLength: AppTheme.Spacing.xl)
            }
        }
        .navigationTitle("Weekly Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Activity Grid

    private var activityGrid: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Daily Activity")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            VStack(spacing: 0) {
                // Day headers
                HStack(spacing: 0) {
                    Text("").frame(width: 72, alignment: .leading)
                    ForEach(summary.days) { day in
                        VStack(spacing: 2) {
                            Text(day.shortLabel)
                                .font(AppTheme.Font.caption(10))
                                .foregroundColor(day.isToday ? AppTheme.primaryFallback : .secondary)
                                .fontWeight(day.isToday ? .semibold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.bottom, AppTheme.Spacing.xs)

                Divider().padding(.horizontal, AppTheme.Spacing.l)

                // One row per activity type
                ForEach(DailyActivity.ActivityType.allCases, id: \.self) { type in
                    HStack(spacing: 0) {
                        HStack(spacing: 4) {
                            Text(type.icon).font(.system(size: 12))
                            Text(type.displayName)
                                .font(AppTheme.Font.caption(11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 72, alignment: .leading)

                        ForEach(summary.days) { day in
                            ZStack {
                                Circle()
                                    .fill(day.logged.contains(type)
                                          ? AppTheme.primaryFallback.opacity(0.18)
                                          : Color(UIColor.tertiarySystemBackground))
                                    .frame(width: 24, height: 24)
                                if day.logged.contains(type) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(AppTheme.primaryFallback)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, AppTheme.Spacing.l)
                }
            }
            .cardStyle()
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("This Week")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.s) {
                statTile(value: "\(summary.totalWalkMin) min", label: "Total walking", icon: "🦮", color: .blue)
                statTile(value: "\(summary.totalPlayMin) min", label: "Total play", icon: "🎾", color: .green)
                statTile(value: "\(summary.totalTrainingSessions)", label: "Training sessions", icon: "🎯", color: .purple)
                statTile(value: "\(summary.issueFreeDays)/7", label: "Issue-free days", icon: "✅", color: .orange)
            }
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(icon).font(.system(size: 20))
            Text(value)
                .font(AppTheme.Font.headline(20))
                .foregroundColor(color)
            Text(label)
                .font(AppTheme.Font.caption(12))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.m)
        .cardStyle()
    }

    // MARK: - Behavior Trends

    private var behaviorTrendsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Behavior Trends")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            VStack(spacing: AppTheme.Spacing.s) {
                ForEach(BehaviorDimension.allCases, id: \.rawValue) { dim in
                    let score = appState.behaviorProgress[dim]
                    let weekStart = score.history.dropLast(min(7, score.history.count)).last?.score
                    BehaviorTrendRow(score: score, weekStartScore: weekStart)
                }
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let progress = appState.userProgress
        return HStack(spacing: AppTheme.Spacing.l) {
            VStack(spacing: 4) {
                Text("🔥").font(.system(size: 28))
                Text("\(progress.currentStreak)").font(AppTheme.Font.headline(24)).foregroundColor(.orange)
                Text("day streak").font(AppTheme.Font.caption(11)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 48)

            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Text(i < progress.streakShields ? "🛡️" : "○")
                            .font(.system(size: i < progress.streakShields ? 18 : 14))
                            .foregroundColor(i < progress.streakShields ? .primary : Color(UIColor.tertiaryLabel))
                    }
                }
                Text("\(progress.streakShields)/3 shields").font(AppTheme.Font.caption(11)).foregroundColor(.secondary)
                Text("banked").font(AppTheme.Font.caption(10)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 48)

            VStack(spacing: 4) {
                Text(progress.level.icon).font(.system(size: 28))
                Text("\(progress.totalPoints)").font(AppTheme.Font.headline(24)).foregroundColor(AppTheme.primaryFallback)
                Text("points").font(AppTheme.Font.caption(11)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
        .padding(.horizontal, AppTheme.Spacing.l)
    }
}

// MARK: - Behavior Trend Row

private struct BehaviorTrendRow: View {
    let score: BehaviorDimensionScore
    let weekStartScore: Double?

    private var delta: Double? {
        weekStartScore.map { score.score - $0 }
    }

    private var deltaLabel: String {
        guard let d = delta else { return "—" }
        let prefix = d >= 0 ? "+" : ""
        return "\(prefix)\(Int(d))"
    }

    private var deltaColor: Color {
        guard let d = delta else { return .secondary }
        if d > 1 { return .green }
        if d < -1 { return .red }
        return .secondary
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Text(score.dimension.icon).font(.system(size: 18)).frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(score.dimension.displayName)
                    .font(AppTheme.Font.body(13))
                Text(score.scoreLabel)
                    .font(AppTheme.Font.caption(11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(score.trend.icon + " \(Int(score.score))")
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(trendColor)
                Text(deltaLabel)
                    .font(AppTheme.Font.caption(11))
                    .foregroundColor(deltaColor)
            }
        }
    }

    private var trendColor: Color {
        switch score.trend {
        case .improving:      return .green
        case .stable:         return .secondary
        case .needsAttention: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        WeeklySummaryView()
            .environmentObject(AppState())
    }
}
