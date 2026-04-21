import Foundation

struct AIProgressInterpreter {

    // MARK: - Insight of the Day (1–2 sentences, shown on TodayView)

    static func dailyInsight(
        progress: BehaviorProgress,
        dogName: String,
        activities: [DailyActivity]
    ) -> String? {
        let scores = progress.scores

        // Find the most prominent story: improving or needs attention
        if let best = scores.filter({ $0.trend == .improving && $0.confidence > 30 }).max(by: { $0.score < $1.score }) {
            return improvingInsight(dimension: best.dimension, score: best.score, dogName: dogName)
        }
        if let worst = scores.filter({ $0.trend == .needsAttention && $0.confidence > 30 }).min(by: { $0.score < $1.score }) {
            return needsAttentionInsight(dimension: worst.dimension, score: worst.score, dogName: dogName)
        }
        // No strong trend — comment on current state
        if let best = scores.filter({ $0.confidence > 40 }).max(by: { $0.score < $1.score }) {
            return stableInsight(dimension: best.dimension, score: best.score, dogName: dogName)
        }
        return nil
    }

    // MARK: - Per-dimension short insight (shown on dimension card)

    static func dimensionInsight(
        score: BehaviorDimensionScore,
        dogName: String
    ) -> String {
        let name = dogName
        let dim  = score.dimension
        let s    = score.score
        let trend = score.trend
        let conf  = score.confidence

        if conf < 20 {
            return "Keep logging daily activities — I'll have more to say about \(name)'s \(dim.displayName.lowercased()) soon."
        }

        switch dim {
        case .foodBehavior:
            if s >= 75 {
                return trend == .improving
                    ? "\(name)'s calm around food is clearly developing. The patience is paying off."
                    : "\(name) handles feeding time well. Structured meals are building good habits."
            } else if s >= 55 {
                return "\(name) is making progress with food manners. Consistent feeding routine will speed things up."
            } else {
                return trend == .needsAttention
                    ? "Food-related issues are increasing. Try reinforcing 'wait' before placing the bowl."
                    : "\(name) needs more practice with food impulse control. Short wait-before-eat exercises help."
            }

        case .activityExcitement:
            if s >= 75 {
                return trend == .improving
                    ? "\(name)'s energy balance is improving. More structured activity = more emotional control."
                    : "\(name) is getting good physical and mental stimulation. Calm focus is the result."
            } else if s >= 50 {
                if activities_missing(score) {
                    return "Less activity than needed today. \(name) may get restless — even a short structured walk helps."
                }
                return "\(name) is getting some activity but excitement can still spike. Structured play over free chaos works better."
            } else {
                return trend == .needsAttention
                    ? "Overexcitement is growing. \(name) likely needs more physical release — longer walks or structured play."
                    : "\(name) needs more consistent daily activity to become calmer and more focused."
            }

        case .ownerContact:
            if s >= 75 {
                return trend == .improving
                    ? "\(name)'s attention to you is strengthening. Short training sessions are building a real bond."
                    : "\(name) is focused and responsive — that connection makes everything else easier to teach."
            } else if s >= 55 {
                return "Your connection with \(name) is developing. Daily training sessions, even 5 minutes, build attention fast."
            } else {
                return trend == .needsAttention
                    ? "\(name) seems to be tuning you out more. Short, positive engagement sessions will help rebuild focus."
                    : "\(name) needs more practice with attention and responsiveness. Eye contact exercises work well here."
            }

        case .socialization:
            if s >= 75 {
                return trend == .improving
                    ? "\(name)'s social confidence is growing. New environments feel safer and reactions are calming down."
                    : "\(name) handles social situations well. Consistent exposure keeps this skill strong."
            } else if s >= 50 {
                return "Some social reactions are still happening. Calm, controlled exposure in low-stress environments is key."
            } else {
                return trend == .needsAttention
                    ? "Social reactions are increasing. Reduce stimulation level during walks and reward calm behavior heavily."
                    : "\(name) needs gradual, positive social exposure. Start in quiet environments and build up slowly."
            }
        }
    }

    // MARK: - Weekly narrative (shareable summary, 3–5 sentences)

