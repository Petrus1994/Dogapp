import SwiftUI

struct DogStateCard: View {
    let dogState: DogState
    let dogName: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(dogName)'s State")
                        .font(AppTheme.Font.title(15))
                    Text("Updated \(timeAgo(dogState.lastUpdated))")
                        .font(AppTheme.Font.caption(11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dogState.emoji)
                        .font(.system(size: 28))
                    Text(dogState.label)
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(labelColor)
                        .fontWeight(.medium)
                }
            }

            Divider()

            // Metrics
            VStack(spacing: AppTheme.Spacing.s) {
                StateMetricRow(label: "Energy",    icon: "⚡", value: dogState.energyLevel,
                               valueLabel: dogState.energyLabel, invertColor: true)
                StateMetricRow(label: "Calmness",  icon: "😌", value: dogState.calmness,
                               valueLabel: percentLabel(dogState.calmness))
                StateMetricRow(label: "Satisfaction", icon: "😊", value: dogState.satisfaction,
                               valueLabel: percentLabel(dogState.satisfaction))
                StateMetricRow(label: "Stability", icon: "🎯", value: dogState.behaviorStability,
                               valueLabel: percentLabel(dogState.behaviorStability))
                StateMetricRow(label: "Focus",     icon: "👁", value: dogState.focusOnOwner,
                               valueLabel: percentLabel(dogState.focusOnOwner))
            }

            // Context note
            if let note = contextNote {
                HStack(alignment: .top, spacing: AppTheme.Spacing.xs) {
                    Text("💡").font(.system(size: 12))
                    Text(note)
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                .padding(AppTheme.Spacing.s)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(AppTheme.Radius.s)
            }
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
    }

    private var labelColor: Color {
        switch dogState.overallScore {
        case 0.7...: return .green
        case 0.45...: return AppTheme.primaryFallback
        default:     return .orange
        }
    }

    private var contextNote: String? {
        if dogState.energyLevel > 0.75 {
            return "High energy detected — a longer walk or play session will help."
        } else if dogState.calmness < 0.35 {
            return "Your dog seems unsettled. Focus on calm, consistent routine today."
        } else if dogState.satisfaction < 0.35 {
            return "More activities will help — try logging feeding and play time."
        } else if dogState.overallScore > 0.75 {
            return "Great condition! Keep the routine going."
        }
        return nil
    }

    private func percentLabel(_ value: Double) -> String {
        switch value {
        case 0.75...: return "High"
        case 0.5...:  return "Good"
        case 0.3...:  return "Moderate"
        default:      return "Low"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }
}

private struct StateMetricRow: View {
    let label: String
    let icon: String
    let value: Double
    let valueLabel: String
    var invertColor: Bool = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Text(icon).font(.system(size: 14)).frame(width: 20)
            Text(label)
                .font(AppTheme.Font.caption(13))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(UIColor.tertiarySystemBackground))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.opacity(0.8))
                        .frame(width: geo.size.width * value)
                }
            }
            .frame(height: 6)

            Text(valueLabel)
                .font(AppTheme.Font.caption(12))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }

    private var barColor: Color {
        let good = invertColor ? (1.0 - value) : value
        switch good {
        case 0.7...: return .green
        case 0.4...: return AppTheme.primaryFallback
        default:     return .orange
        }
    }
}

#Preview {
    DogStateCard(dogState: .neutral, dogName: "Luna")
        .padding()
}
