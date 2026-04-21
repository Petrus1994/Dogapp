import Foundation

struct ChallengeService {

    static func update(
        challenges: inout [Challenge],
        activities: [DailyActivity],
        behaviorEvents: [BehaviorEvent],
        currentStreak: Int
    ) -> [Challenge] {
        var awarded: [Challenge] = []
        for i in challenges.indices {
            guard !challenges[i].isCompleted else { continue }
            let newProgress = computeProgress(
                type: challenges[i].type,
                activities: activities,
                events: behaviorEvents,
                streak: currentStreak
            )
            challenges[i].progress = newProgress
            if newProgress >= challenges[i].type.requirement {
                challenges[i].isCompleted = true
                challenges[i].completedDate = Date()
                awarded.append(challenges[i])
            }
        }
        return awarded
    }

    private static func computeProgress(
        type: Challenge.ChallengeType,
        activities: [DailyActivity],
        events: [BehaviorEvent],
        streak: Int
    ) -> Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        switch type {

        case .walkFor7Days:
            let walkDays = Set(
                activities.filter { $0.type == .walking && $0.completed }
                          .map { fmt.string(from: $0.date) }
            )
            return min(walkDays.count, 7)

        case .calmWalksFor5Days:
            let walkDays = activities.filter { $0.type == .walking && $0.completed }
                                     .map { fmt.string(from: $0.date) }
            let pullingDays = Set(
                events.filter { $0.issues.contains(.leashPulling) }
                      .map { fmt.string(from: $0.date) }
            )
            let calmDays = Set(walkDays).subtracting(pullingDays)
            return min(calmDays.count, 5)

        case .completeFullDayFor3Days:
            let byDay = Dictionary(grouping: activities.filter { $0.completed }) {
                fmt.string(from: $0.date)
            }
            let fullDays = byDay.filter { _, acts in
                Set(acts.map { $0.type }).count >= 4
            }
            return min(fullDays.count, 3)

        case .logActivitiesFor7Days:
            let activeDays = Set(
                activities.filter { $0.completed }.map { fmt.string(from: $0.date) }
            )
            return min(activeDays.count, 7)

        case .reportIssuesHonestlyFor5Days:
            let daysWithIssues = Set(
                events.filter { $0.hasRealIssues }.map { fmt.string(from: $0.date) }
            )
            return min(daysWithIssues.count, 5)
        }
    }
}
