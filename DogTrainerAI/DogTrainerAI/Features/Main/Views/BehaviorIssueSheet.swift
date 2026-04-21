import SwiftUI

struct BehaviorIssueSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @Binding var isPresented: Bool

    let activity: DailyActivity

    @State private var selectedIssues: Set<BehaviorEvent.BehaviorIssue>
    @State private var notes = ""

    init(isPresented: Binding<Bool>, activity: DailyActivity) {
        self._isPresented = isPresented
        self.activity = activity
        // Pre-populate from walk quality so the user isn't asked twice
        var preSelected: Set<BehaviorEvent.BehaviorIssue> = []
        if activity.type == .walking {
            switch activity.walkQuality {
            case .pulling:    preSelected.insert(.leashPulling)
            case .distracted: preSelected.insert(.ignoringOwner)
            case .calm, .none: break
            }
        }
        self._selectedIssues = State(initialValue: preSelected)
    }

    private var issueOptions: [BehaviorEvent.BehaviorIssue] {
        switch activity.type {
        case .walking:
            return [.leashPulling, .overexcitement, .jumpingOnPeople, .reactingToDogs, .reactingToPeople, .barking]
        case .training:
            return [.notResponding, .ignoringOwner, .overexcitement, .jumpingOnPeople, .fearReactions, .other]
        case .feeding:
            return [.beggingForFood, .pickingFoodFromGround, .overexcitement, .toiletAccidents, .whiningOrHowling, .other]
        case .playing:
            return [.overexcitement, .jumpingOnPeople, .barking, .ignoringOwner, .chewingObjects, .fearReactions]
        case .parkSession:
            return [.leashPulling, .reactingToDogs, .reactingToPeople, .overexcitement, .jumpingOnPeople, .barking]
        }
    }

    private var hasPreSelected: Bool {
        if activity.type == .walking {
            return activity.walkQuality == .pulling || activity.walkQuality == .distracted
        }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {
                    // Header
                    VStack(spacing: AppTheme.Spacing.s) {
                        Text("🐾")
                            .font(.system(size: 40))
                        Text("Any other issues during the \(activity.type.displayName.lowercased())?")
                            .font(AppTheme.Font.headline())
                            .multilineTextAlignment(.center)
                        Text("Honest answers help your dog improve faster.\nThis is not about points — it's about better coaching.")
                            .font(AppTheme.Font.body(14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.top, AppTheme.Spacing.m)
                    .padding(.horizontal, AppTheme.Spacing.l)

                    // Pre-selection note
                    if hasPreSelected {
                        HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(AppTheme.primaryFallback)
                                .font(.system(size: 14))
                            Text("Pre-selected based on the walk quality you reported. Deselect anything that wasn't a real issue.")
                                .font(AppTheme.Font.caption(13))
                                .foregroundColor(.secondary)
                        }
                        .padding(AppTheme.Spacing.m)
                        .background(AppTheme.primaryFallback.opacity(0.07))
                        .cornerRadius(AppTheme.Radius.s)
                        .padding(.horizontal, AppTheme.Spacing.l)
                    }

                    // Issue grid
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: AppTheme.Spacing.s
                    ) {
                        ForEach(issueOptions) { issue in
                            IssueChip(
                                issue: issue,
                                isSelected: selectedIssues.contains(issue)
                            ) {
                                toggleIssue(issue)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)

                    // Notes (only shown when issues are selected)
                    if !selectedIssues.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                            Text("What happened? (optional)")
                                .font(AppTheme.Font.title(15))
                                .foregroundColor(.secondary)

                            TextField("Describe what you observed...", text: $notes, axis: .vertical)
                                .font(AppTheme.Font.body())
                                .lineLimit(3...5)
                                .padding(AppTheme.Spacing.m)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppTheme.Radius.s)
                        }
                        .padding(.horizontal, AppTheme.Spacing.l)
                    }

                    // Info note
                    HStack(alignment: .top, spacing: AppTheme.Spacing.s) {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppTheme.primaryFallback)
                            .font(.system(size: 14))
                        Text("Reporting issues earns points and helps your AI coach give better advice.")
                            .font(AppTheme.Font.caption(13))
                            .foregroundColor(.secondary)
                    }
                    .padding(AppTheme.Spacing.m)
                    .background(AppTheme.primaryFallback.opacity(0.07))
                    .cornerRadius(AppTheme.Radius.s)
                    .padding(.horizontal, AppTheme.Spacing.l)

                    Spacer(minLength: AppTheme.Spacing.xl)
                }
            }
            .navigationTitle("Behavior Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { isPresented = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: AppTheme.Spacing.s) {
                        PrimaryButton(title: selectedIssues.isEmpty ? "No Other Issues ✓" : "Save Issues") {
                            saveEvent()
                        }
                        if selectedIssues.isEmpty {
                            Text("You can always log issues later from the Summary")
                                .font(AppTheme.Font.caption(12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(AppTheme.Spacing.m)
                    .background(Color(UIColor.systemBackground))
                }
            }
        }
    }

    private func toggleIssue(_ issue: BehaviorEvent.BehaviorIssue) {
        if selectedIssues.contains(issue) {
            selectedIssues.remove(issue)
        } else {
            selectedIssues.insert(issue)
        }
    }

    private func saveEvent() {
        let issues: [BehaviorEvent.BehaviorIssue] = selectedIssues.isEmpty ? [.noIssues] : Array(selectedIssues)
        let event = BehaviorEvent(
            id: UUID().uuidString,
            date: Date(),
            activityType: activity.type,
            issues: issues,
            notes: notes
        )
        appState.logBehaviorEvent(event)
        router.toastMessage = selectedIssues.isEmpty ? "All clear ✓" : "Issues noted ✓"
        isPresented = false
    }
}

private struct IssueChip: View {
    let issue: BehaviorEvent.BehaviorIssue
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Text(issue.icon).font(.system(size: 14))
                Text(issue.displayName)
                    .font(AppTheme.Font.caption(12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, AppTheme.Spacing.s)
            .padding(.vertical, AppTheme.Spacing.s)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                    .fill(isSelected ? Color.orange.opacity(0.12) : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
                    )
            )
            .foregroundColor(isSelected ? .orange : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BehaviorIssueSheet(isPresented: .constant(true), activity: DailyActivity(
        id: "1", date: Date(), type: .walking, durationMinutes: 30, completed: true, walkQuality: .pulling, notes: ""
    ))
    .environmentObject(AppState())
    .environmentObject(AppRouter())
}
