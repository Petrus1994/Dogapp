import Foundation

struct AdaptivePatternLearningService {

    // MARK: - Learn from toilet event history

    /// Analyzes recent toilet events and updates the adaptive pattern for this dog.
    static func learn(
        from events: [ToiletEvent],
        currentPattern: AdaptiveDogPattern
    ) -> AdaptiveDogPattern {
        let successEvents = events.filter { $0.outcome == .success || $0.outcome == .accident }
        guard !successEvents.isEmpty else { return currentPattern }

        var pattern = currentPattern

        // Learn toilet-after-feeding delay
        let afterFeedingEvents = successEvents.compactMap { $0.minutesAfterLastFeeding }
        if afterFeedingEvents.count >= 3 {
            pattern.toiletAfterFeedingMinutes = movingAverage(afterFeedingEvents, weight: 0.3)
        }

        // Learn toilet-after-sleep delay
        let afterSleepEvents = successEvents.compactMap { $0.minutesAfterLastSleep }
        if afterSleepEvents.count >= 3 {
            pattern.toiletAfterSleepMinutes = movingAverage(afterSleepEvents, weight: 0.3)
        }

        pattern.sampleCount  = successEvents.count
        pattern.lastLearnedDate = Date()

        return pattern
    }

    // MARK: - Detect if toilet reminders should be earlier or later

    struct PatternInsight {
        let shouldAdjustEarlier: Bool   // accidents happening — window too long
        let shouldAdjustLater: Bool     // lots of "prompted but nothing happened" — window too short
        let accidentRate: Double        // 0.0–1.0
        let message: String?
    }

    static func analyze(events: [ToiletEvent], dogName: String) -> PatternInsight {
        guard !events.isEmpty else {
            return PatternInsight(shouldAdjustEarlier: false, shouldAdjustLater: false,
                                  accidentRate: 0, message: nil)
        }

        let total     = Double(events.count)
        let accidents = Double(events.filter { $0.outcome == .accident }.count)
        let prompted  = Double(events.filter { $0.outcome == .prompted }.count)
        let accidentRate = accidents / total
        let promptedRate = prompted / total

        var message: String?
        if accidentRate > 0.25 {
            message = "\(dogName) is having accidents more often than expected. Try taking them out sooner — the timing window may be shorter than average for this dog."
        } else if promptedRate > 0.4 {
            message = "You're often taking \(dogName) out before they actually need to go. The intervals may be a bit long — try extending by 5 minutes and see if that improves."
        }

        return PatternInsight(
            shouldAdjustEarlier: accidentRate > 0.25,
            shouldAdjustLater:   promptedRate > 0.4,
            accidentRate: accidentRate,
            message: message
        )
    }

    // MARK: - Check if routine should be regenerated due to aging

    static func shouldRegenerateRoutine(lastPhaseId: String?, currentPhase: AgePhase) -> Bool {
        guard let last = lastPhaseId else { return true }
        return last != currentPhase.id
    }

    // MARK: - Helpers

    private static func movingAverage(_ values: [Int], weight: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        // Weighted toward recent values
        var result = Double(values.first!)
        for v in values.dropFirst() {
            result = result * (1 - weight) + Double(v) * weight
        }
        return result
    }
}
