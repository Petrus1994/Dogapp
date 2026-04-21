import Foundation

struct BehaviorEvent: Codable, Identifiable {
    var id: String
    var date: Date
    var activityType: DailyActivity.ActivityType?
    var issues: [BehaviorIssue]
    var notes: String

    var hasRealIssues: Bool {
        !issues.isEmpty && !issues.contains(.noIssues)
    }

    enum BehaviorIssue: String, Codable, CaseIterable, Identifiable {
        var id: String { rawValue }

        case leashPulling          = "leash_pulling"
        case pickingFoodFromGround = "picking_food_from_ground"
        case notResponding         = "not_responding"
        case overexcitement        = "overexcitement"
        case jumpingOnPeople       = "jumping_on_people"
        case barking               = "barking"
        case fearReactions         = "fear_reactions"
        case ignoringOwner         = "ignoring_owner"
        case aggression            = "aggression"
        case chewingObjects        = "chewing_objects"
        case whiningOrHowling      = "whining_or_howling"
        case toiletAccidents       = "toilet_accidents"
        case beggingForFood        = "begging_for_food"
        case reactingToNoises      = "reacting_to_noises"
        case reactingToDogs        = "reacting_to_dogs"
        case reactingToPeople      = "reacting_to_people"
        case other                 = "other"
        case noIssues              = "no_issues"

        var displayName: String {
            switch self {
            case .leashPulling:          return "Leash pulling"
            case .pickingFoodFromGround: return "Picking food from ground"
            case .notResponding:         return "Not responding to commands"
            case .overexcitement:        return "Overexcitement"
            case .jumpingOnPeople:       return "Jumping on people"
            case .barking:               return "Barking"
            case .fearReactions:         return "Fear reactions"
            case .ignoringOwner:         return "Ignoring owner"
            case .aggression:            return "Aggression"
            case .chewingObjects:        return "Chewing objects"
            case .whiningOrHowling:      return "Whining / howling"
            case .toiletAccidents:       return "Toilet accidents"
            case .beggingForFood:        return "Begging for food"
            case .reactingToNoises:      return "Reacting to noises"
            case .reactingToDogs:        return "Reacting to dogs"
            case .reactingToPeople:      return "Reacting to people"
            case .other:                 return "Other"
            case .noIssues:              return "No issues"
            }
        }

        var icon: String {
            switch self {
            case .leashPulling:          return "🐕"
            case .pickingFoodFromGround: return "🍖"
            case .notResponding:         return "🙉"
            case .overexcitement:        return "⚡"
            case .jumpingOnPeople:       return "🦘"
            case .barking:               return "🔊"
            case .fearReactions:         return "😨"
            case .ignoringOwner:         return "🙈"
            case .aggression:            return "⚠️"
            case .chewingObjects:        return "🦷"
            case .whiningOrHowling:      return "😿"
            case .toiletAccidents:       return "🚽"
            case .beggingForFood:        return "🥺"
            case .reactingToNoises:      return "👂"
            case .reactingToDogs:        return "🐩"
            case .reactingToPeople:      return "👥"
            case .other:                 return "📝"
            case .noIssues:              return "✅"
            }
        }
    }
}
