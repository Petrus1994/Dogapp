import SwiftUI

struct ToiletEventSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @Binding var isPresented: Bool

    @State private var selectedOutcome: ToiletEvent.Outcome = .success
    @State private var notes: String = ""

    private let outcomes: [(ToiletEvent.Outcome, String, String, Color)] = [
        (.success,  "✅", "Success",    .green),
        (.accident, "❌", "Accident",   .orange),
        (.prompted, "🔄", "Didn't go", .secondary),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.l) {
                // Outcome selector
                VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                    Text("What happened?")
                        .font(AppTheme.Font.title(15))
                        .padding(.horizontal, AppTheme.Spacing.l)

                    HStack(spacing: AppTheme.Spacing.s) {
                        ForEach(outcomes, id: \.0.rawValue) { outcome, icon, label, color in
                            OutcomeButton(
                                icon: icon,
                                label: label,
                                color: color,
                                isSelected: selectedOutcome == outcome
                            ) {
                                selectedOutcome = outcome
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                }

                // Notes
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Notes (optional)")
                        .font(AppTheme.Font.caption(13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.l)

                    TextField("e.g. right after walk, outside spot", text: $notes, axis: .vertical)
                        .font(AppTheme.Font.body(15))
                        .padding(AppTheme.Spacing.m)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(AppTheme.Radius.m)
                        .padding(.horizontal, AppTheme.Spacing.l)
                        .lineLimit(3)
                }

                // Context tip
                contextTip
                    .padding(.horizontal, AppTheme.Spacing.l)

                Spacer()

                // Save
                Button(action: save) {
                    Text("Save Toilet Event")
                        .font(AppTheme.Font.title(16))
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.m)
                        .background(AppTheme.primaryFallback)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.Radius.m)
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.bottom, AppTheme.Spacing.l)
            }
            .padding(.top, AppTheme.Spacing.l)
            .navigationTitle("Toilet Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    @ViewBuilder
    private var contextTip: some View {
        if selectedOutcome == .accident {
            HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13))
                Text("Accidents help the app learn — your timing window will be adjusted automatically.")
                    .font(AppTheme.Font.caption(13))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(AppTheme.Spacing.m)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(AppTheme.Radius.s)
        } else if selectedOutcome == .prompted {
            HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                Text("\"Didn't go\" means you took them out but they didn't go. This still helps track the pattern.")
                    .font(AppTheme.Font.caption(13))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(AppTheme.Spacing.m)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(AppTheme.Radius.s)
        }
    }

    private func save() {
        let minutesAfterFeeding: Int? = {
            guard let last = appState.todayActivities
                .filter({ $0.type == .feeding && $0.completed })
                .last?.date else { return nil }
            return Int(Date().timeIntervalSince(last) / 60)
        }()

        let minutesAfterSleep: Int? = {
            guard let lastSleepEnd = appState.dailyRoutine?.cycles
                .filter({ $0.phase == .sleep && $0.isCompleted })
                .compactMap({ $0.completedAt })
                .last else { return nil }
            return Int(Date().timeIntervalSince(lastSleepEnd) / 60)
        }()

        let event = ToiletEvent(
            id: UUID().uuidString,
            date: Date(),
            outcome: selectedOutcome,
            minutesAfterLastFeeding: minutesAfterFeeding,
            minutesAfterLastSleep: minutesAfterSleep,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        appState.logToiletEvent(event)
        router.toastMessage = "Toilet logged ✓"
        isPresented = false
    }
}

// MARK: - Outcome button

private struct OutcomeButton: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Text(icon).font(.system(size: 28))
                Text(label)
                    .font(AppTheme.Font.caption(13))
                    .foregroundColor(isSelected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.m)
            .background(isSelected ? color.opacity(0.12) : Color(UIColor.secondarySystemBackground))
            .cornerRadius(AppTheme.Radius.m)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                    .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ToiletEventSheet(isPresented: .constant(true))
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
