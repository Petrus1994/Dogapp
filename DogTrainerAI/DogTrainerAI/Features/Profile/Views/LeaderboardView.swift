import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var appState: AppState

    private var entries: [LeaderboardEntry] {
        LeaderboardEntry.mockEntries(userPoints: appState.userProgress.totalPoints,
                                     userLevel: appState.userProgress.level,
                                     userStreak: appState.userProgress.currentStreak)
    }

    private var myRank: Int {
        (entries.firstIndex { $0.isCurrentUser } ?? 0) + 1
    }

    var body: some View {
        List {
            // Current user card
            Section {
                if let me = entries.first(where: { $0.isCurrentUser }) {
                    LeaderboardRow(entry: me, rank: myRank, isHighlighted: true)
                }
            } header: {
                Text("Your position")
            }

            // Top players
            Section {
                ForEach(Array(entries.prefix(20).enumerated()), id: \.element.id) { idx, entry in
                    LeaderboardRow(entry: entry, rank: idx + 1, isHighlighted: entry.isCurrentUser)
                }
            } header: {
                Text("Community")
            } footer: {
                Text("Rankings are based on consistency, honesty, and improvement — not just points.")
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Row

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                Text(rankLabel)
                    .font(AppTheme.Font.title(13))
                    .foregroundColor(rankColor)
            }

            // Avatar placeholder + name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.level.icon).font(.system(size: 14))
                    Text(entry.name)
                        .font(AppTheme.Font.title(14))
                        .foregroundColor(isHighlighted ? AppTheme.primaryFallback : .primary)
                }
                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(entry.level.displayName)
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                    if entry.streak > 0 {
                        Text("· 🔥\(entry.streak)d")
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            Text("\(entry.points) pts")
                .font(AppTheme.Font.title(13))
                .foregroundColor(isHighlighted ? AppTheme.primaryFallback : .secondary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .listRowBackground(isHighlighted
                           ? AppTheme.primaryFallback.opacity(0.05)
                           : Color.clear)
    }

    private var rankLabel: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(UIColor.systemGray)
        case 3: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Data model

struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let points: Int
    let streak: Int
    let level: UserProgress.UserLevel
    let isCurrentUser: Bool

    static func mockEntries(
        userPoints: Int,
        userLevel: UserProgress.UserLevel,
        userStreak: Int
    ) -> [LeaderboardEntry] {
        let names = [
            ("Max", 1840, 21, UserProgress.UserLevel.advanced),
            ("Sophie", 1610, 18, .advanced),
            ("Oliver", 1480, 14, .responsible),
            ("Mia", 1320, 12, .responsible),
            ("Lucas", 1190, 9,  .responsible),
            ("Emma", 1050, 8,  .consistent),
            ("Noah", 980,  7,  .consistent),
            ("Lena", 870,  6,  .consistent),
            ("James", 760, 5,  .consistent),
            ("Aria", 650,  4,  .consistent),
            ("Eli",  530,  3,  .beginner),
            ("Zoe",  410,  2,  .beginner),
            ("Sam",  290,  1,  .beginner),
            ("Nora", 180,  0,  .beginner),
            ("Finn", 90,   0,  .beginner),
        ]

        var entries: [LeaderboardEntry] = names.map { (name, pts, streak, level) in
            LeaderboardEntry(id: name, name: name, points: pts, streak: streak,
                             level: level, isCurrentUser: false)
        }

        // Insert real user and re-sort
        let me = LeaderboardEntry(id: "me", name: "You", points: userPoints,
                                  streak: userStreak, level: userLevel, isCurrentUser: true)
        entries.append(me)
        entries.sort { $0.points > $1.points }
        return entries
    }
}

#Preview {
    NavigationStack {
        LeaderboardView()
            .environmentObject({
                let s = AppState()
                s.userProgress.totalPoints = 720
                s.userProgress.currentStreak = 5
                return s
            }())
    }
}
