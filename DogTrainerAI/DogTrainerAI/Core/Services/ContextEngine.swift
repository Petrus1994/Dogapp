import Foundation

struct ContextEngine {

    // MARK: - Output types

    struct CurrentContext {
        var stateEmoji: String
        var stateLabel: String
        var stateSublabel: String?
        var primaryAction: Action
        var nextAction: Action?
        var urgency: Urgency
        var isResting: Bool = false   // current routine phase is a sleep/rest window
        var restEndsAt: Date? = nil   // approximate end of rest window

        enum Urgency { case high, normal, low }
    }

    struct Action: Equatable {
        var icon: String
        var title: String
        var subtitle: String
        var rationale: String
        var ctaLabel: String
        var type: ActionType
        var timingHint: String? = nil       // e.g. "~20–30 min" — shown in card
        var methodologyTip: String? = nil   // 1 short methodology line

        static func == (lhs: Action, rhs: Action) -> Bool { lhs.type == rhs.type }
    }

    enum ActionType: Equatable {
        case toilet
        case activity(DailyActivity.ActivityType)
        case rest
        case reviewTask(String)
        case balanced

        static func == (lhs: ActionType, rhs: ActionType) -> Bool {
            switch (lhs, rhs) {
            case (.toilet, .toilet):         return true
            case (.rest, .rest):             return true
            case (.balanced, .balanced):     return true
            case (.activity(let a), .activity(let b)): return a == b
            case (.reviewTask(let a), .reviewTask(let b)): return a == b
            default: return false
            }
        }
    }

    // MARK: - Main computation

