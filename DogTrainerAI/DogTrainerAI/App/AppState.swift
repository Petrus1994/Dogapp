import SwiftUI
import Combine

enum AppFlow {
    case splash
    case auth
    case onboarding
    case main
}

@MainActor
final class AppState: ObservableObject {
    // MARK: - Existing state
    @Published var flow: AppFlow = .splash
    @Published var currentUser: User?
    @Published var dogProfile: DogProfile?
    @Published var breedSelectionProfile: BreedSelectionProfile?
    @Published var selectedBreed: BreedRecommendation?
    @Published var currentPlan: Plan?
    @Published var recentFeedback: [TaskFeedback] = []

    // MARK: - Coaching system state
    @Published var dogState: DogState = .neutral
    @Published var todayActivities: [DailyActivity] = []
    @Published var allBehaviorEvents: [BehaviorEvent] = []
    @Published var userProgress: UserProgress = .initial
    @Published var challenges: [Challenge] = Challenge.defaults()
    @Published var dailyRoutine: DailyRoutine?
    @Published var todayToiletEvents: [ToiletEvent] = []
    @Published var adaptivePattern: AdaptiveDogPattern = .empty
    @Published var toiletPrediction: ToiletPredictionService.ToiletPrediction?
    @Published var ageProgressionAnnouncement: String?

    // MARK: - Behavioral progress system
    @Published var behaviorProgress: BehaviorProgress = .initial

    private let sessionManager = SessionManager()
    private let userDefaultsManager = UserDefaultsManager.shared

    init() {
        Task { await bootstrap() }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        if sessionManager.isAuthenticated,
           let user = userDefaultsManager.loadUser() {
            currentUser = user
            dogProfile  = userDefaultsManager.loadDogProfile()
            currentPlan = userDefaultsManager.loadPlan()

            // Load coaching system
            userProgress      = userDefaultsManager.loadUserProgress() ?? .initial
            challenges        = userDefaultsManager.loadChallenges()   ?? Challenge.defaults()
            todayActivities   = ActivityTrackingService.shared.todayActivities()
            allBehaviorEvents = BehaviorTrackingService.shared.loadAll()
            behaviorProgress  = userDefaultsManager.loadBehaviorProgress() ?? .initial

            // Check streak break on launch (shield may absorb it)
            let streakResult = StreakService.checkForStreakBreak(progress: &userProgress)
            userDefaultsManager.saveUserProgress(userProgress)
            if let msg = streakResult.notificationMessage {
                ageProgressionAnnouncement = msg  // reuse announcement slot for shield messages
            }

            BackendSyncService.shared.setBackendDogId(userDefaultsManager.loadBackendDogId())

            refreshDogState()
            refreshDailyRoutine()
            refreshToiletState()
            checkAgeProgression()

            flow = user.onboardingCompleted ? .main : .onboarding
        } else {
            flow = .auth
        }
    }

    // MARK: - Auth

    func loginSuccess(user: User, token: String) {
        sessionManager.saveToken(token)
        sessionManager.saveUserId(user.id)
        currentUser = user
        userDefaultsManager.saveUser(user)
        flow = user.onboardingCompleted ? .main : .onboarding
    }

    func completeOnboarding(plan: Plan) {
        currentPlan = plan
        currentUser?.onboardingCompleted = true
        if let user = currentUser { userDefaultsManager.saveUser(user) }
        if let profile = dogProfile {
            userDefaultsManager.saveDogProfile(profile)
            BackendSyncService.shared.syncDogProfile(profile)
        }
        userDefaultsManager.savePlan(plan)
        flow = .main
    }

    func logout() {
        sessionManager.clearToken()
        userDefaultsManager.clearAll()
        BackendSyncService.shared.setBackendDogId(nil)
        ActivityTrackingService.shared.clear()
        BehaviorTrackingService.shared.clear()

        currentUser           = nil
        dogProfile            = nil
        currentPlan           = nil
        selectedBreed         = nil
        breedSelectionProfile = nil
        recentFeedback        = []
        dogState              = .neutral
        todayActivities       = []
        allBehaviorEvents     = []
        userProgress          = .initial
        challenges            = Challenge.defaults()
        dailyRoutine          = nil
        todayToiletEvents     = []
        adaptivePattern       = .empty
        toiletPrediction      = nil
        ageProgressionAnnouncement = nil
        behaviorProgress      = .initial
        NotificationTimingService.shared.cancelAll()
        ToiletTrackingService.shared.clear()
        flow = .auth
    }

    // MARK: - Plan / Task

    func updatePlan(_ plan: Plan) {
        currentPlan = plan
        userDefaultsManager.savePlan(plan)
    }

