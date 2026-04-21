import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject var appState: AppState

    private var hasDog: Bool { appState.dogProfile != nil }

    private var available: [Challenge] {
        appState.challenges.filter { !$0.isCompleted && (!$0.type.requiresDog || hasDog) }
    }
    private var locked: [Challenge] {
        appState.challenges.filter { !$0.isCompleted && $0.type.requiresDog && !hasDog }
    }
    private var completed: [Challenge] {
        appState.challenges.filter { $0.isCompleted }
    }

    var body: some View {
        List {
            if !available.isEmpty {
                Section("Active") {
                    ForEach(available) { challenge in
                        ChallengeRow(challenge: challenge)
                    }
                }
            }

            if !locked.isEmpty {
                Section {
                    ForEach(locked) { challenge in
                        LockedChallengeRow(challenge: challenge)
                    }
                } header: {
                    Text("Available when you have a dog")
                } footer: {
                    Text("Set up your dog's profile from the Profile tab to unlock these.")
                        .font(AppTheme.Font.caption(12))
                }
            }

            if !completed.isEmpty {
                Section("Completed") {
                    ForEach(completed) { challenge in
                        ChallengeRow(challenge: challenge)
                    }
                }
            }

            if appState.challenges.isEmpty {
                Section {
                    Text("No challenges yet. Start logging activities to unlock them.")
                        .foregroundColor(.secondary)
                        .font(AppTheme.Font.body())
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ChallengeRow: View {
    let challenge: Challenge

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                Text(challenge.type.icon).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(challenge.type.title)
                            .font(AppTheme.Font.title(15))
                        Spacer()
                        if challenge.isCompleted {
                            Text("✅ Done")
                                .font(AppTheme.Font.caption(12))
                                .foregroundColor(.green)
                        } else {
                            Text("+\(challenge.type.pointReward) pts")
                                .font(AppTheme.Font.caption(12))
                                .foregroundColor(AppTheme.primaryFallback)
                                .fontWeight(.medium)
                        }
                    }
                    Text(challenge.type.description)
                        .font(AppTheme.Font.caption())
                        .foregroundColor(.secondary)
                }
            }

            if !challenge.isCompleted {
                HStack {
                    ProgressBarView(progress: challenge.progressFraction, color: AppTheme.primaryFallback)
                    Text("\(challenge.progress)/\(challenge.type.requirement)")
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .opacity(challenge.isCompleted ? 0.6 : 1.0)
    }
}

private struct LockedChallengeRow: View {
    let challenge: Challenge

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Text(challenge.type.icon)
                .font(.system(size: 22))
                .opacity(0.4)
            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.type.title)
                    .font(AppTheme.Font.title(15))
                    .foregroundColor(.secondary)
                Text(challenge.type.description)
                    .font(AppTheme.Font.caption())
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .opacity(0.5)
    }
}

#Preview {
    NavigationStack {
        ChallengesView()
            .environmentObject({ let s = AppState(); s.challenges = Challenge.defaults(); return s }())
    }
}
