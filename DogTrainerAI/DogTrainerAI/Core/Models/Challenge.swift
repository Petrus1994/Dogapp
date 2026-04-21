import Foundation

struct Challenge: Codable, Identifiable {
    var id: String
    var type: ChallengeType
    var progress: Int
    var isCompleted: Bool
    var completedDate: Date?

    var progressFraction: Double {
        min(Double(progress) / Double(type.requirement), 1.0)
    }

    enum ChallengeType: String, Codable, CaseIterable {
        case walkFor7Days
        case calmWalksFor5Days
        case completeFullDayFor3Days
        case logActivitiesFor7Days
        case reportIssuesHonestlyFor5Days

        var title: String {
            switch self {
            case .walkFor7Days:                 return "7-Day Walk Streak"
            case .calmWalksFor5Days:            return "Calm Walker"
            case .completeFullDayFor3Days:      return "Routine Builder"
            case .logActivitiesFor7Days:        return "Dedicated Tracker"
            case .reportIssuesHonestlyFor5Days: return "Honest Trainer"
            }
        }

        var description: String {
            switch self {
            case .walkFor7Days:                 return "Log a walk for 7 consecutive days"
            case .calmWalksFor5Days:            return "Complete 5 walks without reporting leash pulling"
            case .completeFullDayFor3Days:      return "Log all 4 activities (feeding, walk, play, training) for 3 days in a row"
            case .logActivitiesFor7Days:        return "Log at least one activity every day for 7 days"
            case .reportIssuesHonestlyFor5Days: return "Report real behavior issues on 5 different days"
            }
        }

        var icon: String {
            switch self {
            case .walkFor7Days:                 return "🦮"
            case .calmWalksFor5Days:            return "🧘"
            case .completeFullDayFor3Days:      return "📅"
            case .logActivitiesFor7Days:        return "📊"
            case .reportIssuesHonestlyFor5Days: return "🎯"
            }
        }

        var requirement: Int {
            switch self {
            case .walkFor7Days:                 return 7
            case .calmWalksFor5Days:            return 5
            case .completeFullDayFor3Days:      return 3
            case .logActivitiesFor7Days:        return 7
            case .reportIssuesHonestlyFor5Days: return 5
            }
        }

        var pointReward: Int {
            switch self {
            case .walkFor7Days:                 return 50
            case .calmWalksFor5Days:            return 40
            case .completeFullDayFor3Days:      return 30
            case .logActivitiesFor7Days:        return 45
            case .reportIssuesHonestlyFor5Days: return 35
            }
        }

        var requiresDog: Bool {
            switch self {
            case .walkFor7Days, .calmWalksFor5Days,
                 .completeFullDayFor3Days, .reportIssuesHonestlyFor5Days:
                return true
            case .logActivitiesFor7Days:
                return false
            }
        }
    }

    static func defaults() -> [Challenge] {
        ChallengeType.allCases.map { type in
            Challenge(id: type.rawValue, type: type, progress: 0, isCompleted: false, completedDate: nil)
        }
    }
}
