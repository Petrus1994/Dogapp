import Foundation

// MARK: - Cycle phase

enum CyclePhase: String, Codable, CaseIterable {
    case sleep    = "sleep"
    case toilet   = "toilet"
    case physical = "physical"
    case mental   = "mental"
    case feeding  = "feeding"

    var displayName: String {
        switch self {
        case .sleep:    return "Rest"
        case .toilet:   return "Toilet break"
        case .physical: return "Physical activity"
        case .mental:   return "Mental exercise"
        case .feeding:  return "Feeding"
        }
    }

    var icon: String {
        switch self {
        case .sleep:    return "😴"
        case .toilet:   return "🌿"
        case .physical: return "🦮"
        case .mental:   return "🧠"
        case .feeding:  return "🍖"
        }
    }

    var notificationMessage: String {
        switch self {
        case .sleep:    return "Rest time — let your dog settle down."
        case .toilet:   return "Toilet break time! Take your dog outside now."
        case .physical: return "Time for a short activity session."
        case .mental:   return "Quick mental exercise — 5 minutes makes a difference."
        case .feeding:  return "Feeding time."
        }
    }

    /// Whether this phase maps to a loggable DailyActivity
    var linkedActivityType: DailyActivity.ActivityType? {
        switch self {
        case .physical: return .walking
        case .mental:   return .training
        case .feeding:  return .feeding
        case .sleep, .toilet: return nil
        }
    }

    /// Whether this phase counts toward the daily "activity" score
    var isTrackable: Bool { linkedActivityType != nil }
}

// MARK: - Routine cycle

struct RoutineCycle: Codable, Identifiable {
    var id: String
    var cycleNumber: Int               // which repeating cycle (1-based)
    var phase: CyclePhase
    var suggestedTime: Date            // suggested wall-clock time
    var expectedDurationMinutes: Int   // how long this phase should take
    var isCompleted: Bool
    var completedAt: Date?
    var linkedActivityId: String?      // set when user logs an activity for this phase
    var skipped: Bool                  // user explicitly skipped

    init(
        id: String, cycleNumber: Int, phase: CyclePhase,
        suggestedTime: Date, expectedDurationMinutes: Int,
        isCompleted: Bool = false, completedAt: Date? = nil,
        linkedActivityId: String? = nil, skipped: Bool = false
    ) {
        self.id = id; self.cycleNumber = cycleNumber; self.phase = phase
        self.suggestedTime = suggestedTime
        self.expectedDurationMinutes = expectedDurationMinutes
        self.isCompleted = isCompleted; self.completedAt = completedAt
        self.linkedActivityId = linkedActivityId; self.skipped = skipped
    }

    var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: suggestedTime)
    }

    var isPast: Bool { suggestedTime < Date() }
}

// MARK: - Daily routine

struct DailyRoutine: Codable {
    var date: Date
    var dogProfileId: String
    var cycles: [RoutineCycle]
    var generatedAt: Date

    init(date: Date, dogProfileId: String, cycles: [RoutineCycle]) {
        self.date = date; self.dogProfileId = dogProfileId
        self.cycles = cycles; self.generatedAt = Date()
    }

    var completionFraction: Double {
        guard !cycles.isEmpty else { return 0 }
        let actionable = cycles.filter { !$0.skipped }
        guard !actionable.isEmpty else { return 1 }
        return Double(actionable.filter { $0.isCompleted }.count) / Double(actionable.count)
    }

    var currentCycle: RoutineCycle? {
        cycles.first { !$0.isCompleted && !$0.skipped }
    }

    var nextCycle: RoutineCycle? {
        let pending = cycles.filter { !$0.isCompleted && !$0.skipped }
        return pending.count > 1 ? pending[1] : nil
    }

    var completedCount: Int { cycles.filter { $0.isCompleted }.count }
    var totalCount: Int { cycles.filter { !$0.skipped }.count }

    // Phases that need attention right now (past suggested time, not done)
    var overduePhases: [RoutineCycle] {
        cycles.filter { !$0.isCompleted && !$0.skipped && $0.isPast }
    }
}
