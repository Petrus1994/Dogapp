import SwiftUI

struct DailyRoutineSection: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        guard let routine = appState.dailyRoutine else { return AnyView(EmptyView()) }
        return AnyView(content(routine: routine))
    }

    @ViewBuilder
    private func content(routine: DailyRoutine) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {

            // Header
            HStack {
                Text("Daily Routine")
                    .font(AppTheme.Font.title())
                Spacer()
                Text("\(routine.completedCount)/\(routine.totalCount) done")
                    .font(AppTheme.Font.caption())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            // Current phase highlight
            if let current = routine.currentCycle {
                CurrentCycleCard(cycle: current) {
                    handleTap(cycle: current)
                } onSkip: {
                    appState.skipRoutineCycle(current.id)
                }
                .padding(.horizontal, AppTheme.Spacing.l)
            } else if routine.completionFraction >= 1.0 {
                RoutineCompleteCard()
                    .padding(.horizontal, AppTheme.Spacing.l)
            }

            // Balance insight
            let balance = appState.activityBalance
            if let msg = balance.coachingMessage {
                BalanceInsightBanner(message: msg, state: balance.overallBalance)
                    .padding(.horizontal, AppTheme.Spacing.l)
            }

            // Timeline scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.s) {
                    ForEach(routine.cycles) { cycle in
                        CycleTimelineChip(cycle: cycle) {
                            handleTap(cycle: cycle)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.vertical, AppTheme.Spacing.xs)
            }
        }
    }

    private func handleTap(cycle: RoutineCycle) {
        if let activityType = cycle.phase.linkedActivityType {
            // Log the linked activity
            router.startActivityLog(type: activityType)
        } else {
            // Mark sleep/toilet as done directly
            appState.completeRoutineCycle(cycle.id)
        }
    }
}

// MARK: - Current cycle card

private struct CurrentCycleCard: View {
    let cycle: RoutineCycle
    let onTap: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(spacing: AppTheme.Spacing.s) {
                ZStack {
                    Circle()
                        .fill(phaseColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Text(cycle.phase.icon)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Now")
                            .font(AppTheme.Font.caption(11))
                            .foregroundColor(phaseColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(phaseColor.opacity(0.1))
                            .cornerRadius(4)
                        Spacer()
                        Text(cycle.timeLabel)
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.secondary)
                    }

                    Text(cycle.phase.displayName)
                        .font(AppTheme.Font.title(16))

                    Text("\(cycle.expectedDurationMinutes) min · Cycle \(cycle.cycleNumber)")
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                }
            }

            if cycle.isPast {
                Text("⚠️ This was scheduled earlier — you can still complete it.")
                    .font(AppTheme.Font.caption(12))
                    .foregroundColor(.orange)
            }

            // Action row
            HStack(spacing: AppTheme.Spacing.s) {
                if cycle.phase.linkedActivityType != nil {
                    Button(action: onTap) {
                        Label("Log activity", systemImage: "plus")
                            .font(AppTheme.Font.body(14))
                            .foregroundColor(.white)
                            .padding(.vertical, AppTheme.Spacing.s)
                            .frame(maxWidth: .infinity)
                            .background(phaseColor)
                            .cornerRadius(AppTheme.Radius.s)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onTap) {
                        Label("Mark done", systemImage: "checkmark")
                            .font(AppTheme.Font.body(14))
                            .foregroundColor(.white)
                            .padding(.vertical, AppTheme.Spacing.s)
                            .frame(maxWidth: .infinity)
                            .background(phaseColor)
                            .cornerRadius(AppTheme.Radius.s)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onSkip) {
                    Text("Skip")
                        .font(AppTheme.Font.body(14))
                        .foregroundColor(.secondary)
                        .padding(.vertical, AppTheme.Spacing.s)
                        .frame(width: 64)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(AppTheme.Radius.s)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
    }

    private var phaseColor: Color {
        switch cycle.phase {
        case .sleep:    return .indigo
        case .toilet:   return .green
        case .physical: return AppTheme.primaryFallback
        case .mental:   return .purple
        case .feeding:  return .orange
        }
    }
}

// MARK: - Timeline chip (horizontal scroll)

private struct CycleTimelineChip: View {
    let cycle: RoutineCycle
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(chipBackground)
                        .frame(width: 36, height: 36)
                    if cycle.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else if cycle.skipped {
                        Image(systemName: "forward")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text(cycle.phase.icon)
                            .font(.system(size: 16))
                    }
                }

                Text(cycle.timeLabel)
                    .font(AppTheme.Font.caption(10))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .opacity(cycle.skipped ? 0.4 : 1.0)
    }

    private var chipBackground: Color {
        if cycle.isCompleted { return .green }
        if cycle.skipped     { return Color(UIColor.tertiarySystemBackground) }
        if cycle.isPast      { return .orange.opacity(0.3) }
        return phaseColor.opacity(0.15)
    }

    private var phaseColor: Color {
        switch cycle.phase {
        case .sleep:    return .indigo
        case .toilet:   return .green
        case .physical: return AppTheme.primaryFallback
        case .mental:   return .purple
        case .feeding:  return .orange
        }
    }
}

// MARK: - Routine complete

private struct RoutineCompleteCard: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Text("🎉").font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("Routine complete!")
                    .font(AppTheme.Font.title(15))
                Text("Your dog had a full, structured day. Excellent work.")
                    .font(AppTheme.Font.caption(13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.m)
        .background(Color.green.opacity(0.08))
        .cornerRadius(AppTheme.Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Balance insight banner

private struct BalanceInsightBanner: View {
    let message: String
    let state: ActivityBalanceService.BalanceReport.BalanceState

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
                .padding(.top, 1)
            Text(message)
                .font(AppTheme.Font.caption(13))
                .foregroundColor(.primary)
                .lineSpacing(2)
        }
        .padding(AppTheme.Spacing.m)
        .background(color.opacity(0.07))
        .cornerRadius(AppTheme.Radius.s)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private var icon: String {
        switch state {
        case .overtrained: return "exclamationmark.triangle"
        case .bothLow:     return "arrow.up.and.down"
        default:           return "lightbulb"
        }
    }

    private var color: Color {
        switch state {
        case .balanced:    return AppTheme.primaryFallback
        case .overtrained: return .red
        default:           return .orange
        }
    }
}

#Preview {
    let appState = AppState()
    let router   = AppRouter()

    return ScrollView {
        DailyRoutineSection()
            .environmentObject(appState)
            .environmentObject(router)
    }
}