    static func compute(
        dogState: DogState,
        dogProfile: DogProfile?,
        dailyRoutine: DailyRoutine?,
        currentPlan: Plan?,
        toiletPrediction: ToiletPredictionService.ToiletPrediction?,
        todayActivities: [DailyActivity],
        norms: ActivityNorms?,
        now: Date = Date()
    ) -> CurrentContext {
        let name = dogProfile?.name ?? "your dog"
        let need = dogState.primaryNeed

        // 0. No data yet — first launch or fresh day, no activities logged
        if todayActivities.isEmpty {
            let walkMins = norms.map { $0.walkMinPerDay / max(1, $0.walkSessionsPerDay) } ?? 20
            return CurrentContext(
                stateEmoji: "👋",
                stateLabel: "Start the day",
                stateSublabel: "Log your first activity to get coaching.",
                primaryAction: Action(
                    icon: "🦮",
                    title: "Take \(name) for a walk",
                    subtitle: "Walk · ~\(walkMins) min",
                    rationale: "Start the day with a walk — it burns energy and sets a calm tone for the rest of the day.",
                    ctaLabel: "Start",
                    type: .activity(.walking),
                    timingHint: timingHint(for: .walking, norms: norms),
                    methodologyTip: methodologyTip(for: .walking)
                ),
                nextAction: Action(
                    icon: "🍖",
                    title: "Feeding time",
                    subtitle: "After walk",
                    rationale: "Feed after exercise to reinforce calm behaviour around food.",
                    ctaLabel: "Log feeding",
                    type: .activity(.feeding),
                    timingHint: timingHint(for: .feeding, norms: norms),
                    methodologyTip: methodologyTip(for: .feeding)
                ),
                urgency: .low
            )
        }

        // 1. Critical toilet urgency — always overrides
        if dogState.toiletUrgency > 0.75 {
            return CurrentContext(
                stateEmoji: "🐶",
                stateLabel: "Needs to go outside",
                stateSublabel: "Toilet urgency is high",
                primaryAction: Action(
                    icon: "🌿",
                    title: "Take \(name) outside",
                    subtitle: "Toilet break · ~5 min",
                    rationale: "High urgency detected. Taking \(name) out now prevents accidents and builds the outdoor toilet habit.",
                    ctaLabel: "Log toilet",
                    type: .toilet
                ),
                nextAction: previewNextRoutineAction(from: dailyRoutine, skip: .toilet, name: name, norms: norms),
                urgency: .high
            )
        }

        // 2. Current routine cycle is a sleep / rest phase → rest mode
        if let sleepCycle = dailyRoutine?.currentCycle, sleepCycle.phase == .sleep, !sleepCycle.isCompleted {
            let restEndsAt = sleepCycle.suggestedTime.addingTimeInterval(
                TimeInterval(sleepCycle.expectedDurationMinutes * 60))
            let minutesLeft = max(0, Int(restEndsAt.timeIntervalSince(now) / 60))
            let restSubtitle = minutesLeft > 5
                ? "Rest window · ~\(minutesLeft) min remaining"
                : "Rest window · finishing soon"
            return CurrentContext(
                stateEmoji: "😴",
                stateLabel: "Resting now",
                stateSublabel: "Current needs are covered — rest is part of the plan.",
                primaryAction: Action(
                    icon: "😴",
                    title: "\(name) is resting",
                    subtitle: restSubtitle,
                    rationale: "Rest is as important as activity. Puppies and young dogs need structured downtime to consolidate learning and recover. Avoid stimulation during this window.",
                    ctaLabel: "Got it",
                    type: .rest,
                    methodologyTip: "Avoid stimulation, play, or training during rest windows."
                ),
                nextAction: previewNextRoutineAction(from: dailyRoutine, skip: .sleep, name: name, norms: norms),
                urgency: .low,
                isResting: true,
                restEndsAt: restEndsAt
            )
        }

        // 3. Moderate toilet urgency — surface as next action
        if dogState.toiletUrgency > 0.5 {
            let (emoji, label, sublabel) = stateDescription(need: need, dogState: dogState)
            return CurrentContext(
                stateEmoji: emoji,
                stateLabel: label,
                stateSublabel: sublabel,
                primaryAction: routineOrDefaultAction(
                    routine: dailyRoutine, plan: currentPlan, dogState: dogState,
                    activities: todayActivities, norms: norms, name: name),
                nextAction: Action(
                    icon: "🌿",
                    title: "Toilet break soon",
                    subtitle: "~\(Int(dogState.toiletUrgency * 30))–\(Int(dogState.toiletUrgency * 45)) min",
                    rationale: "Getting \(name) outside before urgency peaks avoids accidents.",
                    ctaLabel: "Log toilet",
                    type: .toilet
                ),
                urgency: .normal
            )
        }

        // 4. Follow daily routine if a non-sleep cycle is due
        if let cycle = dailyRoutine?.currentCycle,
           cycle.phase != .sleep,
           !cycle.isCompleted, !cycle.skipped {
            let action = routineCycleAction(cycle: cycle, name: name, norms: norms)
            let next   = previewNextRoutineAction(from: dailyRoutine, skip: cycle.phase, name: name, norms: norms)
            let (emoji, label, sublabel) = stateDescription(need: need, dogState: dogState)
            return CurrentContext(
                stateEmoji: emoji,
                stateLabel: label,
                stateSublabel: sublabel,
                primaryAction: action,
                nextAction: next,
                urgency: cycle.isPast ? .high : .normal
            )
        }

        // 5. Pending training task (prioritise when training not yet done)
        let trainingDone = todayActivities.contains { $0.type == .training && $0.completed }
        if let task = pendingTodayTask(from: currentPlan), !trainingDone {
            let (emoji, label, sublabel) = stateDescription(need: need, dogState: dogState)
            return CurrentContext(
                stateEmoji: emoji,
                stateLabel: label,
                stateSublabel: sublabel,
                primaryAction: Action(
                    icon: task.category.icon,
                    title: "Practice: \(task.title)",
                    subtitle: "Training · ~\(norms?.trainingMinPerSession ?? 10) min",
                    rationale: task.description,
                    ctaLabel: "Start",
                    type: .reviewTask(task.id),
                    timingHint: timingHint(for: .training, norms: norms),
                    methodologyTip: methodologyTip(for: .training)
                ),
                nextAction: previewNextRoutineAction(from: dailyRoutine, skip: nil, name: name, norms: norms),
                urgency: .normal
            )
        }

        // 6. Activity need (under-stimulated)
        if need == .activity || need == .play {
            let (emoji, label, sublabel) = stateDescription(need: need, dogState: dogState)
            let actType: DailyActivity.ActivityType = need == .play ? .playing : .walking
            return CurrentContext(
                stateEmoji: emoji,
                stateLabel: label,
                stateSublabel: sublabel,
                primaryAction: activityAction(type: actType, name: name, norms: norms),
                nextAction: previewNextRoutineAction(from: dailyRoutine, skip: nil, name: name, norms: norms),
                urgency: dogState.energyLevel > 0.75 ? .high : .normal
            )
        }

        // 7. Feeding due
        if need == .feeding {
            let (emoji, label, sublabel) = stateDescription(need: need, dogState: dogState)
            return CurrentContext(
                stateEmoji: emoji,
                stateLabel: label,
                stateSublabel: sublabel,
                primaryAction: activityAction(type: .feeding, name: name, norms: norms),
                nextAction: previewNextRoutineAction(from: dailyRoutine, skip: nil, name: name, norms: norms),
                urgency: .normal
            )
        }

        // 8. Calm / rest need / balanced
        let (emoji, label, sublabel) = stateDescription(need: need, dogState: dogState, activities: todayActivities, norms: norms)
        let primary: Action
        if need == .rest {
            primary = Action(
                icon: "😴",
                title: "Let \(name) rest",
                subtitle: "Low energy after activity",
                rationale: "After activity \(name) needs calm time to recover. Avoid stimulation — just quiet presence.",
                ctaLabel: "Got it",
                type: .rest,
                methodologyTip: "Avoid stimulation, play, or training during rest windows."
            )
        } else {
            primary = Action(
                icon: "✨",
                title: "\(name) is doing well",
                subtitle: "Routine is on track",
                rationale: "Energy, mood, and routine are in good shape. Stay consistent.",
                ctaLabel: "View summary",
                type: .balanced
            )
        }

        return CurrentContext(
            stateEmoji: emoji,
            stateLabel: label,
            stateSublabel: sublabel,
            primaryAction: primary,
            nextAction: previewNextRoutineAction(from: dailyRoutine, skip: nil, name: name, norms: norms),
            urgency: .low
        )
    }

