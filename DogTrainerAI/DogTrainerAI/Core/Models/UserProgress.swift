import Foundation

struct UserProgress: Codable {
    var totalPoints: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date?
    var level: UserLevel
    var completedChallengeIds: [String]
    var consecutiveSuccessCount: Int    // anti-cheat: tracks unbroken task successes
    var consecutiveNoIssuesCount: Int   // anti-cheat: tracks days with zero issues reported

    // MARK: - Streak shield system
    var streakShields: Int              // banked shields (max 3)
    var shieldProtectedDate: Date?      // if set, this day's missed streak is forgiven
    var lastShieldAwardedAtStreak: Int  // prevents double-awarding at same milestone

    static let initial = UserProgress(
        totalPoints: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastActiveDate: nil,
        level: .beginner,
        completedChallengeIds: [],
        consecutiveSuccessCount: 0,
        consecutiveNoIssuesCount: 0,
        streakShields: 0,
        shieldProtectedDate: nil,
        lastShieldAwardedAtStreak: 0
    )

    // MARK: - Shield helpers

    /// Returns true if the user has a shield available and it's not yet used today
    var hasAvailableShield: Bool { streakShields > 0 }

    mutating func consumeShield(for date: Date) {
        guard streakShields > 0 else { return }
        streakShields -= 1
        shieldProtectedDate = Calendar.current.startOfDay(for: date)
    }

    /// Award a shield when reaching a new 7-day milestone
    mutating func checkAndAwardShield() {
        let milestone = (currentStreak / 7) * 7
        guard milestone > 0, milestone > lastShieldAwardedAtStreak, streakShields < 3 else { return }
        streakShields = min(streakShields + 1, 3)
        lastShieldAwardedAtStreak = milestone
    }

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