    func updateTaskStatus(taskId: String, status: TrainingTask.TaskStatus) {
        guard var plan = currentPlan else { return }
        if let idx = plan.tasks.firstIndex(where: { $0.id == taskId }) {
            plan.tasks[idx].status = status
            updatePlan(plan)
        }
    }

    func resetTaskStatus(taskId: String) {
        updateTaskStatus(taskId: taskId, status: .pending)
    }

    func updateTaskNotes(taskId: String, notes: String) {
        guard var plan = currentPlan else { return }
        if let idx = plan.tasks.firstIndex(where: { $0.id == taskId }) {
            plan.tasks[idx].notes = notes
            updatePlan(plan)
        }
    }

    // MARK: - Feedback + scoring

    func recordFeedback(_ feedback: TaskFeedback) {
        recentFeedback.append(feedback)
        if recentFeedback.count > 5 { recentFeedback.removeFirst() }

        // Award points
        let event = ScoringService.pointsFor(feedbackResult: feedback.result)
        awardPoints(event.points)

        // Anti-cheat tracking
        if feedback.result == .success {
            userProgress.consecutiveSuccessCount += 1
        } else {
            userProgress.consecutiveSuccessCount = 0
        }
        saveUserProgress()
        refreshDogState()
        processProgress()
    }

    // MARK: - Activity logging

    func logActivity(_ activity: DailyActivity) {
        todayActivities.append(activity)
        ActivityTrackingService.shared.add(activity)

        // Streak
        StreakService.markActiveToday(progress: &userProgress)

        // Points for the activity
        let activityEvent = ScoringService.pointsFor(activity: activity)
        awardPoints(activityEvent.points)

        // Streak bonus (only once per day — when streak is extended)
        let streakEvent = ScoringService.streakBonus(streak: userProgress.currentStreak)
        if streakEvent.points > 0 && isFirstActivityToday {
            awardPoints(streakEvent.points)
        }

        // Full-day bonus when all 4 types are logged
        let completedTypes = Set(todayActivities.filter { $0.completed }.map { $0.type })
        if completedTypes.count == DailyActivity.ActivityType.allCases.count {
            awardPoints(ScoringService.fullDayBonus().points)
        }

        // Norm-completion bonus: award extra points when meeting walk or play target
        if let norms = activityNorms {
            if activity.type == .walking,
               NormCalculationService.walkCompletion(activities: todayActivities, norms: norms) >= 1.0 {
                awardPoints(ScoringService.normMetBonus(for: .walking).points)
            } else if activity.type == .playing,
                      NormCalculationService.playCompletion(activities: todayActivities, norms: norms) >= 1.0 {
                awardPoints(ScoringService.normMetBonus(for: .playing).points)
            }
        }

        saveUserProgress()
        updateChallenges()
        refreshDogState()
        processProgress()

        // Mirror to backend
        switch activity.type {
        case .walking:     BackendSyncService.shared.syncWalk(activity)
        case .feeding:     BackendSyncService.shared.syncFeeding(activity)
        case .playing:  BackendSyncService.shared.syncPlay(activity)
        case .training: BackendSyncService.shared.syncTraining(activity)
        }

        // Auto-complete the next matching routine cycle
        autoCompleteRoutineCycle(for: activity)

        // Toilet reminder after feeding
        if activity.type == .feeding, let name = dogProfile?.name {
            Task {
                await NotificationTimingService.shared.scheduleToiletReminderAfterFeeding(dogName: name)
            }
        }
    }

    private func autoCompleteRoutineCycle(for activity: DailyActivity) {
        guard var routine = dailyRoutine else { return }
        let matchingPhase: CyclePhase
        switch activity.type {
        case .walking:  matchingPhase = .physical
        case .playing:  matchingPhase = .physical
        case .training: matchingPhase = .mental
        case .feeding:  matchingPhase = .feeding
        }
        if let idx = routine.cycles.firstIndex(where: {
            $0.phase == matchingPhase && !$0.isCompleted && !$0.skipped
        }) {
            routine.cycles[idx].isCompleted = true
            routine.cycles[idx].completedAt = Date()
            routine.cycles[idx].linkedActivityId = activity.id
            dailyRoutine = routine
            userDefaultsManager.saveDailyRoutine(routine)
        }
    }

    func logBehaviorEvent(_ event: BehaviorEvent) {
        allBehaviorEvents.append(event)
        BehaviorTrackingService.shared.add(event)

        // Points for honest reporting
        let issueCount = event.issues.filter { $0 != .noIssues }.count
        let scoreEvent = ScoringService.pointsFor(behaviorIssueCount: issueCount)
        awardPoints(scoreEvent.points)

        // Anti-cheat tracking
        if event.hasRealIssues {
            userProgress.consecutiveNoIssuesCount = 0
        } else {
            userProgress.consecutiveNoIssuesCount += 1
        }

        saveUserProgress()
        updateChallenges()
        refreshDogState()
        processProgress()

        BackendSyncService.shared.syncBehaviorEvent(event)
    }

