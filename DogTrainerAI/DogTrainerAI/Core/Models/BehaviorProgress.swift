import Foundation

// MARK: - Dimension enum

enum BehaviorDimension: String, Codable, CaseIterable {
    case foodBehavior       = "food_behavior"
    case activityExcitement = "activity_excitement"
    case ownerContact       = "owner_contact"
    case socialization      = "socialization"

    var displayName: String {
        switch self {
        case .foodBehavior:       return "Nutrition"
        case .activityExcitement: return "Activity"
        case .ownerContact:       return "Bond"
        case .socialization:      return "Training"
        }
    }

    var icon: String {
        switch self {
        case .foodBehavior:       return "🍖"
        case .activityExcitement: return "⚡"
        case .ownerContact:       return "❤️"
        case .socialization:      return "🧠"
        }
    }

    var goalState: String {
        switch self {
        case .foodBehavior:
            return "Calm, controlled, healthy eating habits"
        case .activityExcitement:
            return "Well-exercised, emotionally balanced"
        case .ownerContact:
            return "Strong connection and trust with owner"
        case .socialization:
            return "Consistent, focused training progress"
        }
    }

    var shortDescription: String {
        switch self {
        case .foodBehavior:
            return "Feeding quality, calmness around food, regularity"
        case .activityExcitement:
            return "Physical activity, energy release, emotional balance"
        case .ownerContact:
            return "Owner focus, responsiveness, bonding quality"
        case .socialization:
            return "Training consistency, skill retention, task completion"
        }
    }
}

// MARK: - Snapshot (one day of data)

struct DimensionSnapshot: Codable {
    var date: Date
    var score: Double        // 0–100, updated score after smoothing
    var dailySignal: Double  // 0–100, raw day quality signal
    var confidence: Double   // 0–100
    var activityCount: Int   // number of inputs this day
}

// MARK: - Dimension score (current state for one dimension)

struct BehaviorDimensionScore: Codable, Identifiable {
    var id: String { dimension.rawValue }
    var dimension: BehaviorDimension
    var score: Double      // 0–100, smoothed
    var trend: Trend
    var confidence: Double // 0–100
    var history: [DimensionSnapshot]

    enum Trend: String, Codable {
        case improving      = "improving"
        case stable         = "stable"
        case needsAttention = "needs_attention"

        var icon: String {
            switch self {
            case .improving:      return "↑"
            case .stable:         return "→"
            case .needsAttention: return "↓"
            }
        }

        var label: String {
            switch self {
            case .improving:      return "Improving"
            case .stable:         return "Stable"
            case .needsAttention: return "Needs attention"
            }
        }
    }

    var scoreLabel: String {
        switch score {
        case 80...: return "Excellent"
        case 65...: return "Good"
        case 50...: return "Developing"
        case 35...: return "Needs work"
        default:    return "Struggling"
        }
    }

    static func initial(for dimension: BehaviorDimension) -> BehaviorDimensionScore {
        BehaviorDimensionScore(
            dimension: dimension,
            score: 50,
            trend: .stable,
            confidence: 0,
            history: []
        )
    }
}

// MARK: - Signal source (one contributing event)

struct SignalSource: Codable {
    var description: String
    var delta: Double // how much this shifts the raw signal
}

// MARK: - Daily signal computation artifact

struct BehaviorDailySignal: Codable {
    var dimension: BehaviorDimension
    var rawSignal: Double // 0–100 aggregate quality for this dimension today
    var sources: [SignalSource]
    var date: Date
}

// MARK: - Persisted progress container

struct BehaviorProgress: Codable {
    var scores: [BehaviorDimensionScore]
    var lastProcessedDate: Date?
    var lastInsight: String?

    static let initial = BehaviorProgress(
        scores: BehaviorDimension.allCases.map { .initial(for: $0) },
        lastProcessedDate: nil,
        lastInsight: nil
    )

    subscript(dimension: BehaviorDimension) -> BehaviorDimensionScore {
        get { scores.first { $0.dimension == dimension } ?? .initial(for: dimension) }
        set {
            if let idx = scores.firstIndex(where: { $0.dimension == dimension }) {
                scores[idx] = newValue
            }
        }
    }
}