    // MARK: - Dog state label

    static func stateDescription(
        need: DogState.DogNeed,
        dogState: DogState,
        activities: [DailyActivity] = [],
        norms: ActivityNorms? = nil
    ) -> (emoji: String, label: String, sublabel: String?) {
        switch need {
        case .toilet:
            return ("🐶", "Needs to go outside", "Take outside soon")
        case .feeding:
            return ("🍖", "Feeding time", "Time for next meal")
        case .activity:
            if dogState.energyLevel > 0.75 {
                return ("⚡", "High energy", "Needs to burn off energy — walk or play helps")
            }
            return ("🦮", "Ready for activity", "Good time for a walk or play")
        case .play:
            return ("🎾", "Wants to play", "Low stimulation — a short play session helps")
        case .training:
            return ("🧠", "Ready to learn", "Calm and focused — ideal for a short training session")
        case .calm:
            return ("😮‍💨", "A bit unsettled", "Keep things calm and quiet for now")
        case .rest:
            return ("😴", "Tired — needs rest", "Let \(activities.isEmpty ? "them" : "them") recover. Avoid stimulation.")
        case .balanced:
            // Check if all norms are well met
            if let norms, !activities.isEmpty {
                let overall = NormCalculationService.overallCompletion(activities: activities, norms: norms)
                if overall >= 0.8 {
                    return ("✅", "Calm and Balanced", "Daily activities are well covered. Keep the routine consistent.")
                }
            }
            return ("✨", "Calm and Balanced", "Everything is on track. Rest is a healthy part of the routine.")
        }
    }

