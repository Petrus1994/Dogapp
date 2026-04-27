import SwiftUI

// MARK: - TodayView (simplified assistant UI)

struct TodayView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @StateObject private var vm = TodayViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {

                // ── HEADER ─────────────────────────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.buildGreeting(userName: appState.currentUser?.email))
                            .font(AppTheme.Font.body(15))
                            .foregroundColor(.secondary)
                        ModePill(isFutureDogMode: appState.isFutureDogMode,
                                 dogName: appState.dogProfile?.name ?? appState.futureDogProfile?.preferredBreed)
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

                // ── REFERRAL PROMPT ────────────────────────────────────
                if appState.showReferralPrompt {
                    ReferralPromptCard(trigger: .afterSuccess) {
                        appState.showReferralPrompt = false
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                } else if appState.referralInfo?.successfulReferrals == 0 && appState.userProgress.totalPoints > 20 {
                    ReferralPromptCard(trigger: .afterInsight)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // ── DAILY ACTIVITIES ───────────────────────────────────
                if appState.dogProfile != nil {
                    ActivitySectionView()
                }


                // ── ANTI-CHEAT ─────────────────────────────────────────
                if let message = appState.antiCheatMessage {
                    AntiCheatBanner(message: message)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // ── FULL-DAY CELEBRATION ───────────────────────────────
                if appState.completedFullDayToday {
                    FullDayCelebrationCard()
                        .padding(.horizontal, AppTheme.Spacing.l)
                } else if appState.hasTodayActivityData, appState.dogProfile != nil {
                    RemainingActivityHint()
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
        .background(AppTheme.appBackground.ignoresSafeArea())
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
        // Voice quick log sheet
        .sheet(isPresented: $router.showVoiceLog) {
            VoiceQuickLogView(isPresented: $router.showVoiceLog)
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
            break
        case .reviewTask(let id):
            router.navigateToday(to: .taskDetail(id))
        case .balanced:
            router.navigateToday(to: .dailySummary)
        }
    }
}

// MARK: - Dog Avatar Hero

private struct DogAvatarHero: View {
    let dog: DogProfile
    let dogState: DogState
    let activities: [DailyActivity]

    @State private var selectedMetric: DogState.Metric? = nil
    @State private var showStateExplanation = false

    private var avatarState: DogAvatarState { DogAvatarState.from(dogState) }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            // Avatar centered — warm circular background, tappable for state explanation
            HStack {
                Spacer()
                Button {
                    showStateExplanation = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.warmSubtleGradient)
                            .frame(width: 152, height: 152)
                            .shadow(color: Color(hex: "#FF9500").opacity(0.12), radius: 16, x: 0, y: 6)
                        AvatarStateMachineView(profile: dog, avatarState: avatarState, size: 120)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .sheet(isPresented: $showStateExplanation) {
                AvatarStateExplanationSheet(
                    profile: dog,
                    avatarState: avatarState,
                    stateReason: nil,
                    recommendedAction: nil
                )
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

            // 4-metric grid: Nutrition · Activity · Training · Bond
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppTheme.Spacing.s
            ) {
                ForEach(dogState.displayMetrics, id: \.label) { metric in
                    metricCell(metric: metric)
                }
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
        }
        .sheet(item: $selectedMetric) { metric in
            MetricExplanationSheet(metric: metric)
                .presentationDetents([.medium])
        }
    }

    private func metricCell(metric: DogState.Metric) -> some View {
        Button { selectedMetric = metric } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(metric.icon).font(.system(size: 13))
                    Text(metric.label)
                        .font(AppTheme.Font.caption(11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(metric.value * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(metricColor(metric.value))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.progressTrack)
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(metricColor(metric.value))
                            .frame(width: geo.size.width * min(metric.value, 1.0), height: 5)
                            .animation(.easeInOut(duration: 0.5), value: metric.value)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.s)
            .background(metricColor(metric.value).opacity(0.05))
            .cornerRadius(AppTheme.Radius.s)
        }
        .buttonStyle(.plain)
    }

    private func metricColor(_ value: Double) -> Color {
        value >= 0.65 ? .green : (value >= 0.4 ? .orange : .red)
    }
}

// MARK: - DogState.Metric identifiable for sheet

extension DogState.Metric: Identifiable {
    public var id: String { label }
}

// MARK: - MetricExplanationSheet

private struct MetricExplanationSheet: View {
    let metric: DogState.Metric

    private var color: Color {
        metric.value >= 0.65 ? .green : (metric.value >= 0.4 ? .orange : .red)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
            // Header
            HStack(spacing: AppTheme.Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                        .fill(color.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Text(metric.icon).font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.label).font(AppTheme.Font.headline(18))
                    Text("\(Int(metric.value * 100))%")
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(color)
                        .fontWeight(.semibold)
                }
                Spacer()
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.progressTrack)
                        .frame(width: 80, height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 80 * min(metric.value, 1.0), height: 8)
                }
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Label("What this means", systemImage: "info.circle")
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(.secondary)
                Text(metric.explanation)
                    .font(AppTheme.Font.body(15))
                    .lineSpacing(4)
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Label("What to do", systemImage: "lightbulb.fill")
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(.orange)
                Text(metric.recommendation)
                    .font(AppTheme.Font.body(15))
                    .lineSpacing(4)
            }
            .padding(AppTheme.Spacing.m)
            .background(Color.orange.opacity(0.06))
            .cornerRadius(AppTheme.Radius.m)

            Spacer()
        }
        .padding(AppTheme.Spacing.l)
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

