import SwiftUI

struct QuickLogSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @Binding var isPresented: Bool

    let activityType: DailyActivity.ActivityType
    var linkedTaskId: String? = nil

    @State private var result: QuickResult? = nil
    @State private var selectedDuration: Int? = nil
    @State private var mealNumber: Int = 1
    @State private var showNote = false
    @State private var note = ""

    enum QuickResult: Equatable {
        case great, mixed, tough
        var feedbackResult: TaskFeedback.FeedbackResult {
            switch self {
            case .great: return .success
            case .mixed: return .partial
            case .tough: return .failed
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Header
                VStack(spacing: AppTheme.Spacing.s) {
                    Text(activityType.icon)
                        .font(.system(size: 48))
                        .padding(.top, AppTheme.Spacing.l)
                    Text("How did it go?")
                        .font(AppTheme.Font.headline(24))
                    Text(activityType.displayName)
                        .font(AppTheme.Font.body(15))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, AppTheme.Spacing.l)

                // Result buttons
                HStack(spacing: AppTheme.Spacing.m) {
                    resultButton(.great, icon: "✅", label: "Great", color: .green)
                    resultButton(.mixed, icon: "🔶", label: "Mixed", color: .orange)
                    resultButton(.tough, icon: "❌", label: "Tough",  color: .red)
                }
                .padding(.horizontal, AppTheme.Spacing.l)

                // Duration chips — walk only
                if activityType == .walking {
                    durationChips
                }

                // Meal selector — feeding only
                if activityType == .feeding {
                    mealNumberSelector
                }

                // Optional note
                VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showNote.toggle() }
                    } label: {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: showNote ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12))
                            Text("Add a note")
                                .font(AppTheme.Font.body(14))
                        }
                        .foregroundColor(.secondary)
                    }

                    if showNote {
                        TextField("What happened? Any observations...", text: $note, axis: .vertical)
                            .font(AppTheme.Font.body(15))
                            .padding(AppTheme.Spacing.m)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(AppTheme.Radius.m)
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.top, AppTheme.Spacing.l)

                // Struggled helper text
                if result == .tough {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                        Text(toughTip)
                            .font(AppTheme.Font.caption(13))
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(AppTheme.Spacing.m)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(AppTheme.Radius.s)
                    .padding(.horizontal, AppTheme.Spacing.l)
                    .padding(.top, AppTheme.Spacing.s)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: result)
                }

                Spacer()

                // Footer
                VStack(spacing: AppTheme.Spacing.s) {
                    // Save — enabled only when result selected
                    Button(action: save) {
                        Text("Save")
                            .font(AppTheme.Font.title(16))
                            .frame(maxWidth: .infinity)
                            .padding(AppTheme.Spacing.m)
                            .background(result != nil ? AppTheme.primaryFallback : Color(UIColor.tertiarySystemBackground))
                            .foregroundColor(result != nil ? .white : .secondary)
                            .cornerRadius(AppTheme.Radius.m)
                    }
                    .disabled(result == nil)

                    // Skip — just dismiss, no record created
                    Button { isPresented = false } label: {
                        Text("Skip")
                            .font(AppTheme.Font.caption(13))
                            .foregroundColor(.secondary)
                    }

                    // Full details link
                    Button {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            router.startActivityLog(type: activityType)
                        }
                    } label: {
                        Text("Add full details")
                            .font(AppTheme.Font.caption(13))
                            .foregroundColor(.secondary)
                            .underline()
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.bottom, AppTheme.Spacing.l)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    // MARK: - Duration chips (walk)

    private var durationChips: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("How long?")
                .font(AppTheme.Font.caption(13))
                .foregroundColor(.secondary)
            HStack(spacing: AppTheme.Spacing.s) {
                ForEach([15, 30, 45, 60], id: \.self) { mins in
                    Button {
                        selectedDuration = selectedDuration == mins ? nil : mins
                    } label: {
                        Text("\(mins) min")
                            .font(AppTheme.Font.caption(13))
                            .padding(.horizontal, AppTheme.Spacing.m)
                            .padding(.vertical, 6)
                            .background(
                                selectedDuration == mins
                                    ? AppTheme.primaryFallback
                                    : Color(UIColor.secondarySystemBackground)
                            )
                            .foregroundColor(selectedDuration == mins ? .white : .primary)
                            .cornerRadius(AppTheme.Radius.s)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.l)
        .padding(.top, AppTheme.Spacing.l)
    }

    // MARK: - Meal number selector (feeding)

    private var mealNumberSelector: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Which meal?")
                .font(AppTheme.Font.caption(13))
                .foregroundColor(.secondary)
            HStack(spacing: AppTheme.Spacing.s) {
                mealButton(1, "1st")
                mealButton(2, "2nd")
                mealButton(3, "3rd")
            }
        }
        .padding(.horizontal, AppTheme.Spacing.l)
        .padding(.top, AppTheme.Spacing.l)
    }

    private func mealButton(_ num: Int, _ label: String) -> some View {
        Button { mealNumber = num } label: {
            Text("\(label) meal")
                .font(AppTheme.Font.caption(13))
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.vertical, 6)
                .background(
                    mealNumber == num
                        ? AppTheme.primaryFallback
                        : Color(UIColor.secondarySystemBackground)
                )
                .foregroundColor(mealNumber == num ? .white : .primary)
                .cornerRadius(AppTheme.Radius.s)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Result button

    private func resultButton(
        _ r: QuickResult,
        icon: String,
        label: String,
        color: Color
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) { result = result == r ? nil : r }
        } label: {
            VStack(spacing: AppTheme.Spacing.s) {
                Text(icon).font(.system(size: 32))
                Text(label)
                    .font(AppTheme.Font.title(14))
                    .foregroundColor(result == r ? color : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.m)
            .background(result == r ? color.opacity(0.12) : Color(UIColor.secondarySystemBackground))
            .cornerRadius(AppTheme.Radius.m)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                    .stroke(result == r ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tough tip

    private var toughTip: String {
        switch activityType {
        case .walking:
            return "That's normal — keep sessions short and calm. Overexcitement during walks usually reduces as routine builds."
        case .training:
            return "Short sessions work better. 3–5 minutes of focused practice beats a long frustrated session every time."
        case .playing:
            return "Structured play works better than chaotic free-running. Try fetch or scent games with breaks."
        case .feeding:
            return "Food excitement is common. Try asking for a 'sit' before placing the bowl to build calm feeding habits."
        }
    }

    // MARK: - Save

    private func save() {
        guard let res = result else { return }

        let duration = (activityType == .walking ? selectedDuration : nil)
            ?? activityType.defaultDurationMinutes

        let activity = DailyActivity(
            id: UUID().uuidString,
            date: Date(),
            type: activityType,
            durationMinutes: duration,
            completed: true,
            feedingNumber: activityType == .feeding ? mealNumber : nil,
            notes: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        appState.logActivity(activity)

        // If linked to a task, record feedback
        if let taskId = linkedTaskId {
            let feedback = TaskFeedback(
                id: UUID().uuidString,
                taskId: taskId,
                date: Date(),
                result: res.feedbackResult,
                freeTextComment: note.isEmpty ? nil : note
            )
            appState.recordFeedback(feedback)
        }

        router.toastMessage = "\(activityType.displayName) logged ✓"
        isPresented = false

        // Chain behavior issue sheet only for walk/training when result wasn't great
        if (activityType == .walking || activityType == .training) && res != .great {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                router.didSaveActivity(activity)
            }
        }
    }
}

#Preview {
    QuickLogSheet(isPresented: .constant(true), activityType: .walking)
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
