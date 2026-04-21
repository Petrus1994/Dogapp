import Foundation

struct BreedSelectionProfile: Codable {
    var lifestyle:         Lifestyle
    var homeType:          HomeType
    var experienceLevel:   ExperienceLevel
    var availableTime:     AvailableTime
    var hasChildren:       Bool
    var goal:              DogGoal
    var sizePreference:    SizePreference
    var weightPreference:  WeightPreference
    var coatType:          CoatType
    var groomingTolerance: GroomingTolerance
    var noiseTolerance:    NoiseTolerance
    var energyExpectation: EnergyExpectation

    // Backward-compatible decoder: new fields fall back to defaults if absent
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lifestyle         = try c.decode(Lifestyle.self,       forKey: .lifestyle)
        homeType          = try c.decode(HomeType.self,        forKey: .homeType)
        experienceLevel   = try c.decode(ExperienceLevel.self, forKey: .experienceLevel)
        availableTime     = try c.decode(AvailableTime.self,   forKey: .availableTime)
        hasChildren       = try c.decode(Bool.self,            forKey: .hasChildren)
        goal              = try c.decode(DogGoal.self,         forKey: .goal)
        sizePreference    = (try? c.decode(SizePreference.self,    forKey: .sizePreference))    ?? .noPreference
        weightPreference  = (try? c.decode(WeightPreference.self,  forKey: .weightPreference))  ?? .noPreference
        coatType          = (try? c.decode(CoatType.self,          forKey: .coatType))          ?? .noPreference
        groomingTolerance = (try? c.decode(GroomingTolerance.self, forKey: .groomingTolerance)) ?? .medium
        noiseTolerance    = (try? c.decode(NoiseTolerance.self,    forKey: .noiseTolerance))    ?? .okWithBarking
        energyExpectation = (try? c.decode(EnergyExpectation.self, forKey: .energyExpectation)) ?? .balanced
    }

    init(
        lifestyle:         Lifestyle,
        homeType:          HomeType,
        experienceLevel:   ExperienceLevel,
        availableTime:     AvailableTime,
        hasChildren:       Bool,
        goal:              DogGoal,
        sizePreference:    SizePreference    = .noPreference,
        weightPreference:  WeightPreference  = .noPreference,
        coatType:          CoatType          = .noPreference,
        groomingTolerance: GroomingTolerance = .medium,
        noiseTolerance:    NoiseTolerance    = .okWithBarking,
        energyExpectation: EnergyExpectation = .balanced
    ) {
        self.lifestyle         = lifestyle
        self.homeType          = homeType
        self.experienceLevel   = experienceLevel
        self.availableTime     = availableTime
        self.hasChildren       = hasChildren
        self.goal              = goal
        self.sizePreference    = sizePreference
        self.weightPreference  = weightPreference
        self.coatType          = coatType
        self.groomingTolerance = groomingTolerance
        self.noiseTolerance    = noiseTolerance
        self.energyExpectation = energyExpectation
    }

    // MARK: - Existing enums

    enum Lifestyle: String, Codable, CaseIterable {
        case calm, moderate, active
        var displayName: String { rawValue.capitalized }
        var icon: String {
            switch self { case .calm: return "🛋️"; case .moderate: return "🚶"; case .active: return "🏃" }
        }
    }

    enum HomeType: String, Codable, CaseIterable {
        case apartment, house
        var displayName: String { rawValue.capitalized }
        var icon: String {
            switch self { case .apartment: return "🏢"; case .house: return "🏠" }
        }
    }

    enum ExperienceLevel: String, Codable, CaseIterable {
        case firstDog    = "first_dog"
        case experienced
        var displayName: String {
            switch self { case .firstDog: return "First dog"; case .experienced: return "Experienced" }
        }
        var icon: String {
            switch self { case .firstDog: return "🌱"; case .experienced: return "🏆" }
        }
    }

    enum AvailableTime: String, Codable, CaseIterable {
        case low, medium, high
        var displayName: String {
            switch self {
            case .low:    return "Low (< 1 hr)"
            case .medium: return "Medium (1–2 hrs)"
            case .high:   return "High (3+ hrs)"
            }
        }
        var icon: String {
            switch self { case .low: return "⏱️"; case .medium: return "🕐"; case .high: return "🕐🕐" }
        }
    }

    enum DogGoal: String, Codable, CaseIterable {
        case companion, activePartner = "active_partner", guard_ = "guard", versatile
        var displayName: String {
            switch self {
            case .companion:     return "Companion"
            case .activePartner: return "Active partner"
            case .guard_:        return "Guard"
            case .versatile:     return "Versatile"
            }
        }
        var icon: String {
            switch self {
            case .companion:     return "❤️"
            case .activePartner: return "🏅"
            case .guard_:        return "🛡️"
            case .versatile:     return "⭐"
            }
        }
    }

    // MARK: - New enums

    enum SizePreference: String, Codable, CaseIterable {
        case small, medium, large, noPreference = "no_preference"
        var displayName: String {
            switch self {
            case .small:        return "Small"
            case .medium:       return "Medium"
            case .large:        return "Large"
            case .noPreference: return "No preference"
            }
        }
        var icon: String {
            switch self {
            case .small:        return "🐾"
            case .medium:       return "🐕"
            case .large:        return "🦮"
            case .noPreference: return "🤷"
            }
        }
    }

    enum WeightPreference: String, Codable, CaseIterable {
        case under10kg       = "under_10kg"
        case tenTo25kg       = "10_to_25kg"
        case twentyFiveTo45kg = "25_to_45kg"
        case over45kg        = "over_45kg"
        case noPreference    = "no_preference"
        var displayName: String {
            switch self {
            case .under10kg:        return "< 10 kg"
            case .tenTo25kg:        return "10–25 kg"
            case .twentyFiveTo45kg: return "25–45 kg"
            case .over45kg:         return "45 kg+"
            case .noPreference:     return "No pref"
            }
        }
        var icon: String {
            switch self {
            case .under10kg:        return "🐩"
            case .tenTo25kg:        return "🐕"
            case .twentyFiveTo45kg: return "🐕‍🦺"
            case .over45kg:         return "🦣"
            case .noPreference:     return "🤷"
            }
        }
    }

    enum CoatType: String, Codable, CaseIterable {
        case short, long, hypoallergenic, noPreference = "no_preference"
        var displayName: String {
            switch self {
            case .short:           return "Short"
            case .long:            return "Long"
            case .hypoallergenic:  return "Hypo-allergenic"
            case .noPreference:    return "No pref"
            }
        }
        var icon: String {
            switch self {
            case .short:          return "✂️"
            case .long:           return "🌿"
            case .hypoallergenic: return "🤧"
            case .noPreference:   return "🤷"
            }
        }
    }

    enum GroomingTolerance: String, Codable, CaseIterable {
        case low, medium, high
        var displayName: String {
            switch self {
            case .low:    return "Minimal"
            case .medium: return "Monthly"
            case .high:   return "Weekly+"
            }
        }
        var icon: String {
            switch self { case .low: return "😅"; case .medium: return "🪮"; case .high: return "💅" }
        }
    }

    enum NoiseTolerance: String, Codable, CaseIterable {
        case preferQuiet   = "prefer_quiet"
        case okWithBarking = "ok_with_barking"
        var displayName: String {
            switch self {
            case .preferQuiet:   return "Quiet please"
            case .okWithBarking: return "Barking is fine"
            }
        }
        var icon: String {
            switch self { case .preferQuiet: return "🤫"; case .okWithBarking: return "🔊" }
        }
    }

    enum EnergyExpectation: String, Codable, CaseIterable {
        case calmCompanion = "calm_companion"
        case balanced
        case veryActive    = "very_active"
        var displayName: String {
            switch self {
            case .calmCompanion: return "Calm companion"
            case .balanced:      return "Balanced"
            case .veryActive:    return "Very active"
            }
        }
        var icon: String {
            switch self {
            case .calmCompanion: return "😴"
            case .balanced:      return "🎯"
            case .veryActive:    return "⚡"
            }
        }
    }
}
