import Foundation

/// The six visual states the dog avatar can display.
enum DogAvatarState: Equatable {
    case sleeping
    case tired
    case calm
    case happy
    case excited
    case anxious

    // MARK: - Derive state from DogState

    static func from(_ state: DogState) -> DogAvatarState {
        // Resting takes priority
        if state.energyLevel < 0.2 { return .sleeping }
        if state.energyLevel < 0.35 { return .tired }

        // Anxious: low calmness regardless of energy
        if state.calmness < 0.3 { return .anxious }

        // Excited: high energy + high satisfaction
        if state.energyLevel > 0.75 && state.satisfaction > 0.5 { return .excited }

        // Happy: good satisfaction + reasonable calm
        if state.satisfaction > 0.6 && state.calmness > 0.5 { return .happy }

        // Default: calm
        return .calm
    }

    // MARK: - Visual properties

    var label: String {
        switch self {
        case .sleeping: return "Sleeping"
        case .tired:    return "Tired"
        case .calm:     return "Calm"
        case .happy:    return "Happy"
        case .excited:  return "Excited!"
        case .anxious:  return "Anxious"
        }
    }

    var emoji: String {
        switch self {
        case .sleeping: return "😴"
        case .tired:    return "😪"
        case .calm:     return "😌"
        case .happy:    return "😊"
        case .excited:  return "🤩"
        case .anxious:  return "😰"
        }
    }

    // Animation speed multiplier: excited dogs animate faster
    var animationSpeed: Double {
        switch self {
        case .sleeping: return 0.3
        case .tired:    return 0.5
        case .calm:     return 0.8
        case .happy:    return 1.0
        case .excited:  return 1.8
        case .anxious:  return 1.4
        }
    }

    // How much the tail wags (0 = still, 1 = maximum wag)
    var tailWagIntensity: Double {
        switch self {
        case .sleeping: return 0
        case .tired:    return 0.1
        case .calm:     return 0.4
        case .happy:    return 0.7
        case .excited:  return 1.0
        case .anxious:  return 0.2
        }
    }

    // Eye shape: open fraction (0 = fully closed, 1 = wide open)
    var eyeOpenFraction: Double {
        switch self {
        case .sleeping: return 0.0
        case .tired:    return 0.3
        case .calm:     return 0.7
        case .happy:    return 0.8
        case .excited:  return 1.0
        case .anxious:  return 0.9  // wide open from fear
        }
    }

    // Whether the body does a bounce animation (zoomies energy)
    var doesBounce: Bool {
        self == .excited
    }

    // Whether the body does a slow breathing animation
    var doesBreathe: Bool {
        self != .sleeping  // sleeping has its own subtle chest-rise
    }
}