            if expanded && !action.rationale.isEmpty {
                Text(action.rationale)
                    .font(AppTheme.Font.body(14))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

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
        .background(isDuringRest ? AppTheme.progressTrack : AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.s)
        .opacity(isDuringRest ? 0.7 : 1.0)
    }
}

// MARK: - Mini action button (quick access row)

// MARK: - Mode Pill

private struct ModePill: View {
    let isFutureDogMode: Bool
    let dogName: String?

    var body: some View {
        guard let name = dogName else { return AnyView(EmptyView()) }
        let text = isFutureDogMode ? "Future Dog Mode — \(name)" : "Real Dog Mode — \(name)"
        let color: Color = isFutureDogMode ? .purple : AppTheme.primaryFallback
        return AnyView(
            HStack(spacing: 5) {
                Text(isFutureDogMode ? "🔮" : "🐕").font(.system(size: 10))
                Text(text)
                    .font(AppTheme.Font.caption(11))
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.09))
            .cornerRadius(12)
        )
    }
}

// MARK: - Mini Action Button (kept for backward compat, no longer rendered in Today)

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
                .background(AppTheme.cardBackground)
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
        NavigationLink(destination: WeeklySummaryView()) {
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
                Text("You logged all 4 activities today — great consistency!").font(AppTheme.Font.caption(13)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.m)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(AppTheme.Radius.m)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.m).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Remaining Activity Hint

struct RemainingActivityHint: View {
    @EnvironmentObject var appState: AppState

    private var incompleteNames: [String] {
        guard let norms = appState.activityNorms else {
            return DailyActivity.ActivityType.allCases
                .filter { type in !appState.todayActivities.contains { $0.type == type && $0.completed } }
                .map { $0.displayName }
        }
        var names: [String] = []
        let acts = appState.todayActivities
        if NormCalculationService.feedingCompletion(activities: acts, norms: norms) < 1.0 { names.append("Feeding") }
        if NormCalculationService.walkCompletion(activities: acts, norms: norms)    < 1.0 { names.append("Walk") }
        if NormCalculationService.playCompletion(activities: acts, norms: norms)    < 1.0 { names.append("Play") }
        if NormCalculationService.trainingCompletion(activities: acts, norms: norms) < 1.0 { names.append("Training") }
        return names
    }

    var body: some View {
        let names = incompleteNames
        guard !names.isEmpty else { return AnyView(EmptyView()) }
        let label = names.count == 1
            ? "\(names[0]) still needed today"
            : "\(names.joined(separator: ", ")) still needed today"
        return AnyView(
            HStack(spacing: AppTheme.Spacing.s) {
                Image(systemName: "checkmark.circle").foregroundColor(.secondary).font(.system(size: 13))
                Text(label)
                    .font(AppTheme.Font.caption(13))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(AppTheme.Spacing.m)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.Radius.m)
        )
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
        .background(AppTheme.cardBackground)
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
