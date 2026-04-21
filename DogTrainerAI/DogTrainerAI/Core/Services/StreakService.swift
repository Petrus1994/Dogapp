import Foundation

struct StreakService {

    // Call this whenever the user logs any meaningful activity for today.
    static func markActiveToday(progress: inout UserProgress) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let last = progress.lastActiveDate {
            let lastDay = calendar.startOfDay(for: last)
            let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            switch diff {
            case 0:
                return  // Already counted today
            case 1:
                progress.currentStreak += 1
            default:
                progress.currentStreak = 1  // Gap — streak broken
            }
        } else {
            progress.currentStreak = 1
        }

        progress.lastActiveDate = today
        progress.longestStreak  = max(progress.longestStreak, progress.currentStreak)
    }

    // Call on app launch to break streak if the user missed yesterday.
    static func checkForStreakBreak(progress: inout UserProgress) {
        guard let last = progress.lastActiveDate else { return }
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let lastDay  = calendar.startOfDay(for: last)
        let diff     = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if diff > 1 {
            progress.currentStreak = 0
        }
    }
}
