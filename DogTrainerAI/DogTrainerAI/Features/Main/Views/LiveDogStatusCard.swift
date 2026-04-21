import SwiftUI

struct LiveDogStatusCard: View {
    @EnvironmentObject var appState: AppState
    let dogName: String
    var onToiletTap: () -> Void

    var body: some View {
        let state = appState.dogState
        let need  = state.primaryNeed

        VStack(spacing: 0) {
            // Hero section — big emoji + dog name + need
            VStack(spacing: AppTheme.Spacing.s) {
                ZStack {
                    Circle()
                        .fill(needColor(need).opacity(0.12))
                        .frame(width: 100, height: 100)
                    Text(dogEmoji(state: state, need: need))
                        .font(.system(size: 56))
                }

                VStack(spacing: 4) {
                    Text(dogName)
                        .font(AppTheme.Font.headline(20))
                    Text(state.label)
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(overallColor(state))
                        .fontWeight(.medium)
                }
            }
            .padding(.top, AppTheme.Spacing.m)
            .padding(.bottom, AppTheme.Spacing.s)

            Divider().padding(.horizontal, AppTheme.Spacing.m)

            // Current need — the "one thing to do now"
            HStack(spacing: AppTheme.Spacing.s) {
                Text(need.icon)
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Right now")
                        .font(AppTheme.Font.caption(11))
                        .foregroundColor(.secondary)
                    Text(need.label)
                        .font(AppTheme.Font.title(14))
                }
                Spacer()
                if need == .toilet {
                    Button("Log toilet") {
                        onToiletTap()
                    }
                    .font(AppTheme.Font.caption(13))
                    .padding(.horizontal, AppTheme.Spacing.s)
                    .padding(.vertical, 6)
                    .background(needColor(need).opacity(0.15))
                    .foregroundColor(needColor(need))
                    .cornerRadius(AppTheme.Radius.s)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .background(needColor(need).opacity(0.06))

            // Mini status bars
            HStack(spacing: AppTheme.Spacing.s) {
                MiniBar(label: "Energy", value: state.energyLevel, invert: true)
                MiniBar(label: "Calm",   value: state.calmness)
                MiniBar(label: "Focus",  value: state.focusOnOwner)
                if state.toiletUrgency > 0.05 {
                    MiniBar(label: "Toilet", value: state.toiletUrgency, invert: false, overrideColor: .orange)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.top, AppTheme.Spacing.s)
            .padding(.bottom, AppTheme.Spacing.m)

            // Toilet prediction if present
            if let prediction = appState.toiletPrediction, prediction.minutesUntil <= 30 {
                Divider().padding(.horizontal, AppTheme.Spacing.m)
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text(prediction.message)
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.vertical, AppTheme.Spacing.s)
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func dogEmoji(state: DogState, need: DogState.DogNeed) -> String {
        switch need {
        case .toilet:   return "🐶"
        case .feeding:  return "🐕"
        case .activity: return "🦮"
        case .play:     return "🐩"
        case .training: return "🐕‍🦺"
        case .calm:     return "😮‍💨"
        case .rest:     return "💤"
        case .balanced: return state.emoji
        }
    }

    private func needColor(_ need: DogState.DogNeed) -> Color {
        switch need.urgency {
        case .high:   return .orange
        case .medium: return AppTheme.primaryFallback
        case .low:    return .green
        }
    }

    private func overallColor(_ state: DogState) -> Color {
        switch state.overallScore {
        case 0.7...: return .green
        case 0.45...: return AppTheme.primaryFallback
        default:      return .orange
        }
    }
}

// MARK: - Mini status bar

private struct MiniBar: View {
    let label: String
    let value: Double
    var invert: Bool = false
    var overrideColor: Color? = nil

    private var effectiveGood: Double { invert ? 1.0 - value : value }

    private var barColor: Color {
        if let c = overrideColor { return c }
        switch effectiveGood {
        case 0.65...: return .green
        case 0.35...: return AppTheme.primaryFallback
        default:      return .orange
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(UIColor.tertiarySystemBackground))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor.opacity(0.8))
                        .frame(width: geo.size.width * min(value, 1.0))
                }
            }
            .frame(height: 5)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    LiveDogStatusCard(dogName: "Luna") {}
        .environmentObject(AppState())
        .padding()
}
