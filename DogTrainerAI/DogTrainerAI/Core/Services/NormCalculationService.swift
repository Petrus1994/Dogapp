import Foundation

struct NormCalculationService {

    /// Compute daily activity norms based on the dog's profile.
    /// Uses `effectiveActivityLevel` so overrides are respected.
    static func norms(for profile: DogProfile) -> ActivityNorms {
        let age    = profile.ageGroup
        let energy = profile.effectiveActivityLevel

        return ActivityNorms(
            walkMinPerDay:           walkMinutes(age: age, energy: energy),
            walkDistanceKmPerDay:    walkDistanceKm(age: age, energy: energy),
            walkSessionsPerDay:      walkSessions(age: age),
            playMinPerDay:           playMinutes(age: age, energy: energy),
            playSessionsPerDay:      playSessions(age: age),
            trainingMinPerSession:   trainingMaxPerSession(age: age),
            trainingSessionsPerDay:  trainingSessions(age: age),
            feedingsPerDay:          feedings(age: age)
        )
    }

    // MARK: - Walk

    private static func walkMinutes(age: DogProfile.AgeGroup, energy: DogProfile.ActivityLevel) -> Int {
        let base: Int
        switch age {
        case .under2Months:    base = 5      // < 8 weeks: no walks
        case .twoTo3Months:    base = 10
        case .threeTo5Months:  base = 20
        case .sixTo8Months:    base = 30
        case .eightTo12Months: base = 40
        case .oneToThreeYears, .overOneYear: base = 50
        case .threeToSevenYears:             base = 45
        case .overSevenYears:                base = 30
        }
        let multiplier: Double
        switch energy {
        case .low:    multiplier = 0.7
        case .medium: multiplier = 1.0
        case .high:   multiplier = 1.5
        }
        return Int(Double(base) * multiplier)
    }

    private static func walkDistanceKm(age: DogProfile.AgeGroup, energy: DogProfile.ActivityLevel) -> Double {
        let minutes = Double(walkMinutes(age: age, energy: energy))
        return (minutes / 30.0) * 2.0  // ~2 km per 30 min average
    }

    private static func walkSessions(age: DogProfile.AgeGroup) -> Int {
        switch age {
        case .under2Months:    return 0
        case .twoTo3Months:    return 2
        case .threeTo5Months:  return 3
        case .sixTo8Months, .eightTo12Months: return 3
        case .oneToThreeYears, .overOneYear:  return 2
        case .threeToSevenYears:              return 2
        case .overSevenYears:                 return 2
        }
    }

    // MARK: - Play

    private static func playMinutes(age: DogProfile.AgeGroup, energy: DogProfile.ActivityLevel) -> Int {
        let base: Int
        switch age {
        case .under2Months, .twoTo3Months: base = 15
        case .threeTo5Months:              base = 20
        case .sixTo8Months:                base = 30
        case .eightTo12Months:             base = 30
        case .oneToThreeYears, .overOneYear: base = 30
        case .threeToSevenYears:             base = 25
        case .overSevenYears:                base = 20
        }
        switch energy {
        case .low:    return Int(Double(base) * 0.75)
        case .medium: return base
        case .high:   return Int(Double(base) * 1.3)
        }
    }

    private static func playSessions(age: DogProfile.AgeGroup) -> Int {
        switch age {
        case .under2Months, .twoTo3Months:
            return 4   // frequent short bursts
        case .threeTo5Months, .sixTo8Months:
            return 3
        case .eightTo12Months, .oneToThreeYears, .overOneYear:
            return 2
        case .threeToSevenYears, .overSevenYears:
            return 1
        }
    }

    // MARK: - Training

    private static func trainingMaxPerSession(age: DogProfile.AgeGroup) -> Int {
        switch age {
        case .under2Months, .twoTo3Months:  return 3
        case .threeTo5Months:               return 5
        case .sixTo8Months:                 return 8
        case .eightTo12Months:              return 10
        case .oneToThreeYears, .overOneYear: return 15
        case .threeToSevenYears:             return 15
        case .overSevenYears:                return 10
        }
    }

    private static func trainingSessions(age: DogProfile.AgeGroup) -> Int {
        switch age {
        case .under2Months:    return 0
        case .twoTo3Months:    return 2
        case .threeTo5Months:  return 3
        case .sixTo8Months, .eightTo12Months: return 3
        case .oneToThreeYears, .overOneYear:  return 2
        case .threeToSevenYears, .overSevenYears: return 1
        }
    }

    // MARK: - Feeding

    private static func feedings(age: DogProfile.AgeGroup) -> Int {
        switch age {
        case .under2Months:    return 4
        case .twoTo3Months:    return 4
        case .threeTo5Months:  return 3
        case .sixTo8Months:    return 3
        case .eightTo12Months: return 3
        case .oneToThreeYears, .overOneYear: return 2
        case .threeToSevenYears:             return 2
        case .overSevenYears:                return 2
        }
    }

    // MARK: - Norm completion

    /// Returns 0.0–1.0 completion fraction for walk duration vs norm.
    /// Counts parkSession as walk (half its duration attributed to walking).
    static func walkCompletion(activities: [DailyActivity], norms: ActivityNorms) -> Double {
        let totalMin = activities.filter { $0.completed }.reduce(0) { sum, a in
            if a.type == .walking    { return sum + a.durationMinutes }
            if a.type == .parkSession{ return sum + a.durationMinutes / 2 }
            return sum
        }
        guard norms.walkMinPerDay > 0 else { return 1.0 }
        return min(Double(totalMin) / Double(norms.walkMinPerDay), 1.0)
    }

    /// Returns 0.0–1.0 for play minutes vs norm.
    /// Counts parkSession as play (half its duration attributed to play).
    static func playCompletion(activities: [DailyActivity], norms: ActivityNorms) -> Double {
        let totalMin = activities.filter { $0.completed }.reduce(0) { sum, a in
            if a.type == .playing    { return sum + a.durationMinutes }
            if a.type == .parkSession{ return sum + a.durationMinutes / 2 }
            return sum
        }
        guard norms.playMinPerDay > 0 else { return 1.0 }
        return min(Double(totalMin) / Double(norms.playMinPerDay), 1.0)
    }

    /// Returns 0.0–1.0 for feeding count vs recommended.
    static func feedingCompletion(activities: [DailyActivity], norms: ActivityNorms) -> Double {
        let count = activities.filter { $0.type == .feeding && $0.completed }.count
        guard norms.feedingsPerDay > 0 else { return 1.0 }
        return min(Double(count) / Double(norms.feedingsPerDay), 1.0)
    }

    /// Returns 0.0–1.0 for training — also penalises overtraining.
    static func trainingCompletion(activities: [DailyActivity], norms: ActivityNorms) -> Double {
        let sessions = activities.filter { $0.type == .training && $0.completed }
        guard !sessions.isEmpty else { return 0.0 }
        let sessionsDone  = Double(sessions.count)
        let sessionTarget = Double(norms.trainingSessionsPerDay)
        // Cap at 100% — overtraining doesn't score higher
        return min(sessionsDone / sessionTarget, 1.0)
    }

    /// Aggregate completion across all 4 activity types (equal weight).
    static func overallCompletion(activities: [DailyActivity], norms: ActivityNorms) -> Double {
        let scores = [
            walkCompletion(activities: activities, norms: norms),
            playCompletion(activities: activities, norms: norms),
            feedingCompletion(activities: activities, norms: norms),
            trainingCompletion(activities: activities, norms: norms)
        ]
        return scores.reduce(0, +) / Double(scores.count)
    }
}
