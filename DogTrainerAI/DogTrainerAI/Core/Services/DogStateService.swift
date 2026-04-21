import Foundation

struct DogStateService {

    static func compute(
        todayActivities: [DailyActivity],
        todayEvents: [BehaviorEvent],
        recentFeedback: [TaskFeedback],
        dogProfile: DogProfile?,
        previousState: DogState
    ) -> DogState {
        let norms = dogProfile.map { NormCalculationService.norms(for: $0) } ?? defaultNorms

        // Norm-based walk completion
        let walkRatio = NormCalculationService.walkCompletion(activities: todayActivities, norms: norms)

        // Overall activity norm completion
        let normCompletion = NormCalculationService.overallCompletion(activities: todayActivities, norms: norms)

        // Walk quality bonus
        let walks = todayActivities.filter { $0.type == .walking && $0.completed }
        let calmWalks = walks.filter { $0.walkQuality == .calm }.count
        let qualityBonus = walks.isEmpty ? 0.0 : Double(calmWalks) / Double(walks.count) * 0.15

        // Training overload check: penalise if user trained > 2× max session length
        let trainingMin = todayActivities.filter { $0.type == .training && $0.completed }
            .reduce(0) { $0 + $1.durationMinutes }
        let maxTrainingMin = norms.trainingMinPerSession * norms.trainingSessionsPerDay
        let overtrainPenalty = trainingMin > maxTrainingMin * 2 ? 0.15 : 0.0

        // Behavior issue penalty
        let issueCount = todayEvents.reduce(0) { total, event in
            total + event.issues.filter { $0 != .noIssues }.count
        }
        let issuePenalty = min(Double(issueCount) * 0.05, 0.25)

        // Task feedback quality
        let successRate: Double
        if recentFeedback.isEmpty {
            successRate = 0.5
        } else {
            let successes = recentFeedback.filter { $0.result == .success }.count
            successRate = Double(successes) / Double(recentFeedback.count)
        }

        // Compute state dimensions (clamped to [0.1, 1.0])
        let energy    = clamp(1.0 - walkRatio * 0.5 - normCompletion * 0.2)
        let calmness  = clamp(walkRatio * 0.4 + qualityBonus + normCompletion * 0.2
                              - issuePenalty - overtrainPenalty)
        let satisfact = clamp(normCompletion * 0.5 + successRate * 0.3
                              + walkRatio * 0.15 - issuePenalty * 0.5)
        let stability = clamp(previousState.behaviorStability * 0.75 + successRate * 0.15
                              + normCompletion * 0.1 - issuePenalty - overtrainPenalty * 0.5)
        let focus     = clamp(successRate * 0.5 + walkRatio * 0.25
                              + normCompletion * 0.2 - issuePenalty * 0.5 - overtrainPenalty)

        return DogState(
            energyLevel: energy,
            calmness: calmness,
            satisfaction: satisfact,
            behaviorStability: stability,
            focusOnOwner: focus,
            lastUpdated: Date()
        )
    }

    // MARK: - Norm-aware coaching tips

    /// Returns a coaching message based on actual vs norm — used in DailySummary and AI coaching.
    static func coachingInsight(
        activities: [DailyActivity],
        norms: ActivityNorms,
        issues: [BehaviorEvent.BehaviorIssue],
        dogName: String
    ) -> String {
        let walkComp = NormCalculationService.walkCompletion(activities: activities, norms: norms)
        let playComp = NormCalculationService.playCompletion(activities: activities, norms: norms)
        let trainingMin = activities.filter { $0.type == .training && $0.completed }
            .reduce(0) { $0 + $1.durationMinutes }
        let maxTraining = norms.trainingMinPerSession * norms.trainingSessionsPerDay

        if walkComp < 0.5 {
            return "\(dogName) only got \(Int(walkComp * 100))% of their recommended walk time today. Under-exercised dogs tend to be restless and harder to train. Aim for \(norms.walkMinPerDay) minutes tomorrow."
        }
        if walkComp >= 1.0 && issues.contains(.leashPulling) {
            return "Great walk duration! The leash pulling you reported suggests \(dogName) needs more leash-manners practice — try 5-minute loose-leash drills at the start of each walk."
        }
        if trainingMin > maxTraining * 2 {
            return "You trained for \(trainingMin) minutes today — more than double the recommended max of \(maxTraining) minutes. Overstimulation leads to frustration. Shorter, more frequent sessions work better."
        }
        if playComp < 0.5 {
            return "\(dogName) got less than half their recommended play time. Play is how dogs process stress and bond with their owner. Even 10 minutes of focused fetch helps."
        }
        if issues.contains(.barking) {
            return "Barking detected today. Identify the trigger first — reactive barking is usually distance-based. Create more space from the trigger before expecting calm behavior."
        }
        if issues.contains(.ignoringOwner) {
            return "\(dogName) was ignoring commands today. This is often a sign of overstimulation or insufficient exercise. Make sure physical needs are met before training sessions."
        }
        return "Good day overall. Keep the routine consistent — predictability is the foundation of a calm, well-behaved dog."
    }

    private static let defaultNorms = ActivityNorms(
        walkMinPerDay: 30, walkDistanceKmPerDay: 2.0, walkSessionsPerDay: 2,
        playMinPerDay: 20, playSessionsPerDay: 2,
        trainingMinPerSession: 10, trainingSessionsPerDay: 2,
        feedingsPerDay: 2
    )

    private static func clamp(_ v: Double) -> Double { min(max(v, 0.1), 1.0) }
}
