import Foundation

struct StreakService {

    // MARK: - Mark active

    /// Call whenever the user logs any meaningful activity for today.
    /// Awards streak shields at 7-day milestones.
    static func markActiveToday(progress: inout UserProgress) {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())

        if let last = progress.lastActiveDate {
            let lastDay = calendar.startOfDay(for: last)
            let diff    = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            switch diff {
            case 0:
                return  // already counted today
            case 1:
                progress.currentStreak += 1
            default:
                progress.currentStreak = 1  // gap — streak broken (shield check already ran at launch)
            }
        } else {
            progress.currentStreak = 1
        }

        progress.lastActiveDate = today
        progress.longestStreak  = max(progress.longestStreak, progress.currentStreak)

        // Award shield at every new 7-day milestone (max 3 banked)
        progress.checkAndAwardShield()
    }

    // MARK: - Launch check (break streak or consume shield)

    /// Call on app launch to break streak if the user missed yesterday.
    /// If the user has a shield available, consumes it silently — streak is preserved.
    /// Returns a `StreakBreakResult` so the caller can show the appropriate UI.
    @discardableResult
    static func checkForStreakBreak(progress: inout UserProgress) -> StreakBreakResult {
        guard let last = progress.lastActiveDate else { return .noStreak }

        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let lastDay  = calendar.startOfDay(for: last)
        let diff     = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        guard diff > 1 else { return .intact }  // yesterday or today — fine

        // Missed at least one day
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Check if yesterday is shield-protected (consumed at a prior launch)
        if let protected = progress.shieldProtectedDate,
           calendar.isDate(protected, inSameDayAs: yesterday) {
            // Shield was already applied — but now it's diff > 1 meaning TWO+ days missed
            // This means the shield covered day 1 and now day 2+ broke anyway
            progress.currentStreak = 0
            progress.shieldProtectedDate = nil
            return .broken(wasShielded: true)
        }

        // Try to consume a new shield for the missed day
        if progress.hasAvailableShield {
            progress.consumeShield(for: yesterday)
            return .shieldConsumed(shieldsRemaining: progress.streakShields)
        }

        // No shield — streak breaks
        let broken = progress.currentStreak
        progress.currentStreak = 0
        return .broken(wasShielded: false)
    }

    // MARK: - Result type

    enum StreakBreakResult {
        case noStreak                                    // user has no streak history
        case intact                                      // streak is fine
        case shieldConsumed(shieldsRemaining: Int)       // shield used, streak preserved
        case broken(wasShielded: Bool)                   // streak reset

        var shouldShowNotification: Bool {
            switch self {
            case .shieldConsumed: return true
            case .broken:         return true
            default:              return false
            }
        }

        var notificationMessage: String? {
            switch self {
            case .shieldConsumed(let remaining):
                return "You missed yesterday — your streak shield activated! \(remaining) shield\(remaining == 1 ? "" : "s") remaining."
            case .broken(let wasShielded):
                return wasShielded
                    ? "Your streak ended after the shield was used. Start a new one today!"
                    : "Your streak ended. Start fresh today — every day counts."
            default:
                return nil
            }
        }
    }
}