    // MARK: - Routine-driven actions

    private static func routineCycleAction(
        cycle: RoutineCycle,
        name: String,
        norms: ActivityNorms?
    ) -> Action {
        switch cycle.phase {
        case .toilet:
            return Action(
                icon: "🌿",
                title: "Take \(name) outside",
                subtitle: "Toilet break · ~5 min",
                rationale: "Regular toilet breaks at consistent times build the outdoor toilet habit faster.",
                ctaLabel: "Log toilet",
                type: .toilet
            )
        case .physical:
            let mins = norms.map { $0.walkMinPerDay / max(1, $0.walkSessionsPerDay) } ?? 20
            return Action(
                icon: "🦮",
                title: "Activity time",
                subtitle: "Walk or play · ~\(mins) min",
                rationale: "Physical activity balances energy and makes training and calm behaviour easier.",
                ctaLabel: "Start",
                type: .activity(.walking),
                timingHint: timingHint(for: .walking, norms: norms),
                methodologyTip: methodologyTip(for: .walking)
            )
        case .mental:
            return Action(
                icon: "🧠",
                title: "Short training session",
                subtitle: "Training · ~\(norms?.trainingMinPerSession ?? 10) min",
                rationale: "Mental exercise tires \(name) as much as physical exercise — and builds focus on you.",
                ctaLabel: "Start",
                type: .activity(.training),
                timingHint: timingHint(for: .training, norms: norms),
                methodologyTip: methodologyTip(for: .training)
            )
        case .feeding:
            return Action(
                icon: "🍖",
                title: "Feeding time",
                subtitle: "Meal · ~10 min",
                rationale: "Structured mealtimes reduce food-related anxiety and build calm eating habits.",
                ctaLabel: "Log feeding",
                type: .activity(.feeding),
                timingHint: timingHint(for: .feeding, norms: norms),
                methodologyTip: methodologyTip(for: .feeding)
            )
        case .sleep:
            return Action(
                icon: "😴",
                title: "Rest period",
                subtitle: "Quiet time",
                rationale: "Puppies and young dogs need structured rest. Avoid stimulation during rest periods.",
                ctaLabel: "Got it",
                type: .rest,
                methodologyTip: "Avoid stimulation, play, or training during rest windows."
            )
        }
    }

    /// Preview of the next routine action — shown as an upcoming hint (not yet actionable).
    private static func previewNextRoutineAction(
        from routine: DailyRoutine?,
        skip currentPhase: CyclePhase?,
        name: String,
        norms: ActivityNorms?
    ) -> Action? {
        guard let routine else { return nil }
        let next = routine.cycles.first {
            !$0.isCompleted && !$0.skipped && $0.phase != currentPhase
        }
        guard let next else { return nil }
        let subtitle = next.isPast ? "Overdue" : next.timeLabel
        return Action(
            icon: phaseIcon(next.phase),
            title: phaseShortTitle(next.phase, name: name),
            subtitle: subtitle,
            rationale: "",
            ctaLabel: "Start",
            type: actionType(for: next.phase),
            timingHint: next.phase.linkedActivityType.flatMap { timingHint(for: $0, norms: norms) }
        )
    }

    private static func routineOrDefaultAction(
        routine: DailyRoutine?,
        plan: Plan?,
        dogState: DogState,
        activities: [DailyActivity],
        norms: ActivityNorms?,
        name: String
    ) -> Action {
        if let cycle = routine?.currentCycle, cycle.phase != .sleep, !cycle.isCompleted {
            return routineCycleAction(cycle: cycle, name: name, norms: norms)
        }
        return activityAction(type: .walking, name: name, norms: norms)
    }

    // MARK: - Activity actions