    // MARK: - Daily routine

    func refreshDailyRoutine() {
        guard let profile = dogProfile else { dailyRoutine = nil; return }

        // Reuse today's routine if it exists and was generated today
        if let existing = userDefaultsManager.loadDailyRoutine(),
           Calendar.current.isDateInToday(existing.date),
           existing.dogProfileId == profile.id {
            dailyRoutine = existing
            return
        }

        // Generate fresh routine for today
        let routine = RoutineEngineService.generate(for: profile)
        dailyRoutine = routine
        userDefaultsManager.saveDailyRoutine(routine)

        // Schedule notifications (fire-and-forget)
        Task {
            _ = await NotificationTimingService.shared.requestPermission()
            await NotificationTimingService.shared.scheduleNotifications(
                for: routine, dogName: profile.name)
        }
    }

    func completeRoutineCycle(_ cycleId: String) {
        guard var routine = dailyRoutine else { return }
        if let idx = routine.cycles.firstIndex(where: { $0.id == cycleId }) {
            routine.cycles[idx].isCompleted = true
            routine.cycles[idx].completedAt = Date()
        }
        dailyRoutine = routine
        userDefaultsManager.saveDailyRoutine(routine)

        // Toilet after feeding nudge
        if let cycle = routine.cycles.first(where: { $0.id == cycleId }),
           cycle.phase == .feeding,
           let name = dogProfile?.name {
            Task {
                await NotificationTimingService.shared.scheduleToiletReminderAfterFeeding(dogName: name)
            }
        }
    }

    func skipRoutineCycle(_ cycleId: String) {
        guard var routine = dailyRoutine else { return }
        if let idx = routine.cycles.firstIndex(where: { $0.id == cycleId }) {
            routine.cycles[idx].skipped = true
        }
        dailyRoutine = routine
        userDefaultsManager.saveDailyRoutine(routine)
    }

    // MARK: - Toilet system

    func logToiletEvent(_ event: ToiletEvent) {
        todayToiletEvents.append(event)
        ToiletTrackingService.shared.add(event)

        // Learn from the new event
        let recentEvents   = ToiletTrackingService.shared.recentEvents(days: 14)
        adaptivePattern    = AdaptivePatternLearningService.learn(from: recentEvents,
                                                                  currentPattern: adaptivePattern)
        userDefaultsManager.saveAdaptivePattern(adaptivePattern)

        refreshToiletState()
        refreshDogState()

        BackendSyncService.shared.syncToiletEvent(event)
    }

    func refreshToiletState() {
        todayToiletEvents = ToiletTrackingService.shared.todayEvents()
        adaptivePattern   = userDefaultsManager.loadAdaptivePattern() ?? .empty

        guard let profile = dogProfile else {
            toiletPrediction = nil
            return
        }

        let lastToilet   = ToiletTrackingService.shared.lastSuccess()?.date
        let lastFeeding  = todayActivities.filter { $0.type == .feeding && $0.completed }.last?.date
        let lastSleepEnd = dailyRoutine?.cycles
            .filter { $0.phase == .sleep && $0.isCompleted }
            .compactMap { $0.completedAt }
            .last

        toiletPrediction = ToiletPredictionService.predict(
            lastToiletDate:   lastToilet,
            lastFeedingDate:  lastFeeding,
            lastSleepEndDate: lastSleepEnd,
            phase:            profile.currentPhase,
            pattern:          adaptivePattern,
            dogName:          profile.name
        )

        // Update dog state toilet urgency
        let urgency = ToiletPredictionService.urgencyLevel(
            lastToiletDate: lastToilet, phase: profile.currentPhase, pattern: adaptivePattern)
        dogState.toiletUrgency = urgency

        // Schedule toilet notification if high urgency
        if urgency > 0.7, let prediction = toiletPrediction {
            Task {
                await NotificationTimingService.shared.sendOverdueActivityNudge(
                    dogName: profile.name, phase: .toilet)
                _ = prediction  // suppress warning
            }
        }
    }

    // MARK: - Age progression

