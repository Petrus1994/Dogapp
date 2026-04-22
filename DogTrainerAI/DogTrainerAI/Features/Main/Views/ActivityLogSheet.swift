import SwiftUI

struct ActivityLogSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    let activityType: DailyActivity.ActivityType
    @Binding var isPresented: Bool

    @State private var durationMinutes: Int
    @State private var walkQuality: DailyActivity.WalkQuality = .calm
    @State private var distanceKm: Double = 1.0
    @State private var foodType: DailyActivity.FoodType = .dry
    @State private var playActivity: DailyActivity.PlayActivity = .fetch
    @State private var notes = ""
    @StateObject private var stepTracker = StepTrackingService.shared

    init(activityType: DailyActivity.ActivityType, isPresented: Binding<Bool>) {
        self.activityType = activityType
        self._isPresented = isPresented
        self._durationMinutes = State(initialValue: activityType.defaultDurationMinutes)
    }

    private var norms: ActivityNorms? { appState.activityNorms }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {
                    // Icon + title
                    VStack(spacing: AppTheme.Spacing.s) {
                        Text(activityType.icon)
                            .font(.system(size: 48))
                        Text("Log \(activityType.displayName)")
                            .font(AppTheme.Font.headline())
                        Text(normHintText)
                            .font(AppTheme.Font.caption())
                            .foregroundColor(AppTheme.primaryFallback)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppTheme.Spacing.m)
                    .padding(.horizontal, AppTheme.Spacing.l)

                    // Feeding: food type picker (no duration for feeding)
                    if activityType == .feeding {
                        feedingSection
                    } else {
                        // Duration slider (walk, play, training)
                        durationSection

                        // Walk-specific extras
                        if activityType == .walking {
                            walkQualitySection
                            stepTrackingSection
                            if !stepTracker.isTracking {
                                distanceSection
                            }
                        }

                        // Play activity picker
                        if activityType == .playing {
                            playActivitySection
                        }
                    }

                    // Notes
                    notesSection

                    Spacer(minLength: AppTheme.Spacing.xl)
                }
            }
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    PrimaryButton(title: "Log \(activityType.displayName)") {
                        saveActivity()
                    }
                    .padding(AppTheme.Spacing.m)
                    .background(Color(UIColor.systemBackground))
                }
            }
        }
    }

    // MARK: - Sections

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Duration")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            VStack(spacing: AppTheme.Spacing.s) {
                HStack {
                    Text("\(durationMinutes) min")
                        .font(AppTheme.Font.headline(22))
                        .foregroundColor(AppTheme.primaryFallback)
                    Spacer()
                    if let target = normTarget, activityType != .training {
                        Text("Target: \(target)")
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.secondary)
                    }
                }
                Slider(value: Binding(
                    get: { Double(durationMinutes) },
                    set: { durationMinutes = Int($0) }
                ), in: 5...120, step: 5)
                .tint(AppTheme.primaryFallback)

                HStack {
                    Text("5 min").font(AppTheme.Font.caption(11)).foregroundColor(.secondary)
                    Spacer()
                    Text("2 hrs").font(AppTheme.Font.caption(11)).foregroundColor(.secondary)
                }
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    private var walkQualitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Walk quality")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            HStack(spacing: AppTheme.Spacing.s) {
                ForEach(DailyActivity.WalkQuality.allCases, id: \.self) { quality in
                    Button {
                        walkQuality = quality
                    } label: {
                        VStack(spacing: 6) {
                            Text(quality.icon).font(.system(size: 24))
                            Text(quality.displayName)
                                .font(AppTheme.Font.caption(12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                .fill(walkQuality == quality
                                      ? AppTheme.primaryFallback.opacity(0.15)
                                      : Color(UIColor.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                        .stroke(walkQuality == quality ? AppTheme.primaryFallback : Color.clear,
                                                lineWidth: 1.5)
                                )
                        )
                        .foregroundColor(walkQuality == quality ? AppTheme.primaryFallback : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    private var stepTrackingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Step tracking")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            HStack(spacing: AppTheme.Spacing.m) {
                if stepTracker.isTracking {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stepTracker.liveStepLabel)
                            .font(AppTheme.Font.headline(20))
                            .foregroundColor(AppTheme.primaryFallback)
                        Text(stepTracker.liveDistanceLabel)
                            .font(AppTheme.Font.caption(13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        let result = stepTracker.stopSession(estimatedDurationMinutes: durationMinutes)
                        distanceKm = result.distanceKm
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                            .font(AppTheme.Font.body(14))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Track steps automatically")
                            .font(AppTheme.Font.body(14))
                        Text("Or enter distance manually below")
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if StepTrackingService.isAvailable {
                        Button {
                            stepTracker.startSession()
                        } label: {
                            Label("Start", systemImage: "figure.walk")
                                .font(AppTheme.Font.body(14))
                                .foregroundColor(AppTheme.primaryFallback)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Not available")
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Estimated distance")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            VStack(spacing: AppTheme.Spacing.s) {
                HStack {
                    Text(String(format: "%.1f km", distanceKm))
                        .font(AppTheme.Font.headline(22))
                        .foregroundColor(AppTheme.primaryFallback)
                    Spacer()
                    if let targetKm = norms?.walkDistanceKmPerDay {
                        Text(String(format: "Target: %.1f km", targetKm))
                            .font(AppTheme.Font.caption(12))
                            .foregroundColor(.secondary)
                    }
                }
                Slider(value: $distanceKm, in: 0.1...20.0, step: 0.1)
                    .tint(AppTheme.primaryFallback)
                HStack {
                    Text("0.1 km").font(AppTheme.Font.caption(11)).foregroundColor(.secondary)
                    Spacer()
                    Text("20 km").font(AppTheme.Font.caption(11)).foregroundColor(.secondary)
                }
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    private var feedingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                Text("Food type")
                    .font(AppTheme.Font.title(15))
                    .foregroundColor(.secondary)
                Spacer()
                if let n = norms {
                    Text("\(n.feedingsPerDay)x per day recommended")
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: AppTheme.Spacing.s) {
                ForEach(DailyActivity.FoodType.allCases, id: \.self) { type in
                    Button {
                        foodType = type
                    } label: {
                        VStack(spacing: 6) {
                            Text(type.icon).font(.system(size: 24))
                            Text(type.displayName)
                                .font(AppTheme.Font.caption(12))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                .fill(foodType == type
                                      ? AppTheme.primaryFallback.opacity(0.15)
                                      : Color(UIColor.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                        .stroke(foodType == type ? AppTheme.primaryFallback : Color.clear,
                                                lineWidth: 1.5)
                                )
                        )
                        .foregroundColor(foodType == type ? AppTheme.primaryFallback : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    private var playActivitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("What did you play?")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: AppTheme.Spacing.s) {
                ForEach(DailyActivity.PlayActivity.allCases, id: \.self) { activity in
                    Button {
                        playActivity = activity
                    } label: {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Text(activity.icon).font(.system(size: 16))
                            Text(activity.displayName)
                                .font(AppTheme.Font.caption(12))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                .fill(playActivity == activity
                                      ? AppTheme.primaryFallback.opacity(0.15)
                                      : Color(UIColor.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                        .stroke(playActivity == activity ? AppTheme.primaryFallback : Color.clear,
                                                lineWidth: 1.5)
                                )
                        )
                        .foregroundColor(playActivity == activity ? AppTheme.primaryFallback : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Notes (optional)")
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            TextField("How did it go? Any observations...", text: $notes, axis: .vertical)
                .font(AppTheme.Font.body())
                .lineLimit(3...5)
                .padding(AppTheme.Spacing.m)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(AppTheme.Radius.s)
                .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    // MARK: - Norm helpers

    private var normHintText: String {
        guard let norms else { return "+\(activityType.pointValue) pts for logging honestly" }
        switch activityType {
        case .walking:  return "Target: \(norms.walkMinPerDay) min · \(String(format: "%.1f", norms.walkDistanceKmPerDay)) km"
        case .playing:  return "Target: \(norms.playMinPerDay) min per day"
        case .training: return "Max \(norms.trainingMinPerSession) min per session"
        case .feeding:  return "\(norms.feedingsPerDay)x per day recommended"
        }
    }

    private var normTarget: String? {
        guard let norms else { return nil }
        switch activityType {
        case .walking:  return "\(norms.walkMinPerDay) min"
        case .playing:  return "\(norms.playMinPerDay) min"
        case .training: return "≤\(norms.trainingMinPerSession) min"
        case .feeding:  return nil
        }
    }

    // MARK: - Save

    private func saveActivity() {
        // Capture steps from pedometer if it was running
        var finalDistanceKm = distanceKm
        var finalSteps: Int? = nil
        if stepTracker.isTracking {
            let result = stepTracker.stopSession(estimatedDurationMinutes: durationMinutes)
            finalDistanceKm = result.distanceKm
            finalSteps = result.steps
        } else if activityType == .walking {
            finalSteps = estimatedSteps(km: distanceKm)
        }

        let activity = DailyActivity(
            id: UUID().uuidString,
            date: Date(),
            type: activityType,
            durationMinutes: activityType == .feeding ? 0 : durationMinutes,
            completed: true,
            walkQuality: activityType == .walking ? walkQuality : nil,
            distanceKm: activityType == .walking ? finalDistanceKm : nil,
            stepCount: activityType == .walking ? finalSteps : nil,
            foodType: activityType == .feeding ? foodType : nil,
            playActivity: activityType == .playing ? playActivity : nil,
            notes: notes
        )
        appState.logActivity(activity)
        isPresented = false
        // Only ask about behavior issues after walks and training sessions
        if activityType == .walking || activityType == .training {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                router.didSaveActivity(activity)
            }
        }
    }

    private func estimatedSteps(km: Double) -> Int {
        Int(km * 1350) // ~1350 steps/km average
    }
}

#Preview {
    ActivityLogSheet(activityType: .walking, isPresented: .constant(true))
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
