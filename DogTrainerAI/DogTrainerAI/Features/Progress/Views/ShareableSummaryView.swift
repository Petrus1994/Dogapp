import SwiftUI

struct ShareableSummaryView: View {
    let progress: BehaviorProgress
    let dogName: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var summaryText: String {
        AIProgressInterpreter.weeklySummary(progress: progress, dogName: dogName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {

                    // Preview card (mimics share appearance)
                    SummaryCard(progress: progress, dogName: dogName, summaryText: summaryText)
                        .padding(.horizontal, AppTheme.Spacing.l)
                        .padding(.top, AppTheme.Spacing.m)

                    // Copy text button
                    Button {
                        UIPasteboard.general.string = shareString
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack(spacing: AppTheme.Spacing.s) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied!" : "Copy Text")
                        }
                        .font(AppTheme.Font.title(15))
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.m)
                        .background(copied ? Color.green : AppTheme.primaryFallback)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.Radius.m)
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                    .animation(.easeInOut(duration: 0.2), value: copied)

                    // Share via sheet
                    ShareLink(
                        item: shareString,
                        subject: Text("\(dogName)'s Training Progress"),
                        message: Text("Check out how \(dogName) is progressing!")
                    ) {
                        HStack(spacing: AppTheme.Spacing.s) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share via...")
                        }
                        .font(AppTheme.Font.title(15))
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.m)
                        .background(AppTheme.primaryFallback.opacity(0.1))
                        .foregroundColor(AppTheme.primaryFallback)
                        .cornerRadius(AppTheme.Radius.m)
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)

                    Spacer(minLength: AppTheme.Spacing.xl)
                }
            }
            .navigationTitle("Share Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var shareString: String {
        var lines: [String] = [
            "🐾 \(dogName)'s Training Progress",
            "",
            summaryText,
            "",
        ]
        for score in progress.scores.filter({ $0.confidence > 20 }) {
            let bar  = progressBar(score.score)
            let arrow = score.trend == .improving ? "↑" : score.trend == .needsAttention ? "↓" : "→"
            lines.append("\(score.dimension.icon) \(score.dimension.displayName): \(bar) \(Int(score.score))/100 \(arrow)")
        }
        lines += ["", "Tracked with PawCoach 🐕"]
        return lines.joined(separator: "\n")
    }

    private func progressBar(_ value: Double) -> String {
        let filled = Int(value / 10)
        return String(repeating: "█", count: filled) + String(repeating: "░", count: 10 - filled)
    }
}

// MARK: - Summary Card (visual preview)

private struct SummaryCard: View {
    let progress: BehaviorProgress
    let dogName: String
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            HStack {
                Text("🐾")
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(dogName)'s Progress")
                        .font(AppTheme.Font.headline(17))
                    Text("7-day training summary")
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text(summaryText)
                .font(AppTheme.Font.body(14))
                .foregroundColor(.primary)
                .lineSpacing(4)

            Divider()

            // Dimension scores
            ForEach(progress.scores.filter { $0.confidence > 20 }, id: \.id) { score in
                SummaryDimensionRow(score: score)
            }

            Text("PawCoach")
                .font(AppTheme.Font.caption(11))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(AppTheme.Spacing.m)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(AppTheme.Radius.l)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

private struct SummaryDimensionRow: View {
    let score: BehaviorDimensionScore

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Text(score.dimension.icon).font(.system(size: 14))
            Text(score.dimension.displayName)
                .font(AppTheme.Font.caption(13))
                .foregroundColor(.secondary)
            Spacer()
            ProgressBarView(progress: score.score / 100.0, color: scoreColor)
                .frame(width: 80, height: 5)
            Text("\(Int(score.score))")
                .font(AppTheme.Font.caption(12))
                .foregroundColor(scoreColor)
                .frame(width: 28, alignment: .trailing)
            Text(score.trend.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(trendColor)
        }
    }

    private var scoreColor: Color {
        switch score.score {
        case 75...: return .green
        case 55...: return AppTheme.primaryFallback
        default:    return .orange
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
    ShareableSummaryView(progress: .initial, dogName: "Luna")
}
