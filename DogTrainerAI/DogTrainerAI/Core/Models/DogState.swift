import Foundation

struct DogState: Codable {
    var energyLevel: Double        // 0 = exhausted, 1 = hyper
    var calmness: Double           // 0 = reactive/anxious, 1 = very calm
    var satisfaction: Double       // 0 = unfulfilled, 1 = content
    var behaviorStability: Double  // 0 = unpredictable, 1 = stable
    var focusOnOwner: Double       // 0 = ignoring, 1 = attentive
    var lastUpdated: Date

    // Toilet urgency (0 = just went, 1 = critical need)
    var toiletUrgency: Double = 0.0

    // Hunger indicator (0 = just fed, 1 = due for feeding)
    var hungerLevel: Double = 0.0

    // MARK: - Tamagotchi-style current need

    var primaryNeed: DogNeed {
        if toiletUrgency > 0.75 { return .toilet }
        if hungerLevel > 0.8 { return .feeding }
        if energyLevel > 0.75 { return .activity }
        if calmness < 0.3 { return .calm }
        if satisfaction < 0.3 { return .play }
        if focusOnOwner < 0.25 { return .training }
        if energyLevel < 0.25 { return .rest }
        return .balanced
    }

    enum DogNeed {
        case toilet, feeding, activity, play, training, calm, rest, balanced

        var icon: String {
            switch self {
            case .toilet:   return "🌿"
            case .feeding:  return "🍖"
            case .activity: return "🦮"
            case .play:     return "🎾"
            case .training: return "🧠"
            case .calm:     return "😮‍💨"
            case .rest:     return "😴"
            case .balanced: return "✨"
            }
        }

        var label: String {
            switch self {
            case .toilet:   return "Needs toilet break"
            case .feeding:  return "Feeding due soon"
            case .activity: return "High energy — needs a walk"
            case .play:     return "Needs play / interaction"
            case .training: return "Ready for mental exercise"
            case .calm:     return "Needs calm routine"
            case .rest:     return "Tired — let them rest"
            case .balanced: return "Well balanced"
            }
        }

        var urgency: Urgency {
            switch self {
            case .toilet:   return .high
            case .feeding:  return .medium
            case .activity: return .medium
            case .calm:     return .medium
            case .balanced, .rest: return .low
            default:        return .low
            }
        }

        enum Urgency { case high, medium, low }
    }

    static let neutral = DogState(
        energyLevel: 0.5,
        calmness: 0.6,
        satisfaction: 0.5,
        behaviorStability: 0.6,
        focusOnOwner: 0.5,
        lastUpdated: Date()
    )

    var overallScore: Double {
        (calmness + satisfaction + behaviorStability + focusOnOwner) / 4.0
    }

    var emoji: String {
        switch overallScore {
        case 0.8...: return "😊"
        case 0.6...: return "🙂"
        case 0.4...: return "😐"
        case 0.2...: return "😟"
        default:     return "😰"
        }
    }

    var label: String {
        switch overallScore {
        case 0.8...: return "Thriving"
        case 0.6...: return "Doing well"
        case 0.4...: return "Needs attention"
        case 0.2...: return "Struggling"
        default:     return "Needs urgent help"
        }
    }

    var energyLabel: String {
        switch energyLevel {
        case 0.8...: return "Hyperactive"
        case 0.6...: return "High energy"
        case 0.35...: return "Balanced"
        case 0.2...: return "Low energy"
        default:     return "Exhausted"
        }
    }
}
