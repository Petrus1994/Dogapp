import SwiftUI
import Combine
import StoreKit

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

    // MARK: - Avatar system
    @Published var currentAvatarState: DogAvatarState = .calm
    @Published var avatarStateReason: String?
    @Published var avatarRecommendedAction: String?
    @Published var showAvatarSetupPrompt: Bool = false

    // MARK: - Voice → Chat handoff
    @Published var pendingChatInput: String? = nil

    // MARK: - Subscription gate
    var isPaidSubscriber: Bool { SubscriptionService.shared.status == .premium }

    // Multi-dog Phase 2: persists all dog profiles; switching reloads all dog-specific state.
    var dogs: [DogEntity] {
        var entities: [DogEntity] = []
        let sub = SubscriptionService.shared
        guard let userId = currentUser?.id else { return entities }
        let storedProfiles = userDefaultsManager.loadAllDogProfiles()
        let profilesToShow = storedProfiles.isEmpty ? [dogProfile].compactMap { $0 } : storedProfiles
        for profile in profilesToShow {
            let dogStatus = sub.subscriptionStatus(for: profile.id)
            entities.append(DogEntity.from(profile, userId: userId, subscriptionStatus: dogStatus))
        }
        if let profile = futureDogProfile {
            let name = profile.preferredBreed ?? "Future Dog"
            let dogStatus = sub.subscriptionStatus(for: profile.id)
            entities.append(DogEntity.fromFuture(profile, userId: userId, name: name, subscriptionStatus: dogStatus))
        }
        return entities
    }

    var activeDogId: String? { dogProfile?.id }

    // MARK: - Future Dog Mode
    @Published var futureDogProfile: FutureDogProfile?
    @Published var learningProfile: UserLearningProfile?
    @Published var showTransformation: Bool = false

    var isFutureDogMode: Bool { futureDogProfile != nil && dogProfile == nil }

    // MARK: - Referral system
    @Published var referralInfo: ReferralInfo?
    @Published var showReferralPrompt: Bool = false       // inline prompt trigger
    @Published var pendingReferralCode: String?           // code from deep link, applied post-login

    private let sessionManager = SessionManager()
    private let userDefaultsManager = UserDefaultsManager.shared
    private var subscriptionCancellable: AnyCancellable?

    init() {
        subscriptionCancellable = SubscriptionService.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
        Task { await bootstrap() }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        if sessionManager.isAuthenticated,
           let user = userDefaultsManager.loadUser() {
            currentUser = user

            // Multi-dog: resolve active dog from persisted map or legacy single slot
            let allProfiles = userDefaultsManager.loadAllDogProfiles()
            let savedActiveDogId = userDefaultsManager.loadActiveDogId()
            if let profile = allProfiles.first(where: { $0.id == savedActiveDogId }) ?? allProfiles.first {
                dogProfile = profile
            } else if let legacy = userDefaultsManager.loadDogProfile() {
                dogProfile = legacy
                userDefaultsManager.upsertDogProfile(legacy)
                userDefaultsManager.saveActiveDogId(legacy.id)
            }

            if let profile = dogProfile {
                configureDogServices(dogId: profile.id)
                currentPlan = userDefaultsManager.loadPlan(forDogId: profile.id) ?? userDefaultsManager.loadPlan()
            } else {
                currentPlan = userDefaultsManager.loadPlan()
            }

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
            refreshReferralInfo()
            await refreshFutureDogState()

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
        Task { await SubscriptionService.shared.start() }
        applyPendingReferralCode()
        refreshReferralInfo()
    }

    func completeOnboarding(plan: Plan) {
        currentPlan = plan
        currentUser?.onboardingCompleted = true
        if let user = currentUser { userDefaultsManager.saveUser(user) }
        if let profile = dogProfile {
            userDefaultsManager.saveDogProfile(profile)
            userDefaultsManager.upsertDogProfile(profile)
            userDefaultsManager.saveActiveDogId(profile.id)
            userDefaultsManager.savePlan(plan, forDogId: profile.id)
            configureDogServices(dogId: profile.id)
            BackendSyncService.shared.syncDogProfile(profile)
        } else {
            userDefaultsManager.savePlan(plan)
        }
        flow = .main

        // Schedule recurring weekly summary notification
        scheduleWeeklySummaryNotification()

        // Prompt avatar setup if not already generated
        if dogProfile?.avatarGenerationStatus == .none || dogProfile?.avatarGenerationStatus == .failed {
            showAvatarSetupPrompt = true
        }
    }

    // MARK: - Avatar state sync (called from refreshDogState)

    func refreshAvatarState() {
        let state = DogAvatarState.from(dogState)
        currentAvatarState = state
        guard let dogId = UserDefaultsManager.shared.loadBackendDogId() else { return }
        Task {
            let result = try? await AvatarAPIClient.shared.reportAvatarState(
                dogId: dogId,
                dogState: DogStateSyncBody(
                    energyLevel:             dogState.energyLevel,
                    hungerLevel:             dogState.hungerLevel,
                    satisfaction:            dogState.satisfaction,
                    calmness:                dogState.calmness,
                    focusOnOwner:            dogState.focusOnOwner,
                    recentActivityCompleted: todayActivities.contains { $0.completed },
                    missedActivitiesCount:   todayActivities.filter { !$0.completed }.count,
                    recentTrainingSuccess:   nil,
                    recentBehaviorIssues:    weeklyBehaviorEvents.filter { $0.hasRealIssues }.count,
                    streakActive:            userProgress.currentStreak > 0
                )
            )
            if let result {
                currentAvatarState       = DogAvatarState.from(backendState: result.state)
                avatarStateReason        = result.stateReason
                avatarRecommendedAction  = result.recommendedCopy
            }
        }
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
        ActivityChatViewModel.clearAll()
        DogMemory.clear()
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
            // Trigger referral prompt after every 3rd success (show once per session)
            if userProgress.consecutiveSuccessCount % 3 == 0 {
                showReferralPrompt = true
            }
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

        // Streak (check if a new shield is earned)
        let shieldsBefore = userProgress.streakShields
        StreakService.markActiveToday(progress: &userProgress)
        if userProgress.streakShields > shieldsBefore {
            ageProgressionAnnouncement = "🛡️ Streak shield earned! You've hit a \(userProgress.currentStreak)-day streak. Your shield is banked for emergencies."
        }

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

        // Schedule activity follow-up notification (Part 8 — smart follow-up)
        if let name = dogProfile?.name {
            Task {
                await NotificationTimingService.shared.scheduleActivityFollowUp(
                    activityType: activity.type, dogName: name
                )
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
            userDefaultsManager.upsertDogProfile(updatedProfile)
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
        scheduleSmartDailyNudge()
        refreshAvatarState()
    }

    // MARK: - Helpers

    var antiCheatMessage: String? {
        ScoringService.antiCheatMessage(for: userProgress)
    }

    // True only after the user has logged at least one activity today
    var hasTodayActivityData: Bool {
        !todayActivities.isEmpty
    }

    // True when all 4 activity types are fully completed (at or above norm targets)
    var completedFullDayToday: Bool {
        guard let norms = activityNorms else {
            let completedTypes = Set(todayActivities.filter { $0.completed }.map { $0.type })
            return completedTypes.count == DailyActivity.ActivityType.allCases.count
        }
        return NormCalculationService.walkCompletion(activities: todayActivities, norms: norms) >= 1.0
            && NormCalculationService.playCompletion(activities: todayActivities, norms: norms) >= 1.0
            && NormCalculationService.feedingCompletion(activities: todayActivities, norms: norms) >= 1.0
            && NormCalculationService.trainingCompletion(activities: todayActivities, norms: norms) >= 1.0
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

    // MARK: - Empathy mode (too many tough sessions → softer coaching tone)

    var empathyModeActive: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let toughCount = allBehaviorEvents
            .filter { $0.date >= sevenDaysAgo && $0.hasRealIssues }
            .count
        return toughCount >= 4
    }

    var empathyMessage: String? {
        guard empathyModeActive, let name = dogProfile?.name else { return nil }
        let toughCount = allBehaviorEvents
            .filter {
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                return $0.date >= sevenDaysAgo && $0.hasRealIssues
            }.count
        if toughCount >= 7 {
            return "It's been a hard week. That's okay — showing up consistently matters more than perfection. \(name) is still learning."
        }
        return "Some sessions are tougher than others. Every walk and every feeding still counts for \(name)'s development."
    }

    // MARK: - Weekly summary data

    var weeklyActivities: [DailyActivity] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return ActivityTrackingService.shared.loadAll()
            .filter { $0.date >= sevenDaysAgo && $0.completed }
    }

    var allActivities: [DailyActivity] {
        ActivityTrackingService.shared.loadAll().filter { $0.completed }
    }

    var weeklyBehaviorEvents: [BehaviorEvent] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return allBehaviorEvents.filter { $0.date >= sevenDaysAgo }
    }

    // MARK: - Smart proactive notifications

    func scheduleSmartDailyNudge() {
        guard let profile = dogProfile else { return }
        Task {
            await NotificationTimingService.shared.scheduleSmartDailyNudge(
                dogState: dogState, dogName: profile.name)
        }
    }

    func scheduleWeeklySummaryNotification() {
        guard let profile = dogProfile else { return }
        Task {
            await NotificationTimingService.shared.scheduleWeeklySummaryNotification(dogName: profile.name)
        }
    }

    // MARK: - Future Dog

    func refreshFutureDogState() async {
        guard dogProfile == nil else { return }
        futureDogProfile = try? await FutureDogAPIClient.shared.fetchProfile()
        if futureDogProfile != nil {
            learningProfile = try? await FutureDogAPIClient.shared.fetchLearning()
        }
    }

    func completeFutureDogOnboarding(profile: FutureDogProfile) {
        futureDogProfile = profile
        currentUser?.scenarioType = .futureDog
        if let user = currentUser { userDefaultsManager.saveUser(user) }
        flow = .main
    }

    // MARK: - Referral

    func refreshReferralInfo() {
        Task {
            referralInfo = try? await ReferralAPIClient.shared.fetchMyInfo()
        }
    }

    func applyPendingReferralCode() {
        guard let code = pendingReferralCode else { return }
        pendingReferralCode = nil
        Task {
            try? await ReferralAPIClient.shared.applyCode(code)
            refreshReferralInfo()
        }
    }

    // MARK: - Multi-dog Phase 2

    func dogProfile(for id: String) -> DogProfile? {
        userDefaultsManager.loadAllDogProfiles().first { $0.id == id }
    }

    private func configureDogServices(dogId: String) {
        ActivityTrackingService.shared.configure(dogId: dogId)
        BehaviorTrackingService.shared.configure(dogId: dogId)
        DogMemory.configure(dogId: dogId)
    }

    func switchActiveDog(to profile: DogProfile) {
        guard profile.id != dogProfile?.id else { return }
        dogProfile = profile
        userDefaultsManager.saveActiveDogId(profile.id)
        userDefaultsManager.saveDogProfile(profile)
        configureDogServices(dogId: profile.id)
        currentPlan       = userDefaultsManager.loadPlan(forDogId: profile.id) ?? userDefaultsManager.loadPlan()
        todayActivities   = ActivityTrackingService.shared.todayActivities()
        allBehaviorEvents = BehaviorTrackingService.shared.loadAll()
        behaviorProgress  = userDefaultsManager.loadBehaviorProgress() ?? .initial
        refreshDogState()
        refreshDailyRoutine()
        refreshToiletState()
        BackendSyncService.shared.setBackendDogId(userDefaultsManager.loadBackendDogId())
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
