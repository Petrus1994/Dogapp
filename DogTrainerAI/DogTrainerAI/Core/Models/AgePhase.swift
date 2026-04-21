import Foundation

/// Granular behavioral development phase, computed from exact age.
struct AgePhase: Equatable {
    let id: String
    let displayName: String
    let ageRangeMonths: ClosedRange<Double>

    // Routine
    let cyclesPerDay: Int
    let activityMinPerSession: Int      // recommended single session duration
    let trainingMaxPerSession: Int      // hard ceiling — overtraining prevention
    let sleepMinPerCycle: Int

    // Toilet timing (baseline — overridden by learned pattern)
    let toiletAfterSleepMinutes: Int    // how soon after waking to expect a need
    let toiletAfterFeedingMinutes: Int  // how soon after eating to expect a need
    let toiletIntervalMinutes: Int      // max gap before next likely need

    // Feeding
    let feedingsPerDay: Int

    // Social restrictions
    let socialNote: String?             // vaccination / outdoor restriction guidance

    // MARK: - Phase library

    static let phases: [AgePhase] = [
        AgePhase(
            id: "neonatal", displayName: "Neonatal",
            ageRangeMonths: 0.0...1.75,
            cyclesPerDay: 10, activityMinPerSession: 5, trainingMaxPerSession: 0,
            sleepMinPerCycle: 90, toiletAfterSleepMinutes: 2, toiletAfterFeedingMinutes: 5,
            toiletIntervalMinutes: 60, feedingsPerDay: 4,
            socialNote: "Keep interactions calm and gentle. No outdoor exposure yet."
        ),
        AgePhase(
            id: "early_puppy", displayName: "Early Puppy (2–3 mo)",
            ageRangeMonths: 1.75...3.5,
            cyclesPerDay: 8, activityMinPerSession: 10, trainingMaxPerSession: 3,
            sleepMinPerCycle: 90, toiletAfterSleepMinutes: 2, toiletAfterFeedingMinutes: 10,
            toiletIntervalMinutes: 60, feedingsPerDay: 4,
            socialNote: "Limited outdoor contact. Focus on indoor socialization, handling, and calm routines."
        ),
        AgePhase(
            id: "core_puppy", displayName: "Core Puppy (3–5 mo)",
            ageRangeMonths: 3.5...5.5,
            cyclesPerDay: 5, activityMinPerSession: 20, trainingMaxPerSession: 5,
            sleepMinPerCycle: 75, toiletAfterSleepMinutes: 3, toiletAfterFeedingMinutes: 15,
            toiletIntervalMinutes: 90, feedingsPerDay: 3,
            socialNote: "From ~4 months, outdoor socialization can expand cautiously after vaccination."
        ),
        AgePhase(
            id: "late_puppy", displayName: "Late Puppy (5–8 mo)",
            ageRangeMonths: 5.5...8.0,
            cyclesPerDay: 4, activityMinPerSession: 25, trainingMaxPerSession: 8,
            sleepMinPerCycle: 60, toiletAfterSleepMinutes: 5, toiletAfterFeedingMinutes: 20,
            toiletIntervalMinutes: 120, feedingsPerDay: 3,
            socialNote: "Active socialization phase. Leash manners, calm greetings, and environment exposure."
        ),
        AgePhase(
            id: "adolescent", displayName: "Adolescent (8–12 mo)",
            ageRangeMonths: 8.0...12.0,
            cyclesPerDay: 3, activityMinPerSession: 30, trainingMaxPerSession: 10,
            sleepMinPerCycle: 50, toiletAfterSleepMinutes: 5, toiletAfterFeedingMinutes: 20,
            toiletIntervalMinutes: 180, feedingsPerDay: 2,
            socialNote: "Hormonal changes may affect behavior. Consistent routine is critical."
        ),
        AgePhase(
            id: "young_adult", displayName: "Young Adult (1–3 yr)",
            ageRangeMonths: 12.0...36.0,
            cyclesPerDay: 2, activityMinPerSession: 40, trainingMaxPerSession: 15,
            sleepMinPerCycle: 40, toiletAfterSleepMinutes: 10, toiletAfterFeedingMinutes: 30,
            toiletIntervalMinutes: 240, feedingsPerDay: 2,
            socialNote: nil
        ),
        AgePhase(
            id: "adult", displayName: "Adult (3–7 yr)",
            ageRangeMonths: 36.0...84.0,
            cyclesPerDay: 2, activityMinPerSession: 35, trainingMaxPerSession: 15,
            sleepMinPerCycle: 40, toiletAfterSleepMinutes: 10, toiletAfterFeedingMinutes: 30,
            toiletIntervalMinutes: 300, feedingsPerDay: 2,
            socialNote: nil
        ),
        AgePhase(
            id: "senior", displayName: "Senior (7+ yr)",
            ageRangeMonths: 84.0...240.0,
            cyclesPerDay: 2, activityMinPerSession: 20, trainingMaxPerSession: 10,
            sleepMinPerCycle: 50, toiletAfterSleepMinutes: 5, toiletAfterFeedingMinutes: 20,
            toiletIntervalMinutes: 180, feedingsPerDay: 2,
            socialNote: "Senior dogs may need shorter, more frequent outings."
        )
    ]

    // MARK: - Lookup

    static func from(ageInMonths: Double) -> AgePhase {
        phases.first { $0.ageRangeMonths.contains(ageInMonths) } ?? phases.last!
    }

    static func from(ageGroup: DogProfile.AgeGroup) -> AgePhase {
        switch ageGroup {
        case .under2Months:    return from(ageInMonths: 1.5)
        case .twoTo3Months:    return from(ageInMonths: 2.5)
        case .threeTo5Months:  return from(ageInMonths: 4.0)
        case .sixTo8Months:    return from(ageInMonths: 7.0)
        case .eightTo12Months: return from(ageInMonths: 10.0)
        case .oneToThreeYears, .overOneYear: return from(ageInMonths: 18.0)
        case .threeToSevenYears:             return from(ageInMonths: 48.0)
        case .overSevenYears:                return from(ageInMonths: 96.0)
        }
    }

    // MARK: - Energy multiplier

    func activityMinutes(for energy: DogProfile.ActivityLevel) -> Int {
        switch energy {
        case .low:    return Int(Double(activityMinPerSession) * 0.7)
        case .medium: return activityMinPerSession
        case .high:   return Int(Double(activityMinPerSession) * 1.4)
        }
    }

    var isPuppy: Bool { cyclesPerDay >= 4 }
    var isVeryYoung: Bool { ageRangeMonths.lowerBound < 3.5 }
}
