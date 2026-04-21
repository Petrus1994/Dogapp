import Foundation

struct ScoringService {

    struct ScoreEvent {
        let points: Int
        let reason: String
    }

    // MARK: - Point awards

    static func pointsFor(activity: DailyActivity) -> ScoreEvent {
        ScoreEvent(points: activity.type.pointValue, reason: "\(activity.type.displayName) logged")
    }

    static func pointsFor(feedbackResult: TaskFeedback.FeedbackResult) -> ScoreEvent {
        switch feedbackResult {
        case .success:
            return ScoreEvent(points: 10, reason: "Task completed")
        case .partial:
            // Honesty rewarded — partial is almost as valuable as success
            return ScoreEvent(points: 8, reason: "Honest partial feedback")
        case .failed:
            // Still reward honesty; failure = useful signal
            return ScoreEvent(points: 5, reason: "Honest — keep going")
        }
    }

    static func pointsFor(behaviorIssueCount: Int) -> ScoreEvent {
        if behaviorIssueCount > 0 {
            // Reporting real issues is actively rewarded
            let pts = min(behaviorIssueCount * 3, 15)
            return ScoreEvent(points: pts, reason: "Honest behavior report")
        } else {
            return ScoreEvent(points: 2, reason: "All-clear report")
        }
    }

    static func normMetBonus(for type: DailyActivity.ActivityType) -> ScoreEvent {
        ScoreEvent(points: 5, reason: "\(type.displayName) daily target met")
    }

    static func fullDayBonus() -> ScoreEvent {
        ScoreEvent(points: 15, reason: "Full daily routine completed")
    }

    static func streakBonus(streak: Int) -> ScoreEvent {
        let pts = min(streak * 2, 20)
        return ScoreEvent(points: pts, reason: "Day \(streak) streak bonus")
    }

    // MARK: - Level calculation

    static func levelFor(points: Int) -> UserProgress.UserLevel {
        for level in UserProgress.UserLevel.allCases.reversed() {
            if points >= level.pointsRequired { return level }
        }
        return .beginner
    }

    // MARK: - Anti-cheat

    static func antiCheatMessage(for progress: UserProgress) -> String? {
        guard progress.shouldShowAntiCheatPrompt else { return nil }
        if progress.consecutiveNoIssuesCount >= 14 {
            return "Everything has been perfect lately — just make sure you're not missing small inconsistencies. Honest tracking helps your dog the most."
        }
        if progress.consecutiveSuccessCount >= 7 {
            return "Great streak! Real training rarely goes perfectly every time. If you're struggling with anything, logging it honestly helps us give better advice."
        }
        return nil
    }
}
