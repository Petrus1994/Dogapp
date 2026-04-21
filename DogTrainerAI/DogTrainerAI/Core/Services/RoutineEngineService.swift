import Foundation

struct RoutineEngineService {

    // MARK: - Public entry point

    /// Generate a complete daily routine for a dog profile, starting from a given wake time.
    static func generate(for profile: DogProfile, wakeTime: Date = defaultWakeTime()) -> DailyRoutine {
        let phase        = profile.currentPhase
        let cycleCount   = phase.cyclesPerDay
        let feedingCount = phase.feedingsPerDay
        let sleepMin     = phase.sleepMinPerCycle
        let activityMin  = phase.activityMinutes(for: profile.activityLevel)
        let mentalMin    = phase.trainingMaxPerSession

        // Space cycles evenly across 16 waking hours
        let wakingSeconds = 16.0 * 3600.0
        let cycleSeconds  = wakingSeconds / Double(cycleCount)

        var cycles: [RoutineCycle] = []
        var idCounter = 0
        var feedingsScheduled = 0

        for c in 0..<cycleCount {
            let cycleStart = wakeTime.addingTimeInterval(Double(c) * cycleSeconds)
            var offset: TimeInterval = 0

            func makeId() -> String { idCounter += 1; return "\(idCounter)" }

            // 1. Wake / toilet immediately
            cycles.append(RoutineCycle(
                id: makeId(), cycleNumber: c + 1, phase: .toilet,
                suggestedTime: cycleStart,
                expectedDurationMinutes: 5
            ))
            offset += 5 * 60

            // 2. Physical activity
            let physTime = cycleStart.addingTimeInterval(offset)
            cycles.append(RoutineCycle(
                id: makeId(), cycleNumber: c + 1, phase: .physical,
                suggestedTime: physTime,
                expectedDurationMinutes: activityMin
            ))
            offset += Double(activityMin) * 60

            // 3. Feeding (distributed evenly across cycles)
            let feedingEvery = max(1, cycleCount / feedingCount)
            if c % feedingEvery == 0 && feedingsScheduled < feedingCount {
                let feedTime = cycleStart.addingTimeInterval(offset)
                cycles.append(RoutineCycle(
                    id: makeId(), cycleNumber: c + 1, phase: .feeding,
                    suggestedTime: feedTime,
                    expectedDurationMinutes: 10
                ))
                offset += 10 * 60
                feedingsScheduled += 1

                // Toilet 15 min after feeding
                cycles.append(RoutineCycle(
                    id: makeId(), cycleNumber: c + 1, phase: .toilet,
                    suggestedTime: cycleStart.addingTimeInterval(offset + 5 * 60),
                    expectedDurationMinutes: 5
                ))
                offset += 20 * 60
            }

            // 4. Mental exercise (every other cycle for very young puppies, every cycle for others)
            let mentalEvery = phase.isVeryYoung ? 2 : 1
            if c % mentalEvery == 0 {
                cycles.append(RoutineCycle(
                    id: makeId(), cycleNumber: c + 1, phase: .mental,
                    suggestedTime: cycleStart.addingTimeInterval(offset),
                    expectedDurationMinutes: mentalMin
                ))
                offset += Double(mentalMin) * 60
            }

            // 5. Sleep / rest
            let sleepStart = cycleStart.addingTimeInterval(offset)
            let remaining  = cycleSeconds - offset
            let actualSleep = min(max(Double(sleepMin) * 60.0, 900), remaining * 0.85)
            cycles.append(RoutineCycle(
                id: makeId(), cycleNumber: c + 1, phase: .sleep,
                suggestedTime: sleepStart,
                expectedDurationMinutes: Int(actualSleep / 60)
            ))
        }

        return DailyRoutine(date: wakeTime, dogProfileId: profile.id, cycles: cycles)
    }

    // MARK: - Phase-based parameters (now driven by AgePhase, not AgeGroup)

    static func dailyCycleCount(for profile: DogProfile) -> Int {
        profile.currentPhase.cyclesPerDay
    }

    static func feedingsPerDay(for profile: DogProfile) -> Int {
        profile.currentPhase.feedingsPerDay
    }

    static func activityDurationMinutes(for profile: DogProfile) -> Int {
        profile.currentPhase.activityMinutes(for: profile.activityLevel)
    }

    static func mentalDurationMinutes(for profile: DogProfile) -> Int {
        profile.currentPhase.trainingMaxPerSession
    }

    // MARK: - Legacy AgeGroup overloads kept for backward compat

    static func dailyCycleCount(for age: DogProfile.AgeGroup) -> Int {
        AgePhase.from(ageGroup: age).cyclesPerDay
    }

    static func feedingsPerDay(for age: DogProfile.AgeGroup) -> Int {
        AgePhase.from(ageGroup: age).feedingsPerDay
    }

    static func activityDurationMinutes(for age: DogProfile.AgeGroup,
                                        energy: DogProfile.ActivityLevel) -> Int {
        AgePhase.from(ageGroup: age).activityMinutes(for: energy)
    }

    static func mentalDurationMinutes(for age: DogProfile.AgeGroup) -> Int {
        AgePhase.from(ageGroup: age).trainingMaxPerSession
    }

    private static func defaultWakeTime() -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }

    // MARK: - Routine coaching messages

    static func balanceMessage(routine: DailyRoutine, activities: [DailyActivity]) -> String? {
        let physicalDone = activities.filter { $0.type == .walking || $0.type == .playing }.count
        let expectedPhysical = routine.cycles.filter { $0.phase == .physical }.count

        if physicalDone == 0 && routine.overduePhases.contains(where: { $0.phase == .physical }) {
            return "Your dog's physical activity is overdue. Even a 10-minute walk now helps more than nothing."
        }
        if routine.completionFraction < 0.4 && Date().timeIntervalSince(routine.date) > 8 * 3600 {
            return "Less than 40% of today's routine is done. Dogs thrive on structure — try to complete at least one more cycle."
        }
        if physicalDone < expectedPhysical / 2 {
            return "Physical activity is falling behind today. This can cause restlessness and difficulty focusing during training."
        }
        return nil
    }
}