    private func checkAgeProgression() {
        guard let profile = dogProfile else { return }
        let lastPhaseId = userDefaultsManager.loadLastKnownPhaseId()
        let currentPhase = profile.currentPhase

        if let event = AgeProgressionService.checkProgression(
            profile: profile, lastKnownPhaseId: lastPhaseId) {
            // Dog has grown into a new phase — regenerate routine
            ageProgressionAnnouncement = event.announcementMessage
            dailyRoutine = RoutineEngineService.generate(for: profile)
            userDefaultsManager.saveDailyRoutine(dailyRoutine!)
        }

        // Always persist the current phase id
        userDefaultsManager.saveLastKnownPhaseId(currentPhase.id)

        // Sync ageGroup field if we have a birthDate
        if var updatedProfile = dogProfile {
            AgeProgressionService.syncAgeGroup(profile: &updatedProfile)
            dogProfile = updatedProfile
            userDefaultsManager.saveDogProfile(updatedProfile)
        }
    }

    // MARK: - Activity balance

    var activityBalance: ActivityBalanceService.BalanceReport {
        ActivityBalanceService.analyze(activities: todayActivities, norms: activityNorms)
    }

    // MARK: - Dog state

    func refreshDogState() {
        let todayEvents = allBehaviorEvents.filter { Calendar.current.isDateInToday($0.date) }
        dogState = DogStateService.compute(
            todayActivities: todayActivities,
            todayEvents: todayEvents,
            recentFeedback: recentFeedback,
            dogProfile: dogProfile,
            previousState: dogState
        )
    }

    // MARK: - Helpers

    var antiCheatMessage: String? {
        ScoringService.antiCheatMessage(for: userProgress)
    }

    // True only after the user has logged at least one activity today
    var hasTodayActivityData: Bool {
        !todayActivities.isEmpty
    }

    // True when all 4 activity types have been logged today
    var completedFullDayToday: Bool {
        let completedTypes = Set(todayActivities.filter { $0.completed }.map { $0.type })
        return completedTypes.count == DailyActivity.ActivityType.allCases.count
    }

    // Activity norms for the current dog profile (nil for no-dog users)
    var activityNorms: ActivityNorms? {
        dogProfile.map { NormCalculationService.norms(for: $0) }
    }

    // Norm completion coaching insight for today
    var coachingInsight: String? {
        guard let norms = activityNorms else { return nil }
        let todayIssues = allBehaviorEvents
            .filter { Calendar.current.isDateInToday($0.date) }
            .flatMap { $0.issues }
            .filter { $0 != .noIssues }
        return DogStateService.coachingInsight(
            activities: todayActivities,
            norms: norms,
            issues: todayIssues,
            dogName: dogProfile?.name ?? "your dog"
        )
    }

    private var isFirstActivityToday: Bool {
        todayActivities.filter { $0.completed }.count == 1
    }

    // MARK: - Behavioral progress

    func processProgress() {
        guard dogProfile != nil else { return }
        let todayEvents = allBehaviorEvents.filter { Calendar.current.isDateInToday($0.date) }
        let todayFeedbacks = recentFeedback.filter { Calendar.current.isDateInToday($0.date) }
        behaviorProgress = ProgressEngine.process(
            current: behaviorProgress,
            activities: todayActivities,
            events: todayEvents,
            feedbacks: todayFeedbacks,
            norms: activityNorms
        )
        userDefaultsManager.saveBehaviorProgress(behaviorProgress)
    }

    // MARK: - Context engine (current action)

    var currentContext: ContextEngine.CurrentContext {
        ContextEngine.compute(
            dogState: dogState,
            dogProfile: dogProfile,
            dailyRoutine: dailyRoutine,
            currentPlan: currentPlan,
            toiletPrediction: toiletPrediction,
            todayActivities: todayActivities,
            norms: activityNorms
        )
    }

    var progressInsight: String? {
        guard let name = dogProfile?.name else { return nil }
        return AIProgressInterpreter.dailyInsight(
            progress: behaviorProgress,
            dogName: name,
            activities: todayActivities
        )
    }

    var proactiveProgressInsight: String? {
        guard let name = dogProfile?.name else { return nil }
        return AIProgressInterpreter.proactiveInsight(progress: behaviorProgress, dogName: name)
    }

    private func awardPoints(_ points: Int) {
        userProgress.totalPoints += points
        userProgress.level = ScoringService.levelFor(points: userProgress.totalPoints)
    }

    private func saveUserProgress() {
        userDefaultsManager.saveUserProgress(userProgress)
    }

    private func updateChallenges() {
        let allActivities = ActivityTrackingService.shared.loadAll()
        let allEvents     = BehaviorTrackingService.shared.loadAll()
        let awarded = ChallengeService.update(
            challenges: &challenges,
            activities: allActivities,
            behaviorEvents: allEvents,
            currentStreak: userProgress.currentStreak
        )
        userDefaultsManager.saveChallenges(challenges)

        // Award points for newly completed challenges
        for challenge in awarded {
            awardPoints(challenge.type.pointReward)
        }
        if !awarded.isEmpty { saveUserProgress() }
    }
}
