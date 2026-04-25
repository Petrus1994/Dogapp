import SwiftUI

// MARK: - TodayView (simplified assistant UI)

struct TodayView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @StateObject private var vm = TodayViewModel()

    @AppStorage("today_tasks_expanded") private var showTasks = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {

                // ── HEADER ─────────────────────────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.buildGreeting(userName: appState.currentUser?.email))
                            .font(AppTheme.Font.body(15))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    CompactBadges(progress: appState.userProgress)
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.top, AppTheme.Spacing.m)

                // ── DOG AVATAR HERO (dog users only) ──────────────────
                if let dog = appState.dogProfile {
                    let ctx = appState.currentContext
                    DogAvatarHero(
                        dog: dog,
                        dogState: appState.dogState,
                        activities: appState.todayActivities
                    )
                    .padding(.horizontal, AppTheme.Spacing.l)

                    // ── CURRENT ACTION CARD ───────────────────────────
                    CurrentActionCard(
                        action: ctx.primaryAction,
                        urgency: ctx.urgency,
                        isResting: ctx.isResting
                    ) {
                        handleActionCTA(ctx.primaryAction)
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)

                    // ── NEXT ACTION PILL ──────────────────────────────
                    if let next = ctx.nextAction {
                        NextActionPill(action: next, isDuringRest: ctx.isResting)
                            .padding(.horizontal, AppTheme.Spacing.l)
                    }
                }

                // ── AGE PROGRESSION BANNER ─────────────────────────────
                if let announcement = appState.ageProgressionAnnouncement {
                    AgeProgressionBanner(message: announcement) {
                        appState.ageProgressionAnnouncement = nil
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                }

                // ── PROGRESS INSIGHT ───────────────────────────────────
                if let insight = appState.progressInsight {
                    ProgressInsightBanner(insight: insight)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // ── EMPATHY BANNER ─────────────────────────────────────
                if let msg = appState.empathyMessage {
                    EmpathyBanner(message: msg)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // ── QUICK ACCESS ROW ───────────────────────────────────
                HStack(spacing: AppTheme.Spacing.s) {
                    MiniActionButton(icon: "bubble.left.fill", label: "AI Coach") {
                        router.showChat()
                    }
                    MiniActionButton(icon: "list.bullet.clipboard", label: "Full Plan") {
                        router.selectedTab = .plan
                    }
                    MiniActionButton(icon: "chart.line.uptrend.xyaxis", label: "Progress") {
                        router.navigateToday(to: .behaviorProgress)
                    }
                    MiniActionButton(icon: "calendar.badge.clock", label: "This Week") {
                        router.navigateToday(to: .weeklySummary)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)

                // ── ANTI-CHEAT ─────────────────────────────────────────
                if let message = appState.antiCheatMessage {
                    AntiCheatBanner(message: message)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // ── FULL-DAY CELEBRATION ───────────────────────────────
                if appState.completedFullDayToday {
                    FullDayCelebrationCard()
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // ── DAILY ACTIVITIES ───────────────────────────────────
                if appState.dogProfile != nil {
                    ActivitySectionView()
                }

                // ── COLLAPSIBLE: TRAINING TASKS ───────────────────────
                if appState.currentPlan != nil {
                    CollapsibleSection(
                        title: trainingTasksTitle,
                        isExpanded: $showTasks
                    ) {
                        taskList
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                }

                // ── NO DOG — plan intro ────────────────────────────────
                if appState.dogProfile == nil {
                    if let plan = appState.currentPlan, plan.tasks.allSatisfy({ $0.status == .pending }) {
                        PlanIntroCard(plan: plan)
                            .padding(.horizontal, AppTheme.Spacing.l)
                    }
                }

                // Tips (collapsible if there are tasks to avoid clutter)
                if let tips = appState.currentPlan?.tips, !tips.isEmpty, appState.dogProfile == nil {
                    TipsSection(tips: tips)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                Spacer(minLength: AppTheme.Spacing.xl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            if let msg = router.toastMessage {
                ToastBanner(message: msg)
                    .padding(.top, AppTheme.Spacing.s)
                    .padding(.horizontal, AppTheme.Spacing.l)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: router.toastMessage)
        .onChange(of: router.toastMessage) { _, new in
            guard new != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { router.toastMessage = nil }
            }
        }
        // Quick log sheet (from CurrentActionCard CTA)
        .sheet(isPresented: $router.showQuickLog) {
            if let type = router.quickLogType {
                QuickLogSheet(
                    isPresented: $router.showQuickLog,
                    activityType: type,
                    linkedTaskId: router.quickLogLinkedTaskId
                )
            }
        }
        // Full activity log (from "Add full details")
        .sheet(isPresented: $router.showActivityLog) {
            if let type = router.activityToLog {
                ActivityLogSheet(activityType: type, isPresented: $router.showActivityLog)
            }
        }
        // Behavior issue sheet
        .sheet(isPresented: $router.showBehaviorIssue) {
            if let activity = router.pendingActivityForBehavior {
                BehaviorIssueSheet(isPresented: $router.showBehaviorIssue, activity: activity)
            }
        }
        // Toilet log sheet
        .sheet(isPresented: $router.showToiletLog) {
            ToiletEventSheet(isPresented: $router.showToiletLog)
        }
    }

    // MARK: - CTA handler

    private func handleActionCTA(_ action: ContextEngine.Action) {
        switch action.type {
        case .toilet:
            router.showToiletLog = true
        case .activity(let type):
            router.startQuickLog(type: type)
        case .rest:
            break // no log needed
        case .reviewTask(let id):
            router.navigateToday(to: .taskDetail(id))
        case .balanced:
            router.navigateToday(to: .dailySummary)
        }
    }

    // MARK: - Section titles

    private var trainingTasksTitle: String {
        let pending = appState.currentPlan?.todaysTasks.filter { $0.status == .pending }.count ?? 0
        return pending == 0 ? "Training tasks ✓" : "Training tasks (\(pending) pending)"
    }

    // MARK: - Task list (inside collapsible)

    @ViewBuilder
    private var taskList: some View {
        if let tasks = appState.currentPlan?.todaysTasks, !tasks.isEmpty {
            VStack(spacing: AppTheme.Spacing.xs) {
                ForEach(tasks) { task in
                    TaskCard(task: task) {
                        router.navigateToday(to: .taskDetail(task.id))
                    }
                }
            }
        } else if let completed = appState.currentPlan?.completedTasks, !completed.isEmpty {
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("All done for today ✓")
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.m)
            }
        }
        // Completed tasks
        if let completed = appState.currentPlan?.completedTasks, !completed.isEmpty {
            DisclosureGroup {
                ForEach(completed) { task in
                    TaskCard(task: task) {
                        router.navigateToday(to: .taskDetail(task.id))
                    }
                }
            } label: {
                Text("Done today (\(completed.count))")
                    .font(AppTheme.Font.caption(13))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Dog Avatar Hero

private struct DogAvatarHero: View {
    let dog: DogProfile
    let dogState: DogState
    let activities: [DailyActivity]

    @State private var selectedExplanation: StateExplanation? = nil
    @State private var showSecondaryStats = false

    private var avatarState: DogAvatarState { DogAvatarState.from(dogState) }

    private var explanations: [StateExplanation] {
        StateExplanation.explanations(for: dogState, dogName: dog.name, activities: activities)
    }

    private func explanation(for param: StateExplanation.Parameter) -> StateExplanation? {
        explanations.first { $0.parameter == param }
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            // Avatar centered
            HStack {
                Spacer()
                DogAvatarView(avatarState: avatarState, coatColor: dog.coatColor, size: 120)
                Spacer()
            }

            // Name + state label
            HStack(spacing: 6) {
                Text(dog.name)
                    .font(AppTheme.Font.headline(20))
                Text("·")
                    .foregroundColor(.secondary)
                Text(avatarState.label)
                    .font(AppTheme.Font.body(15))
                    .foregroundColor(.secondary)
            }

            // Primary stats: Energy, Hunger, Happiness
            VStack(spacing: AppTheme.Spacing.s) {
                HStack(spacing: AppTheme.Spacing.s) {
                    statCell(param: .energy,    value: dogState.energyLevel)
                    statCell(param: .hunger,    value: dogState.hungerLevel)
                    statCell(param: .happiness, value: dogState.satisfaction)
                }

                // Secondary stats (expandable)
                if showSecondaryStats {
                    HStack(spacing: AppTheme.Spacing.s) {
                        statCell(param: .calmness,   value: dogState.calmness)
                        statCell(param: .confidence, value: dogState.behaviorStability)
                        statCell(param: .engagement, value: dogState.focusOnOwner)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showSecondaryStats.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showSecondaryStats ? "Less" : "More stats")
                            .font(AppTheme.Font.caption(12))
                        Image(systemName: showSecondaryStats ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
        }
        .sheet(item: $selectedExplanation) { exp in
            StateExplanationSheet(explanation: exp)
                .presentationDetents([.medium])
        }
    }

    private func statCell(param: StateExplanation.Parameter, value: Double) -> some View {
        Button {
            selectedExplanation = explanation(for: param)
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    Text(param.icon).font(.system(size: 11))
                    Text(param.displayName)
                        .font(AppTheme.Font.caption(11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                StatBar(value: value, param: param)
                Text(valueLabel(value, param: param))
                    .font(AppTheme.Font.caption(10))
                    .foregroundColor(barColor(value, param: param))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func valueLabel(_ v: Double, param: StateExplanation.Parameter) -> String {
        if param == .hunger {
            switch v {
            case 0.8...: return "Hungry"
            case 0.5...: return "Peckish"
            default:     return "Fed"
            }
        }
        switch v {
        case 0.75...: return "High"
        case 0.5...:  return "Good"
        case 0.25...: return "Low"
        default:      return "Very low"
        }
    }

    private func barColor(_ v: Double, param: StateExplanation.Parameter) -> Color {
        let exp = StateExplanation(
            parameter: param, value: v, isNormal: true, cause: "", recommendation: ""
        )
        switch exp.severityColor {
        case .good:    return .green
        case .warning: return .orange
        case .bad:     return .red
        }
    }
}

private struct StatBar: View {
    let value: Double
    let param: StateExplanation.Parameter

    private var color: Color {
        let exp = StateExplanation(
            parameter: param, value: value, isNormal: true, cause: "", recommendation: ""
        )
        switch exp.severityColor {
        case .good:    return .green
        case .warning: return .orange
        case .bad:     return .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: geo.size.width * min(value, 1.0), height: 6)
                    .animation(.easeInOut(duration: 0.4), value: value)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - State Explanation Sheet

private struct StateExplanationSheet: View {
    let explanation: StateExplanation

    private var barColor: Color {
        switch explanation.severityColor {
        case .good:    return .green
        case .warning: return .orange
        case .bad:     return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
            // Header
            HStack(spacing: AppTheme.Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                        .fill(barColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Text(explanation.parameter.icon)
                        .font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(explanation.parameter.displayName)
                        .font(AppTheme.Font.headline(18))
                    Text(explanation.valueLabel)
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(barColor)
                        .fontWeight(.medium)
                }
                Spacer()
                // Mini bar
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(explanation.value * 100))%")
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(UIColor.tertiarySystemBackground))
                            .frame(width: 80, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor)
                            .frame(width: 80 * min(explanation.value, 1.0), height: 8)
                    }
                }
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()

            // Why
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Label("Why this value", systemImage: "info.circle")
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(.secondary)
                Text(explanation.cause)
                    .font(AppTheme.Font.body(15))
                    .lineSpacing(4)
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()

            // Recommendation
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Label("What to do", systemImage: "lightbulb.fill")
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(.orange)
                Text(explanation.recommendation)
                    .font(AppTheme.Font.body(15))
                    .lineSpacing(4)
            }
            .padding(AppTheme.Spacing.m)
            .background(Color.orange.opacity(0.06))
            .cornerRadius(AppTheme.Radius.m)

            Spacer()
        }
        .padding(AppTheme.Spacing.l)
        .navigationTitle(explanation.parameter.displayName)
    }
}

// MARK: - Current Action Card

private struct CurrentActionCard: View {
    let action: ContextEngine.Action
    let urgency: ContextEngine.CurrentContext.Urgency
    var isResting: Bool = false
    let onCTA: () -> Void

    @State private var expanded = false

    private var urgencyColor: Color {
        switch urgency {
        case .high:   return .orange
        case .normal: return AppTheme.primaryFallback
        case .low:    return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            // Action row
            HStack(spacing: AppTheme.Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                        .fill((isResting ? Color.secondary : urgencyColor).opacity(0.12))
                        .frame(width: 48, height: 48)
                    Text(action.icon)
                        .font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(AppTheme.Font.title(17))
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Text(action.subtitle)
                            .font(AppTheme.Font.caption(13))
                            .foregroundColor(.secondary)
                        // Timing badge
                        if let hint = action.timingHint {
                            Text(hint)
                                .font(AppTheme.Font.caption(11))
                                .foregroundColor(isResting ? .secondary : urgencyColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((isResting ? Color.secondary : urgencyColor).opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
                // Expand rationale toggle (only when rationale exists)
                if !action.rationale.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        Image(systemName: expanded ? "info.circle.fill" : "info.circle")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                    }
                }
            }

            // Methodology tip — always visible, 1 short line
            if let tip = action.methodologyTip {
                HStack(alignment: .top, spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 1)
                    Text(tip)
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
            }

            // Rationale (expanded, optional deep-dive)
            if expanded && !action.rationale.isEmpty {
                Text(action.rationale)
                    .font(AppTheme.Font.body(14))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // CTA — hidden during rest and for balanced / rest action types
            if !isResting && action.type != .rest && action.type != .balanced {
                Button(action: onCTA) {
                    Text(action.ctaLabel)
                        .font(AppTheme.Font.title(16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.m)
                        .background(urgencyColor)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.Radius.m)
                }
            } else if isResting || action.type == .rest {
                HStack(spacing: AppTheme.Spacing.s) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.secondary.opacity(0.7))
                        .font(.system(size: 13))
                    Text("No action needed — let them rest quietly")
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                .stroke(
                    urgency == .high && !isResting ? Color.orange.opacity(0.3) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Next Action Pill

private struct NextActionPill: View {
    let action: ContextEngine.Action
    var isDuringRest: Bool = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: isDuringRest ? "clock" : "arrow.right.circle")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(isDuringRest ? "Upcoming:" : "Next:")
                .font(AppTheme.Font.caption(13))
                .foregroundColor(.secondary)
            Text(action.title)
                .font(AppTheme.Font.caption(13))
                .foregroundColor(isDuringRest ? .secondary : .primary)
            if !action.subtitle.isEmpty {
                Text("· \(action.subtitle)")
                    .font(AppTheme.Font.caption(13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.s)
        .padding(.vertical, 6)
        .background(isDuringRest
            ? Color(UIColor.tertiarySystemBackground)
            : Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppTheme.Radius.s)
        .opacity(isDuringRest ? 0.7 : 1.0)
    }
}

// MARK: - Mini action button (quick access row)

private struct MiniActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.primaryFallback)
                Text(label)
                    .font(AppTheme.Font.caption(11))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.m)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsible section

private struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(AppTheme.Font.title(14))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(AppTheme.Spacing.m)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(AppTheme.Radius.m)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Compact streak + level badges (header corner)

struct CompactBadges: View {
    let progress: UserProgress

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            // Streak shields
            if progress.streakShields > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<progress.streakShields, id: \.self) { _ in
                        Text("🛡️").font(.system(size: 11))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.s)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(AppTheme.Radius.s)
            }

            if progress.currentStreak > 0 {
                HStack(spacing: 4) {
                    Text("🔥").font(.system(size: 13))
                    Text("\(progress.currentStreak)d")
                        .font(AppTheme.Font.caption(12))
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, AppTheme.Spacing.s)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(AppTheme.Radius.s)
            }
            HStack(spacing: 4) {
                Text(progress.level.icon).font(.system(size: 13))
                Text("\(progress.totalPoints)pts")
                    .font(AppTheme.Font.caption(12))
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, AppTheme.Spacing.s)
            .padding(.vertical, 4)
            .background(AppTheme.primaryFallback.opacity(0.1))
            .cornerRadius(AppTheme.Radius.s)
        }
    }
}

// MARK: - Kept components (used by this and other views)

struct StreakLevelBadge: View {
    let progress: UserProgress
    var hasDog: Bool = true

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            if progress.currentStreak > 0 {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Text("🔥").font(.system(size: 16))
                    Text("\(progress.currentStreak) day streak").font(AppTheme.Font.title(13))
                }
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.vertical, AppTheme.Spacing.s)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(AppTheme.Radius.m)
            }
            HStack(spacing: AppTheme.Spacing.xs) {
                Text(progress.level.icon).font(.system(size: 16))
                Text(progress.level.displayName).font(AppTheme.Font.title(13))
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .background(AppTheme.primaryFallback.opacity(0.1))
            .cornerRadius(AppTheme.Radius.m)
            Spacer()
        }
    }
}

struct EmpathyBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
            Text("💙").font(.system(size: 16))
            Text(message)
                .font(AppTheme.Font.body(14))
                .foregroundColor(.primary)
                .lineSpacing(3)
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.07))
        .cornerRadius(AppTheme.Radius.m)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.m).stroke(Color.blue.opacity(0.18), lineWidth: 1))
    }
}

struct AntiCheatBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
            Image(systemName: "lightbulb").foregroundColor(.orange).font(.system(size: 14)).padding(.top, 1)
            Text(message).font(AppTheme.Font.caption(13)).foregroundColor(.primary).lineSpacing(2)
        }
        .padding(AppTheme.Spacing.m)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(AppTheme.Radius.s)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.s).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }
}

