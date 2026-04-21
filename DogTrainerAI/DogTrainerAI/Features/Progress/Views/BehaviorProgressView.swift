import SwiftUI

struct BehaviorProgressView: View {
    @EnvironmentObject var appState: AppState
    @State private var showShareSheet = false
    @State private var expandedDimension: BehaviorDimension?

    private var dogName: String { appState.dogProfile?.name ?? "your dog" }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {

                // Insight of the day
                if let insight = appState.progressInsight {
                    InsightOfDayCard(insight: insight, dogName: dogName)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // Proactive pattern insight
                if let proactive = appState.proactiveProgressInsight {
                    ProactiveInsightCard(message: proactive)
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                // 4 dimension cards
                VStack(spacing: AppTheme.Spacing.m) {
                    ForEach(BehaviorDimension.allCases, id: \.rawValue) { dimension in
                        let score = appState.behaviorProgress[dimension]
                        DimensionProgressCard(
                            score: score,
                            dogName: dogName,
                            isExpanded: expandedDimension == dimension
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                expandedDimension = expandedDimension == dimension ? nil : dimension
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)

                // Share button
                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: AppTheme.Spacing.s) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share \(dogName)'s Progress")
                    }
                    .font(AppTheme.Font.title(15))
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.m)
                    .background(AppTheme.primaryFallback.opacity(0.1))
                    .foregroundColor(AppTheme.primaryFallback)
                    .cornerRadius(AppTheme.Radius.m)
                }
                .padding(.horizontal, AppTheme.Spacing.l)

                // Low data hint
                let hasData = appState.behaviorProgress.scores.filter { $0.confidence > 20 }.count
                if hasData < 2 {
                    LowDataHint()
                        .padding(.horizontal, AppTheme.Spacing.l)
                }

                Spacer(minLength: AppTheme.Spacing.xl)
            }
            .padding(.top, AppTheme.Spacing.m)
        }
        .navigationTitle("\(dogName)'s Progress")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showShareSheet) {
            ShareableSummaryView(progress: appState.behaviorProgress, dogName: dogName)
        }
    }
}

// MARK: - Insight of the Day Card

private struct InsightOfDayCard: View {
    let insight: String
    let dogName: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(spacing: AppTheme.Spacing.s) {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                    .font(.system(size: 14))
                Text("Insight of the Day")
                    .font(AppTheme.Font.caption(12))
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .kerning(0.5)
            }
            Text(insight)
                .font(AppTheme.Font.body(15))
                .foregroundColor(.primary)
                .lineSpacing(3)
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.07))
        .cornerRadius(AppTheme.Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Proactive Insight Card

private struct ProactiveInsightCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))
            Text(message)
                .font(AppTheme.Font.body(14))
                .foregroundColor(.primary)
                .lineSpacing(3)
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.07))
        .cornerRadius(AppTheme.Radius.m)
    }
}

// MARK: - Dimension Progress Card

struct DimensionProgressCard: View {
    let score: BehaviorDimensionScore
    let dogName: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row (always visible)
            Button(action: onTap) {
                HStack(spacing: AppTheme.Spacing.m) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(scoreColor.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Text(score.dimension.icon)
                            .font(.system(size: 20))
                    }

                    // Title + score label
                    VStack(alignment: .leading, spacing: 3) {
                        Text(score.dimension.displayName)
                            .font(AppTheme.Font.title(15))
                        Text(score.scoreLabel)
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(scoreColor)
                    }

                    Spacer()

                    // Score + trend
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(score.trend.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(trendColor)
                            Text("\(Int(score.score))")
                                .font(AppTheme.Font.headline(18))
                                .foregroundColor(scoreColor)
                        }
                        Text(score.trend.label)
                            .font(AppTheme.Font.caption(11))
                            .foregroundColor(trendColor)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(AppTheme.Spacing.m)
            }
            .buttonStyle(.plain)

            // Progress bar
            ProgressBarView(progress: score.score / 100.0, color: scoreColor)
                .frame(height: 5)
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.bottom, AppTheme.Spacing.s)

            // Expanded detail
            if isExpanded {
                Divider().padding(.horizontal, AppTheme.Spacing.m)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                    // AI insight
                    let insight = AIProgressInterpreter.dimensionInsight(score: score, dogName: dogName)
                    HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                        Image(systemName: "bubble.left")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Text(insight)
                            .font(AppTheme.Font.body(13))
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }

                    // Confidence indicator
                    if score.confidence > 0 {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: "chart.dots.scatter")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(confidenceLabel)
                                .font(AppTheme.Font.caption(12))
                                .foregroundColor(.secondary)
                        }
                    }

                    // History sparkline (last 7 points)
                    if score.history.count >= 2 {
                        Sparkline(history: Array(score.history.suffix(7)))
                            .frame(height: 30)
                    } else {
                        Text("Data available after 2 days of logging")
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Goal state
                    HStack(alignment: .top, spacing: AppTheme.Spacing.xs) {
                        Text("Goal:")
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.secondary)
                        Text(score.dimension.goalState)
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                }
                .padding(AppTheme.Spacing.m)
            }
        }
        .cardStyle()
    }

    private var scoreColor: Color {
        switch score.score {
        case 75...: return .green
        case 55...: return AppTheme.primaryFallback
        case 35...: return .orange
        default:    return .red
        }
    }

    private var trendColor: Color {
        switch score.trend {
        case .improving:      return .green
        case .stable:         return .secondary
        case .needsAttention: return .orange
        }
    }

    private var confidenceLabel: String {
        switch score.confidence {
        case 75...: return "High confidence — based on good amount of data"
        case 50...: return "Medium confidence — more daily logs will improve accuracy"
        default:    return "Low confidence — keep logging to build a clearer picture"
        }
    }
}

// MARK: - Sparkline (mini history chart)

private struct Sparkline: View {
    let history: [DimensionSnapshot]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let points = history.map { $0.score }
            let minVal = (points.min() ?? 0) - 5
            let maxVal = (points.max() ?? 100) + 5
            let range  = max(1, maxVal - minVal)

            Path { path in
                for (i, value) in points.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(max(1, points.count - 1))
                    let y = h - h * CGFloat((value - minVal) / range)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(AppTheme.primaryFallback.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Dots
            ForEach(Array(points.enumerated()), id: \.0) { i, value in
                let x = w * CGFloat(i) / CGFloat(max(1, points.count - 1))
                let y = h - h * CGFloat((value - minVal) / range)
                Circle()
                    .fill(AppTheme.primaryFallback)
                    .frame(width: 5, height: 5)
                    .position(x: x, y: y)
            }
        }
    }
}

// MARK: - Low data hint

private struct LowDataHint: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            Text("Log daily activities and behaviors for at least 3–4 days to see meaningful progress trends.")
                .font(AppTheme.Font.caption(13))
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .padding(AppTheme.Spacing.m)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppTheme.Radius.m)
    }
}

#Preview {
    NavigationStack {
        BehaviorProgressView()
            .environmentObject({
                let s = AppState()
                s.dogProfile = DogProfile(
                    id: "1", name: "Luna", gender: .female,
                    ageGroup: .twoTo3Months, breed: "Golden Retriever",
                    isBreedUnknown: false, size: nil,
                    activityLevel: .medium, issues: [], photoURL: nil
                )
                return s
            }())
    }
}
