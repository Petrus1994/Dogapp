import Foundation

struct AgeProgressionService {

    struct AgeProgressionEvent {
        let previousPhaseId: String
        let newPhase: AgePhase
        let dogName: String

        var announcementMessage: String {
            "\(dogName) has grown into a new stage: \(newPhase.displayName). The daily routine and activity recommendations have been updated automatically."
        }
    }

    // MARK: - Check if dog has aged into a new phase

    /// Call this on app launch. Returns a progression event if the dog crossed a phase boundary.
    static func checkProgression(
        profile: DogProfile,
        lastKnownPhaseId: String?
    ) -> AgeProgressionEvent? {
        let currentPhase = profile.currentPhase
        guard let lastId = lastKnownPhaseId else {
            return nil  // first launch — no comparison
        }
        guard lastId != currentPhase.id else {
            return nil  // same phase — no change
        }
        return AgeProgressionEvent(
            previousPhaseId: lastId,
            newPhase: currentPhase,
            dogName: profile.name
        )
    }

    // MARK: - Auto-update AgeGroup from birthDate

    /// If the dog has a birthDate, derive and update the ageGroup field for display purposes.
    static func syncAgeGroup(profile: inout DogProfile) {
        guard let _ = profile.birthDate else { return }
        let months = profile.exactAgeInMonths

        let newGroup: DogProfile.AgeGroup
        switch months {
        case ..<1.75:   newGroup = .under2Months
        case ..<3.5:    newGroup = .twoTo3Months
        case ..<5.5:    newGroup = .threeTo5Months
        case ..<8.0:    newGroup = .sixTo8Months
        case ..<12.0:   newGroup = .eightTo12Months
        case ..<36.0:   newGroup = .oneToThreeYears
        case ..<84.0:   newGroup = .threeToSevenYears
        default:        newGroup = .overSevenYears
        }

        profile.ageGroup = newGroup
    }

    // MARK: - How long until next phase

    static func daysUntilNextPhase(profile: DogProfile) -> Int? {
        let currentPhase  = profile.currentPhase
        guard let nextPhase = nextPhase(after: currentPhase) else { return nil }
        let targetMonths  = nextPhase.ageRangeMonths.lowerBound
        let targetDays    = targetMonths * 30.44
        let daysLeft      = Int(targetDays) - profile.exactAgeInDays
        return max(0, daysLeft)
    }

    private static func nextPhase(after phase: AgePhase) -> AgePhase? {
        let phases = AgePhase.phases
        guard let idx = phases.firstIndex(where: { $0.id == phase.id }),
              idx + 1 < phases.count else { return nil }
        return phases[idx + 1]
    }

    // MARK: - Activity norm for exact age + energy

    static func activityNorms(for profile: DogProfile) -> ActivityNorms {
        let phase  = profile.currentPhase
        let energy = profile.activityLevel

        let walkMin = phase.activityMinutes(for: energy)
        let playMin = Int(Double(phase.activityMinPerSession) * 0.6)

        return ActivityNorms(
            walkMinPerDay:           walkMin * min(phase.cyclesPerDay, 2),
            walkDistanceKmPerDay:    Double(walkMin * min(phase.cyclesPerDay, 2)) / 30.0 * 2.0,
            walkSessionsPerDay:      min(phase.cyclesPerDay, 3),
            playMinPerDay:           playMin * min(phase.cyclesPerDay, 3),
            playSessionsPerDay:      min(phase.cyclesPerDay, 3),
            trainingMinPerSession:   phase.trainingMaxPerSession,
            trainingSessionsPerDay:  max(1, phase.cyclesPerDay / 2),
            feedingsPerDay:          phase.feedingsPerDay
        )
    }
}