struct AgeProgressionBanner: View {
    let message: String
    let onDismiss: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
            Text("🎂").font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text("Your dog grew up!").font(AppTheme.Font.title(14))
                Text(message).font(AppTheme.Font.caption(13)).foregroundColor(.secondary).lineSpacing(2)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
        .padding(AppTheme.Spacing.m)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(AppTheme.Radius.m)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.m).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
}

struct ProgressInsightBanner: View {
    let insight: String
    var body: some View {
        NavigationLink(destination: BehaviorProgressView()) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                Image(systemName: "sparkles").foregroundColor(.purple).font(.system(size: 13)).padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress Insight")
                        .font(AppTheme.Font.caption(11)).foregroundColor(.purple)
                        .fontWeight(.semibold).textCase(.uppercase).kerning(0.4)
                    Text(insight).font(AppTheme.Font.body(14)).foregroundColor(.primary).lineSpacing(2).lineLimit(3)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(AppTheme.Spacing.m)
            .background(Color.purple.opacity(0.07))
            .cornerRadius(AppTheme.Radius.m)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.m).stroke(Color.purple.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    var wide: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if wide {
                    HStack(spacing: AppTheme.Spacing.s) {
                        Image(systemName: icon).font(.system(size: 18)).foregroundColor(isDisabled ? .secondary : AppTheme.primaryFallback)
                        Text(label).font(AppTheme.Font.title(15)).foregroundColor(isDisabled ? .secondary : .primary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, AppTheme.Spacing.m)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: icon).font(.system(size: 16)).foregroundColor(isDisabled ? .secondary : AppTheme.primaryFallback)
                        Text(label).font(AppTheme.Font.caption(12)).foregroundColor(isDisabled ? .secondary : .primary).multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, AppTheme.Spacing.m)
                }
            }
            .cardStyle().opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain).disabled(isDisabled)
    }
}

