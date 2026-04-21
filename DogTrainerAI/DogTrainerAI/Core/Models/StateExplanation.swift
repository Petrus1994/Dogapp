import Foundation

/// A human-readable explanation for one dog state parameter.
/// Shown when a user taps a stat bar to understand what caused it.
struct StateExplanation: Identifiable {
    let id = UUID()
    let parameter: Parameter
    let value: Double        // 0–1
    let isNormal: Bool
    let cause: String        // what drove this value
    let recommendation: String  // one specific action

    enum Parameter: String, CaseIterable {
        case energy, hunger, happiness, calmness, confidence, engagement

        var displayName: String {
            switch self {
            case .energy:     return "Energy"
            case .hunger:     return "Hunger"
            case .happiness:  return "Happiness"
            case .calmness:   return "Calmness"
            case .confidence: return "Confidence"
            case .engagement: return "Engagement"
            }
        }

        var icon: String {
            switch self {
            case .energy:     return "⚡"
            case .hunger:     return "🍖"
            case .happiness:  return "😊"
            case .calmness:   return "😌"
            case .confidence: return "💪"
            case .engagement: return "🤝"
            }
        }
    }

    var valueLabel: String {
        switch value {
        case 0.8...: return "Very high"
        case 0.6...: return "Good"
        case 0.4...: return "Moderate"
        case 0.2...: return "Low"
        default:     return "Very low"
        }
    }

    var severityColor: SeverityColor {
        switch parameter {
        case .hunger:
            // High hunger = bad
            if value > 0.75 { return .bad }
            if value > 0.5  { return .warning }
            return .good

        case .energy:
            // Extreme energy (too high or too low) = bad
            if value > 0.85 || value < 0.15 { return .bad }
            if value > 0.7  || value < 0.25 { return .warning }
            return .good

        default:
            // For calmness, happiness, confidence, engagement: higher = better
            if value > 0.65 { return .good }
            if value > 0.4  { return .warning }
            return .bad
        }
    }

    enum SeverityColor { case good, warning, bad }
}

// MARK: - Factory

extension StateExplanation {

