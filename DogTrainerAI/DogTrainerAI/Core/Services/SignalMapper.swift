import Foundation

struct SignalMapper {

    // MARK: - Public entry: compute raw daily signal per dimension from all day's data

    static func dailySignals(
        activities: [DailyActivity],
        events: [BehaviorEvent],
        feedbacks: [TaskFeedback],
        norms: ActivityNorms?
    ) -> [BehaviorDailySignal] {
        BehaviorDimension.allCases.compactMap { dimension in
            signal(for: dimension, activities: activities, events: events,
                   feedbacks: feedbacks, norms: norms)
        }
    }

    // MARK: - Per-dimension computation

    private static func signal(
        for dimension: BehaviorDimension,
        activities: [DailyActivity],
        events: [BehaviorEvent],
        feedbacks: [TaskFeedback],
        norms: ActivityNorms?
    ) -> BehaviorDailySignal? {
        var sources: [SignalSource] = []
        var base: Double = 50

        switch dimension {

        // ─────────────────────────────────────────────────────────────────
        case .foodBehavior:
            let feedings = activities.filter { $0.type == .feeding && $0.completed }
            guard !feedings.isEmpty else { return nil } // no feeding → no signal

            base = 60
            sources.append(SignalSource(description: "Feeding logged", delta: 10))

            // Calm feeding (no food issues in any event linked to feeding)
            let foodIssues = events.flatMap { $0.issues }.filter {
                $0 == .beggingForFood || $0 == .pickingFoodFromGround
            }
            if foodIssues.isEmpty {
                base += 15
                sources.append(SignalSource(description: "No food issues reported", delta: 15))
            }
            for _ in foodIssues.filter({ $0 == .beggingForFood }) {
                base -= 25
                sources.append(SignalSource(description: "Issue: begging for food", delta: -25))
            }
            for _ in foodIssues.filter({ $0 == .pickingFoodFromGround }) {
                base -= 25
                sources.append(SignalSource(description: "Issue: picking food from ground", delta: -25))
            }
            // Notes show engagement
            if feedings.contains(where: { !$0.notes.isEmpty }) {
                base += 8
                sources.append(SignalSource(description: "Notes added to feeding", delta: 8))
            }
            // Multiple feedings = structured routine (good)
            if feedings.count >= 2 {
                base += 7
                sources.append(SignalSource(description: "Structured feeding schedule", delta: 7))
            }

        // ─────────────────────────────────────────────────────────────────
        case .activityExcitement:
            let walks   = activities.filter { $0.type == .walking && $0.completed }
            let plays   = activities.filter { $0.type == .playing && $0.completed }
            let trains  = activities.filter { $0.type == .training && $0.completed }

            // Needs at least one activity to generate a signal
            guard !walks.isEmpty || !plays.isEmpty || !trains.isEmpty else {
                // No activity at all — signal is very low (can indicate understimulation)
                // Only emit if it's late in the day (after noon) — otherwise skip
                let hour = Calendar.current.component(.hour, from: Date())
                guard hour >= 14 else { return nil }
                return BehaviorDailySignal(
                    dimension: .activityExcitement,
                    rawSignal: 25,
                    sources: [SignalSource(description: "No activity logged today", delta: -25)],
                    date: Date()
                )
            }

            base = 40

            // Walks
            for walk in walks {
                base += 18
                sources.append(SignalSource(description: "Walk logged", delta: 18))
                if walk.walkQuality == .calm {
                    base += 12
                    sources.append(SignalSource(description: "Calm walk quality", delta: 12))
                } else if walk.walkQuality == .pulling {
                    base -= 8
                    sources.append(SignalSource(description: "Walk quality: pulling", delta: -8))
                }
                // Duration vs norm
                if let normMin = norms?.walkMinPerDay {
                    let fraction = Double(walk.durationMinutes) / Double(max(1, normMin))
                    if fraction >= 1.0 {
                        base += 10
                        sources.append(SignalSource(description: "Walk met daily norm", delta: 10))
                    } else if fraction < 0.5 {
                        base -= 8
                        sources.append(SignalSource(description: "Walk duration below 50% of norm", delta: -8))
                    }
                }
            }

            // Play sessions
            for play in plays {
                base += 10
                sources.append(SignalSource(description: "Play session logged", delta: 10))
                // Structured play is better than chaotic free run
                if play.playActivity == .freePark && plays.count == 1 && walks.isEmpty {
                    base -= 5
                    sources.append(SignalSource(description: "Unstructured free play only", delta: -5))
                }
                if play.playActivity == .puzzle || play.playActivity == .hiddenTreats {
                    base += 5
                    sources.append(SignalSource(description: "Mental play (puzzle/scent)", delta: 5))
                }
            }

            // Training contributes to excitement regulation
            if !trains.isEmpty {
                base += 8
                sources.append(SignalSource(description: "Training session (mental regulation)", delta: 8))
            }

            // Issue penalties
            let excIssues = events.flatMap { $0.issues }
            for issue in excIssues {
                switch issue {
                case .overexcitement:
                    base -= 20
                    sources.append(SignalSource(description: "Issue: overexcitement", delta: -20))
                case .leashPulling:
                    base -= 15
                    sources.append(SignalSource(description: "Issue: leash pulling", delta: -15))
                case .jumpingOnPeople:
                    base -= 10
                    sources.append(SignalSource(description: "Issue: jumping on people", delta: -10))
                case .chewingObjects:
                    base -= 5
                    sources.append(SignalSource(description: "Issue: chewing objects (understimulated)", delta: -5))
                case .whiningOrHowling:
                    base -= 5
                    sources.append(SignalSource(description: "Issue: whining/howling", delta: -5))
                default: break
                }
            }

            // Clean session bonus
            let hasExcitementIssues = excIssues.contains(where: {
                $0 == .overexcitement || $0 == .leashPulling
            })
            if !hasExcitementIssues && (!walks.isEmpty || !plays.isEmpty) {
                base += 8
                sources.append(SignalSource(description: "No excitement issues during activity", delta: 8))
            }

        // ─────────────────────────────────────────────────────────────────
        case .ownerContact:
            let trains   = activities.filter { $0.type == .training && $0.completed }
            let walks    = activities.filter { $0.type == .walking && $0.completed }
            let plays    = activities.filter { $0.type == .playing && $0.completed }

            guard !trains.isEmpty || !feedbacks.isEmpty || !walks.isEmpty || !plays.isEmpty else {
                return nil
            }

            base = 50

            // Training is the primary signal
            if !trains.isEmpty {
                base += 20
                sources.append(SignalSource(description: "Training session logged", delta: 20))
            }

            // Feedback from tasks
            for feedback in feedbacks {
                switch feedback.result {
                case .success:
                    base += 18
                    sources.append(SignalSource(description: "Task feedback: success", delta: 18))
                case .partial:
                    base += 6
                    sources.append(SignalSource(description: "Task feedback: partial", delta: 6))
                case .failed:
                    base -= 5
                    sources.append(SignalSource(description: "Task feedback: failed", delta: -5))
                }
            }

            // Walks and play build bond
            if !walks.isEmpty {
                base += 5
                sources.append(SignalSource(description: "Walk (owner bonding)", delta: 5))
            }
            if !plays.isEmpty {
                base += 8
                sources.append(SignalSource(description: "Play (owner engagement)", delta: 8))
            }

            // Negative contact issues
            let contactIssues = events.flatMap { $0.issues }
            for issue in contactIssues {
                switch issue {
                case .ignoringOwner:
                    base -= 25
                    sources.append(SignalSource(description: "Issue: ignoring owner", delta: -25))
                case .notResponding:
                    base -= 20
                    sources.append(SignalSource(description: "Issue: not responding to commands", delta: -20))
                default: break
                }
            }

        // ─────────────────────────────────────────────────────────────────
        case .socialization:
            let walks = activities.filter { $0.type == .walking && $0.completed }

            // Need either a walk or social-related behavior events
            let socialIssueSet: Set<BehaviorEvent.BehaviorIssue> = [
                .reactingToDogs, .reactingToPeople, .fearReactions,
                .barking, .aggression, .reactingToNoises, .jumpingOnPeople
            ]
            let allIssues = events.flatMap { $0.issues }
            let socialIssues = allIssues.filter { socialIssueSet.contains($0) }
            guard !walks.isEmpty || !socialIssues.isEmpty else { return nil }

            base = 50

            for walk in walks {
                base += 15
                sources.append(SignalSource(description: "Walk (social exposure)", delta: 15))
                if walk.walkQuality == .calm {
                    base += 10
                    sources.append(SignalSource(description: "Calm during walk", delta: 10))
                }
            }

            for issue in socialIssues {
                switch issue {
                case .aggression:
                    base -= 30
                    sources.append(SignalSource(description: "Issue: aggression", delta: -30))
                case .fearReactions:
                    base -= 25
                    sources.append(SignalSource(description: "Issue: fear reactions", delta: -25))
                case .reactingToDogs:
                    base -= 20
                    sources.append(SignalSource(description: "Issue: reacting to dogs", delta: -20))
                case .reactingToPeople:
                    base -= 20
                    sources.append(SignalSource(description: "Issue: reacting to people", delta: -20))
                case .barking:
                    base -= 15
                    sources.append(SignalSource(description: "Issue: barking", delta: -15))
                case .reactingToNoises:
                    base -= 10
                    sources.append(SignalSource(description: "Issue: reacting to noises", delta: -10))
                case .jumpingOnPeople:
                    base -= 10
                    sources.append(SignalSource(description: "Issue: jumping on people", delta: -10))
                default: break
                }
            }

            // Bonus: calm walk with no social issues
            if !walks.isEmpty && socialIssues.isEmpty {
                base += 15
                sources.append(SignalSource(description: "No social issues during walk", delta: 15))
            }
        }

        let clamped = min(max(base, 0), 100)
        return BehaviorDailySignal(
            dimension: dimension,
            rawSignal: clamped,
            sources: sources,
            date: Date()
        )
    }
}