struct PlanIntroCard: View {
    let plan: Plan
    private var dayCount: Int { Set(plan.tasks.map { $0.scheduledDay }).max() ?? 7 }
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                Text("📋").font(.system(size: 20))
                Text("Your \(dayCount)-Day Plan").font(AppTheme.Font.title(15))
                Spacer()
                Text(plan.type.displayName).font(AppTheme.Font.caption(12)).foregroundColor(.secondary)
            }
            Text(plan.goal).font(AppTheme.Font.body(14)).foregroundColor(.secondary).lineSpacing(2)
            Text("This week: \(plan.weeklyFocus)").font(AppTheme.Font.caption(13)).foregroundColor(AppTheme.primaryFallback)
        }
        .padding(AppTheme.Spacing.m).cardStyle()
    }
}

struct FullDayCelebrationCard: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Text("🏆").font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("Full day complete!").font(AppTheme.Font.title(15))
                Text("You logged all 4 activities. Bonus points earned.").font(AppTheme.Font.caption(13)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.m)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(AppTheme.Radius.m)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.m).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
    }
}

struct ToastBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(AppTheme.Font.body(14))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(AppTheme.Spacing.m)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppTheme.Radius.m)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

struct TipsSection: View {
    let tips: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Tips for Today").font(AppTheme.Font.title())
            ForEach(Array(tips.prefix(3).enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                    Text("💡").font(.system(size: 14)).padding(.top, 2)
                    Text(tip).font(AppTheme.Font.body(14)).foregroundColor(.secondary).lineSpacing(3)
                }
            }
        }
        .padding(AppTheme.Spacing.m).cardStyle()
    }
}

#Preview {
    NavigationStack {
        TodayView()
            .environmentObject({
                let s = AppState()
                s.currentPlan  = MockData.puppyPlan
                s.dogProfile   = DogProfile(id: "1", name: "Luna", gender: .female,
                    ageGroup: .twoTo3Months, breed: "Golden Retriever",
                    isBreedUnknown: false, size: nil, activityLevel: .medium,
                    issues: [.indoorAccidents], photoURL: nil)
                return s
            }())
            .environmentObject(AppRouter())
    }
}
