import SwiftUI

struct ActivitySectionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                Text("Daily Activities")
                    .font(AppTheme.Font.title())
                Spacer()
                Text(completionText)
                    .font(AppTheme.Font.caption())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppTheme.Spacing.s
            ) {
                ForEach(DailyActivity.ActivityType.allCases, id: \.self) { type in
                    ActivityCard(
                        type: type,
                        activities: activities(for: type),
                        norms: appState.activityNorms
                    ) {
                        router.startActivityLog(type: type)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    private var completionText: String {
        if let norms = appState.activityNorms {
            let pct = Int(NormCalculationService.overallCompletion(
                activities: appState.todayActivities, norms: norms) * 100)
            return "\(pct)% of daily targets"
        }
        let done = DailyActivity.ActivityType.allCases.filter { activities(for: $0).last != nil }.count
        return "\(done)/\(DailyActivity.ActivityType.allCases.count) done"
    }

    private func activities(for type: DailyActivity.ActivityType) -> [DailyActivity] {
        appState.todayActivities.filter { $0.type == type && $0.completed }
    }
}

struct ActivityCard: View {
    let type: DailyActivity.ActivityType
    let activities: [DailyActivity]
    let norms: ActivityNorms?
    let onTap: () -> Void

    private var latestActivity: DailyActivity? { activities.last }
    private var isLogged: Bool { !activities.isEmpty }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                HStack {
                    Text(type.icon).font(.system(size: 22))
                    Spacer()
                    if isLogged {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(normFractionColor)
                            .font(.system(size: 16))
                    } else {
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppTheme.primaryFallback)
                            .font(.system(size: 16))
                    }
                }

                Text(type.displayName)
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(.primary)

                if let activity = latestActivity {
                    primaryValueLabel(for: activity)
                    secondaryLabel(for: activity)
                } else {
                    normHintLabel
                }

                // Norm progress bar
                if let fraction = normFraction {
                    NormProgressBar(fraction: fraction, color: normFractionColor)
                        .padding(.top, 2)
                }
            }
            .padding(AppTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                    .fill(isLogged
                          ? normFractionColor.opacity(0.06)
                          : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                            .stroke(isLogged ? normFractionColor.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Labels

    @ViewBuilder
    private func primaryValueLabel(for activity: DailyActivity) -> some View {
        switch type {
        case .feeding:
            Text("\(activities.count)x fed · \(activity.foodType?.displayName ?? "—")")
                .font(AppTheme.Font.caption(12))
                .foregroundColor(.green)
        case .walking:
            HStack(spacing: 4) {
                Text("\(activity.durationMinutes) min")
                if let km = activity.distanceKm {
                    Text("· \(String(format: "%.1f", km)) km")
                }
            }
            .font(AppTheme.Font.caption(12))
            .foregroundColor(.green)
        case .playing:
            Text("\(activity.durationMinutes) min · \(activity.playActivity?.displayName ?? "play")")
                .font(AppTheme.Font.caption(12))
                .foregroundColor(.green)
                .lineLimit(1)
        case .training:
            Text("\(activity.durationMinutes) min")
                .font(AppTheme.Font.caption(12))
                .foregroundColor(.green)
        }
    }

    @ViewBuilder
    private func secondaryLabel(for activity: DailyActivity) -> some View {
        switch type {
        case .walking:
            if let quality = activity.walkQuality {
                Text(quality.icon + " " + quality.displayName)
                    .font(AppTheme.Font.caption(11))
                    .foregroundColor(.secondary)
            }
        case .feeding:
            if let n = norms {
                Text("\(activities.count)/\(n.feedingsPerDay) feedings")
                    .font(AppTheme.Font.caption(11))
                    .foregroundColor(.secondary)
            }
        default:
            EmptyView()
        }
    }

    private var normHintLabel: some View {
        Group {
            if let hint = normHint {
                Text(hint)
                    .font(AppTheme.Font.caption(11))
                    .foregroundColor(.secondary)
            } else {
                Text("Tap to log")
                    .font(AppTheme.Font.caption(12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var normHint: String? {
        guard let norms else { return nil }
        switch type {
        case .walking:  return "Target: \(norms.walkMinPerDay) min"
        case .playing:  return "Target: \(norms.playMinPerDay) min"
        case .feeding:  return "\(norms.feedingsPerDay)x per day"
        case .training: return "≤\(norms.trainingMinPerSession) min/session"
        }
    }

    // MARK: - Norm fraction

    private var normFraction: Double? {
        guard let norms else { return nil }
        switch type {
        case .walking:  return NormCalculationService.walkCompletion(activities: activities, norms: norms)
        case .playing:  return NormCalculationService.playCompletion(activities: activities, norms: norms)
        case .feeding:  return NormCalculationService.feedingCompletion(activities: activities, norms: norms)
        case .training: return NormCalculationService.trainingCompletion(activities: activities, norms: norms)
        }
    }

    private var normFractionColor: Color {
        guard let f = normFraction else { return .green }
        if f >= 1.0 { return .green }
        if f >= 0.5 { return .orange }
        return isLogged ? .orange : .clear
    }
}

// MARK: - Norm progress bar

struct NormProgressBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(fraction, 1.0), height: 4)
                    .animation(.easeInOut(duration: 0.4), value: fraction)
            }
        }
        .frame(height: 4)
    }
}

#Preview {
    ActivitySectionView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
