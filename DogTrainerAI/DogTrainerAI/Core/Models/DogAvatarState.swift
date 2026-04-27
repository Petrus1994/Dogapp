import Foundation

/// The ten visual/behavioral states the dog avatar can display.
enum DogAvatarState: String, Equatable, Codable {
    case sleeping
    case tired
    case calm
    case happy
    case excited
    case anxious
    case hungry
    case frustrated
    case seekingAttention
    case proud

    // MARK: - Derive state from DogState

    static func from(_ state: DogState) -> DogAvatarState {
        if state.energyLevel < 0.15 { return .sleeping }
        if state.energyLevel < 0.35 { return .tired }
        if state.hungerLevel  > 0.80 { return .hungry }
        if state.calmness     < 0.25 { return .anxious }
        if state.satisfaction > 0.75 && state.energyLevel > 0.6 { return .excited }
        if state.satisfaction > 0.70 && state.calmness > 0.5    { return .happy }
        if state.focusOnOwner < 0.30 { return .seekingAttention }
        return .calm
    }

    // MARK: - Derive from backend state string

    static func from(backendState: String) -> DogAvatarState {
        return DogAvatarState(rawValue: backendState) ?? .calm
    }

    // MARK: - Visual properties

    var label: String {
        switch self {
        case .sleeping:          return "Sleeping"
        case .tired:             return "Tired"
        case .calm:              return "Feeling Great"
        case .happy:             return "Happy"
        case .excited:           return "Excited!"
        case .anxious:           return "Anxious"
        case .hungry:            return "Hungry"
        case .frustrated:        return "Frustrated"
        case .seekingAttention:  return "Waiting for you"
        case .proud:             return "Proud!"
        }
    }

    var emoji: String {
        switch self {
        case .sleeping:          return "😴"
        case .tired:             return "😪"
        case .calm:              return "😌"
        case .happy:             return "😊"
        case .excited:           return "🤩"
        case .anxious:           return "😰"
        case .hungry:            return "🍖"
        case .frustrated:        return "😤"
        case .seekingAttention:  return "👀"
        case .proud:             return "🏆"
        }
    }

    var animationSpeed: Double {
        switch self {
        case .sleeping:          return 0.3
        case .tired:             return 0.5
        case .calm:              return 0.8
        case .happy:             return 1.0
        case .excited:           return 1.8
        case .anxious:           return 1.4
        case .hungry:            return 0.9
        case .frustrated:        return 1.2
        case .seekingAttention:  return 0.9
        case .proud:             return 1.3
        }
    }

    var tailWagIntensity: Double {
        switch self {
        case .sleeping:          return 0.0
        case .tired:             return 0.1
        case .calm:              return 0.4
        case .happy:             return 0.7
        case .excited:           return 1.0
        case .anxious:           return 0.2
        case .hungry:            return 0.3
        case .frustrated:        return 0.15
        case .seekingAttention:  return 0.5
        case .proud:             return 0.8
        }
    }

    var eyeOpenFraction: Double {
        switch self {
        case .sleeping:          return 0.0
        case .tired:             return 0.3
        case .calm:              return 0.7
        case .happy:             return 0.8
        case .excited:           return 1.0
        case .anxious:           return 0.9
        case .hungry:            return 0.7
        case .frustrated:        return 0.85
        case .seekingAttention:  return 0.8
        case .proud:             return 0.9
        }
    }

    var doesBounce: Bool { self == .excited || self == .proud }
    var doesBreathe: Bool { self != .sleeping }

    // Lottie animation key — maps to asset name in AvatarAnimations.xcassets
    var lottieAnimationName: String {
        switch self {
        case .sleeping:          return "avatar_sleeping"
        case .tired:             return "avatar_tired"
        case .calm:              return "avatar_idle"
        case .happy:             return "avatar_happy"
        case .excited:           return "avatar_excited"
        case .anxious:           return "avatar_anxious"
        case .hungry:            return "avatar_hungry"
        case .frustrated:        return "avatar_frustrated"
        case .seekingAttention:  return "avatar_seeking"
        case .proud:             return "avatar_proud"
        }
    }
}