    static func weeklySummary(
        progress: BehaviorProgress,
        dogName: String
    ) -> String {
        let scores = progress.scores
        let improving = scores.filter { $0.trend == .improving && $0.confidence > 30 }
        let struggling = scores.filter { $0.trend == .needsAttention && $0.confidence > 30 }

        var parts: [String] = []

        // Opening
        let overallAvg = scores.filter { $0.confidence > 20 }.map { $0.score }.reduce(0, +)
            / max(1, Double(scores.filter { $0.confidence > 20 }.count))
        if overallAvg >= 70 {
            parts.append("\(dogName) is having a great week — consistent training is showing real results.")
        } else if overallAvg >= 55 {
            parts.append("\(dogName) is making steady progress this week. There's clear development happening.")
        } else {
            parts.append("This week has had challenges, but every day of logging helps \(dogName) grow.")
        }

        // Strengths
        if let best = improving.max(by: { $0.score < $1.score }) {
            parts.append("Biggest improvement: \(best.dimension.displayName) — \(shortImprovingNote(best.dimension, dogName)).")
        } else if let stable = scores.filter({ $0.score >= 65 && $0.confidence > 30 }).first {
            parts.append("Strong area: \(stable.dimension.displayName) — \(stable.scoreLabel.lowercased()) and holding steady.")
        }

        // Focus area
        if let worst = struggling.min(by: { $0.score < $1.score }) {
            parts.append("Focus for next week: \(worst.dimension.displayName) — \(shortFocusNote(worst.dimension, dogName)).")
        }

        // Closing
        parts.append("Keep logging every day — the picture of \(dogName)'s development gets clearer with each session.")

        return parts.joined(separator: " ")
    }

    // MARK: - Proactive pattern insight (shown when pattern detected)

    static func proactiveInsight(
        progress: BehaviorProgress,
        dogName: String
    ) -> String? {
        let excitement = progress[.activityExcitement]
        let contact    = progress[.ownerContact]
        let social     = progress[.socialization]

        // Pattern: low activity → high excitement
        if excitement.score < 45 && excitement.trend == .needsAttention {
            return "\(dogName) seems understimulated — overexcitement usually follows low activity days. A structured walk or training session today would help."
        }

        // Pattern: high training → high contact
        if contact.trend == .improving && contact.score > 65 {
            return "Training is working — \(dogName)'s focus on you is improving. Keep including short sessions even on busy days."
        }

        // Pattern: social issues spiking
        if social.trend == .needsAttention && social.score < 50 {
            return "Social reactions have increased lately. Try lower-stimulation walks at quieter times — calm exposure builds confidence faster."
        }

        return nil
    }

    // MARK: - Privates

    private static func improvingInsight(dimension: BehaviorDimension, score: Double, dogName: String) -> String {
        switch dimension {
        case .foodBehavior:
            return "\(dogName)'s behavior around food is improving — calmer mealtimes are a sign of real impulse control developing."
        case .activityExcitement:
            return "Activity and energy balance is trending up. \(dogName) is becoming more regulated after exercise."
        case .ownerContact:
            return "\(dogName)'s attention to you is getting stronger. This makes everything you teach together more effective."
        case .socialization:
            return "Social confidence is building. \(dogName) is handling new situations with more calm."
        }
    }

    private static func needsAttentionInsight(dimension: BehaviorDimension, score: Double, dogName: String) -> String {
        switch dimension {
        case .foodBehavior:
            return "\(dogName)'s food behavior needs some attention today. Try a calm feeding ritual — 'sit and wait' before the bowl goes down."
        case .activityExcitement:
            return "Energy levels suggest \(dogName) needs more structured activity. Overexcitement usually follows under-stimulation."
        case .ownerContact:
            return "\(dogName) may be distracted or disconnected today. Even 5 minutes of focused training can reset this."
        case .socialization:
            return "Some social reactions have increased. Keep walks calm and in lower-stimulation environments for now."
        }
    }

    private static func stableInsight(dimension: BehaviorDimension, score: Double, dogName: String) -> String {
        switch dimension {
        case .foodBehavior:
            return "Feeding routines are consistent. \(dogName)'s food behavior is steady — keep the structure."
        case .activityExcitement:
            return "\(dogName) is getting regular activity. Emotional balance comes with consistent movement and structure."
        case .ownerContact:
            return "Your connection with \(dogName) is stable. Daily training, even short, keeps this strong."
        case .socialization:
            return "\(dogName) is managing social situations steadily. Regular exposure helps maintain this."
        }
    }

    private static func shortImprovingNote(_ dim: BehaviorDimension, _ name: String) -> String {
        switch dim {
        case .foodBehavior:       return "calmer and more patient at mealtimes"
        case .activityExcitement: return "energy is better regulated after activity"
        case .ownerContact:       return "attention and responsiveness are sharper"
        case .socialization:      return "reactions in social situations are softening"
        }
    }

    private static func shortFocusNote(_ dim: BehaviorDimension, _ name: String) -> String {
        switch dim {
        case .foodBehavior:       return "work on calm feeding rituals and food impulse control"
        case .activityExcitement: return "increase structured activity to reduce overexcitement"
        case .ownerContact:       return "add short daily training sessions to rebuild focus"
        case .socialization:      return "gradual, calm exposure in low-stimulation environments"
        }
    }

    private static func activities_missing(_ score: BehaviorDimensionScore) -> Bool {
        // Heuristic: if score is below 55 for activity, likely under-stimulated
        return score.score < 55
    }
}
