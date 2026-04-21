import Foundation

struct ToiletEvent: Codable, Identifiable {
    var id: String
    var date: Date
    var outcome: Outcome
    var minutesAfterLastFeeding: Int?   // set when a feeding was logged before this
    var minutesAfterLastSleep: Int?     // set when sleep/wake was logged before this
    var notes: String

    enum Outcome: String, Codable, CaseIterable {
        case success  // went outside, result positive
        case accident // happened indoors before they were taken out
        case prompted // taken outside but nothing happened (timing early)

        var displayName: String {
            switch self {
            case .success:  return "Went outside ✓"
            case .accident: return "Accident indoors"
            case .prompted: return "Taken out, nothing happened"
            }
        }

        var icon: String {
            switch self {
            case .success:  return "✅"
            case .accident: return "💧"
            case .prompted: return "⏰"
            }
        }

        var color: String {
            switch self {
            case .success:  return "green"
            case .accident: return "orange"
            case .prompted: return "secondary"
            }
        }
    }
}

// MARK: - Adaptive pattern (learned from toilet history)

struct AdaptiveDogPattern: Codable {
    /// Learned average minutes between waking and needing toilet. nil = use phase default.
    var toiletAfterSleepMinutes: Double?

    /// Learned average minutes between finishing a meal and needing toilet.
    var toiletAfterFeedingMinutes: Double?

    /// Learned max training session before the dog shows fatigue signs.
    var trainingFatigueMinutes: Double?

    /// Learned average activity duration before energy visibly drops.
    var activityFatigueMinutes: Double?

    var lastLearnedDate: Date?
    var sampleCount: Int   // how many toilet events were used for learning

    static let empty = AdaptiveDogPattern(
        toiletAfterSleepMinutes: nil,
        toiletAfterFeedingMinutes: nil,
        trainingFatigueMinutes: nil,
        activityFatigueMinutes: nil,
        lastLearnedDate: nil,
        sampleCount: 0
    )

    /// Resolved toilet-after-feeding delay: learned value or phase default.
    func resolvedToiletAfterFeeding(phaseDefault: Int) -> Int {
        Int(toiletAfterFeedingMinutes ?? Double(phaseDefault))
    }

    func resolvedToiletAfterSleep(phaseDefault: Int) -> Int {
        Int(toiletAfterSleepMinutes ?? Double(phaseDefault))
    }
}