    private static func activityAction(
        type: DailyActivity.ActivityType,
        name: String,
        norms: ActivityNorms?
    ) -> Action {
        let hint = timingHint(for: type, norms: norms)
        let tip  = methodologyTip(for: type)
        switch type {
        case .walking:
            let mins = norms.map { $0.walkMinPerDay / max(1, $0.walkSessionsPerDay) } ?? 20
            return Action(
                icon: "🦮", title: "Take \(name) for a walk",
                subtitle: "Walk · ~\(mins) min",
                rationale: "Regular walks reduce excess energy and overexcitement — making \(name) calmer at home.",
                ctaLabel: "Start", type: .activity(.walking),
                timingHint: hint, methodologyTip: tip
            )
        case .playing:
            let mins = norms.map { $0.playMinPerDay / max(1, $0.playSessionsPerDay) } ?? 15
            return Action(
                icon: "🎾", title: "Play session",
                subtitle: "Play · ~\(mins) min",
                rationale: "Structured play builds the bond with you and releases energy in a controlled way.",
                ctaLabel: "Start", type: .activity(.playing),
                timingHint: hint, methodologyTip: tip
            )
        case .training:
            return Action(
                icon: "🎯", title: "Training session",
                subtitle: "Training · ~\(norms?.trainingMinPerSession ?? 10) min",
                rationale: "Short, focused training builds attention and impulse control — the foundation of all good behaviour.",
                ctaLabel: "Start", type: .activity(.training),
                timingHint: hint, methodologyTip: tip
            )
        case .feeding:
            return Action(
                icon: "🍖", title: "Feeding time",
                subtitle: "Meal · ~10 min",
                rationale: "Structured mealtimes build calm food behaviour.",
                ctaLabel: "Log feeding", type: .activity(.feeding),
                timingHint: hint, methodologyTip: tip
            )
        }
    }

    // MARK: - Timing hints (short, shown in card)

    static func timingHint(for type: DailyActivity.ActivityType, norms: ActivityNorms?) -> String? {
        guard let norms else { return nil }
        switch type {
        case .walking:
            let perSession = norms.walkMinPerDay / max(1, norms.walkSessionsPerDay)
            return "~\(perSession)–\(perSession + 10) min"
        case .playing:
            let perSession = norms.playMinPerDay / max(1, norms.playSessionsPerDay)
            return "~\(perSession) min"
        case .training:
            return "~\(norms.trainingMinPerSession) min max"
        case .feeding:
            return "\(norms.feedingsPerDay)× per day"
        }
    }

    // MARK: - Methodology tips (1 short line per activity type)

    static func methodologyTip(for type: DailyActivity.ActivityType) -> String {
        switch type {
        case .walking:  return "Calm start, loose leash, make contact first."
        case .playing:  return "Keep it engaging but controlled. End while it's still fun."
        case .training: return "Short, clear, positive. Stop before frustration builds."
        case .feeding:  return "Calm state before food. No rushing or overexcitement."
        }
    }

    // MARK: - Plan helpers

    private static func pendingTodayTask(from plan: Plan?) -> TrainingTask? {
        plan?.todaysTasks.first { $0.status == .pending }
    }

    // MARK: - Phase helpers

    private static func phaseIcon(_ phase: CyclePhase) -> String {
        switch phase {
        case .toilet:   return "🌿"
        case .physical: return "🦮"
        case .mental:   return "🧠"
        case .feeding:  return "🍖"
        case .sleep:    return "😴"
        }
    }

    private static func phaseShortTitle(_ phase: CyclePhase, name: String) -> String {
        switch phase {
        case .toilet:   return "Toilet break"
        case .physical: return "Activity time"
        case .mental:   return "Training"
        case .feeding:  return "Feeding"
        case .sleep:    return "Rest"
        }
    }

    private static func actionType(for phase: CyclePhase) -> ActionType {
        switch phase {
        case .toilet:   return .toilet
        case .physical: return .activity(.walking)
        case .mental:   return .activity(.training)
        case .feeding:  return .activity(.feeding)
        case .sleep:    return .rest
        }
    }
}