    static func explanations(for state: DogState, dogName: String, activities: [DailyActivity]) -> [StateExplanation] {
        var result: [StateExplanation] = []

        let walkMin   = activities.filter { $0.type.countsAsWalk  && $0.completed }.reduce(0) { $0 + $1.durationMinutes }
        let playMin   = activities.filter { $0.type.countsAsPlay  && $0.completed }.reduce(0) { $0 + $1.durationMinutes }
        let fedCount  = activities.filter { $0.type == .feeding   && $0.completed }.count
        let trainMin  = activities.filter { $0.type == .training  && $0.completed }.reduce(0) { $0 + $1.durationMinutes }

        // Energy
        let energyCause: String
        let energyRec: String
        if state.energyLevel > 0.75 {
            energyCause = "\(dogName) hasn't had enough physical activity today (\(walkMin) min walked)."
            energyRec   = "A \(walkMin < 20 ? "20-minute" : "15-minute") walk will bring energy to a balanced level."
        } else if state.energyLevel < 0.25 {
            energyCause = "\(dogName) has been very active today — \(walkMin + playMin) minutes of total activity."
            energyRec   = "Allow at least 30 minutes of rest before the next session."
        } else {
            energyCause = "Energy is well-balanced after today's activity."
            energyRec   = "Keep the current routine going."
        }
        result.append(StateExplanation(
            parameter: .energy, value: state.energyLevel,
            isNormal: (0.25...0.75).contains(state.energyLevel),
            cause: energyCause, recommendation: energyRec
        ))

        // Hunger
        let hungerCause: String
        let hungerRec: String
        if state.hungerLevel > 0.75 {
            hungerCause = fedCount == 0 ? "\(dogName) hasn't been fed today yet." : "It's been a while since the last feeding."
            hungerRec   = "Feed \(dogName) now. Consistent meal timing helps reduce food anxiety."
        } else {
            hungerCause = fedCount > 0 ? "\(dogName) was fed \(fedCount == 1 ? "once" : "\(fedCount) times") today." : "No feeding logged yet today."
            hungerRec   = fedCount == 0 ? "Log the first feeding when it happens to keep the system accurate." : "Next feeding in a few hours — you're on track."
        }
        result.append(StateExplanation(
            parameter: .hunger, value: state.hungerLevel,
            isNormal: state.hungerLevel < 0.65,
            cause: hungerCause, recommendation: hungerRec
        ))

        // Happiness
        let happinessCause: String
        let happinessRec: String
        if state.satisfaction < 0.35 {
            happinessCause = playMin < 10
                ? "\(dogName) had little to no play or interaction today."
                : "Low satisfaction despite \(playMin) min of play — behavior issues may be affecting mood."
            happinessRec = "Try 10 minutes of focused play (fetch, tug, or scent work) in the next hour."
        } else if state.satisfaction > 0.75 {
            happinessCause = "\(dogName) had good play (\(playMin) min) and \(trainMin > 0 ? "training (\(trainMin) min)" : "engagement") today."
            happinessRec   = "Great day! Maintaining this balance consistently builds behavioral stability."
        } else {
            happinessCause = "\(dogName) is reasonably content. Play time today: \(playMin) min."
            happinessRec   = playMin < 20 ? "A short play session would push happiness higher." : "You're doing well — keep the routine."
        }
        result.append(StateExplanation(
            parameter: .happiness, value: state.satisfaction,
            isNormal: state.satisfaction > 0.4,
            cause: happinessCause, recommendation: happinessRec
        ))

        // Calmness
        let calmnessCause: String
        let calmnessRec: String
        if state.calmness < 0.3 {
            calmnessCause = "Reactivity or anxious behavior detected. This is often triggered by insufficient routine or overstimulation."
            calmnessRec   = "Avoid high-stimulation environments for the rest of the day. Try a slow 10-minute sniff walk."
        } else if state.calmness > 0.75 {
            calmnessCause = "\(dogName) is calm and settled. Consistent routine is working."
            calmnessRec   = "This is the ideal state for training — \(dogName) will learn best right now."
        } else {
            calmnessCause = "Moderate calmness — typical for this time of day."
            calmnessRec   = "Avoid sudden schedule changes or loud environments in the next few hours."
        }
        result.append(StateExplanation(
            parameter: .calmness, value: state.calmness,
            isNormal: state.calmness > 0.35,
            cause: calmnessCause, recommendation: calmnessRec
        ))

        // Confidence
        let confidenceCause: String
        let confidenceRec: String
        if state.behaviorStability < 0.35 {
            confidenceCause = "Recent avoidance or fearful behavior is signaling low confidence."
            confidenceRec   = "Try 5 minutes of calm exposure: let \(dogName) approach new things at their own pace, no pressure."
        } else if state.behaviorStability > 0.75 {
            confidenceCause = "\(dogName) is showing stable, predictable behavior — a sign of growing confidence."
            confidenceRec   = "Introduce a mild new challenge this week (a new route, a new person) to keep building."
        } else {
            confidenceCause = "Confidence is moderate — normal for this stage."
            confidenceRec   = "Short training wins (sit, stay, name recall) compound into lasting confidence."
        }
        result.append(StateExplanation(
            parameter: .confidence, value: state.behaviorStability,
            isNormal: state.behaviorStability > 0.4,
            cause: confidenceCause, recommendation: confidenceRec
        ))

        // Engagement
        let engagementCause: String
        let engagementRec: String
        if state.focusOnOwner < 0.3 {
            engagementCause = "\(dogName) is not responding well to your cues today. This can follow overstimulation or inconsistent interaction."
            engagementRec   = "Try 3 minutes of name recall in a quiet space. Low-distraction wins rebuild attention fast."
        } else if state.focusOnOwner > 0.7 {
            engagementCause = "High owner focus — \(trainMin > 0 ? "training today has reinforced the bond." : "consistent interaction is paying off.")"
            engagementRec   = "Ideal moment for a new training skill — \(dogName) is primed to learn."
        } else {
            engagementCause = "Moderate engagement — typical outside of active training sessions."
            engagementRec   = "A brief eye-contact game (5 reps of 'look at me') maintains the bond on busy days."
        }
        result.append(StateExplanation(
            parameter: .engagement, value: state.focusOnOwner,
            isNormal: state.focusOnOwner > 0.35,
            cause: engagementCause, recommendation: engagementRec
        ))

        return result
    }
}
