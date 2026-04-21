import Foundation

struct UserProgress: Codable {
    var totalPoints: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date?
    var level: UserLevel
    var completedChallengeIds: [String]
    var consecutiveSuccessCount: Int   // anti-cheat: tracks unbroken task successes
    var consecutiveNoIssuesCount: Int  // anti-cheat: tracks days with zero issues reported

    static let initial = UserProgress(
        totalPoints: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastActiveDate: nil,
        level: .beginner,
        completedChallengeIds: [],
        consecutiveSuccessCount: 0,
        consecutiveNoIssuesCount: 0
    )

    enum UserLevel: String, Codable, CaseIterable {
        case beginner, consistent, responsible, advanced

        var displayName: String {
            switch self {
            case .beginner:    return "Beginner"
            case .consistent:  return "Consistent Owner"
            case .responsible: return "Responsible Owner"
            case .advanced:    return "Advanced Owner"
            }
        }

        var icon: String {
            switch self {
            case .beginner:    return "🌱"
            case .consistent:  return "🌿"
            case .responsible: return "🌳"
            case .advanced:    return "🏆"
            }
        }

        var pointsRequired: Int {
            switch self {
            case .beginner:    return 0
            case .consistent:  return 100
            case .responsible: return 300
            case .advanced:    return 700
            }
        }

        var nextLevel: UserLevel? {
            switch self {
            case .beginner:    return .consistent
            case .consistent:  return .responsible
            case .responsible: return .advanced
            case .advanced:    return nil
            }
        }
    }

    var progressToNextLevel: Double {
        guard let next = level.nextLevel else { return 1.0 }
        let start = level.pointsRequired
        let end   = next.pointsRequired
        return min(max(Double(totalPoints - start) / Double(end - start), 0), 1)
    }

    var pointsToNextLevel: Int {
        (level.nextLevel?.pointsRequired ?? totalPoints) - totalPoints
    }

    var shouldShowAntiCheatPrompt: Bool {
        consecutiveSuccessCount >= 7 || consecutiveNoIssuesCount >= 14
    }
}
