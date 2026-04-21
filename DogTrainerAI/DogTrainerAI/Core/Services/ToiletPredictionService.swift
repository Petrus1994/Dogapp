import Foundation

struct ToiletPredictionService {

    struct ToiletPrediction {
        let predictedTime: Date
        let minutesUntil: Int
        let urgency: Double          // 0.0–1.0
        let triggerReason: TriggerReason
        let message: String

        enum TriggerReason {
            case afterSleep(minutesAgo: Int)
            case afterFeeding(minutesAgo: Int)
            case intervalElapsed(intervalMinutes: Int)
        }

        var isPast: Bool { predictedTime < Date() }
    }

    // MARK: - Main prediction

    static func predict(
        lastToiletDate: Date?,
        lastFeedingDate: Date?,
        lastSleepEndDate: Date?,
        phase: AgePhase,
        pattern: AdaptiveDogPattern,
        dogName: String
    ) -> ToiletPrediction? {
        let now = Date()

        // After sleep: highest priority
        if let sleepEnd = lastSleepEndDate,
           now.timeIntervalSince(sleepEnd) < 600 {           // within 10 min of waking
            let expectedDelay = pattern.resolvedToiletAfterSleep(phaseDefault: phase.toiletAfterSleepMinutes)
            let predictedTime  = sleepEnd.addingTimeInterval(Double(expectedDelay) * 60)
            let minutesUntil   = Int(predictedTime.timeIntervalSince(now) / 60)
            return ToiletPrediction(
                predictedTime: predictedTime,
                minutesUntil: minutesUntil,
                urgency: minutesUntil <= 0 ? 0.95 : 0.7,
                triggerReason: .afterSleep(minutesAgo: Int(now.timeIntervalSince(sleepEnd) / 60)),
                message: "\(dogName) just woke up — this is the best moment for a toilet break."
            )
        }

        // After feeding: second priority
        if let feeding = lastFeedingDate {
            let elapsed        = now.timeIntervalSince(feeding)
            let expectedDelay  = pattern.resolvedToiletAfterFeeding(phaseDefault: phase.toiletAfterFeedingMinutes)
            let predictedTime  = feeding.addingTimeInterval(Double(expectedDelay) * 60)
            let minutesUntil   = Int(predictedTime.timeIntervalSince(now) / 60)

            if elapsed < Double(expectedDelay + 30) * 60 {  // within the window
                let urgency = minutesUntil <= 0 ? 0.85 :
                              minutesUntil <= 5 ? 0.7  : 0.4
                let message: String
                if minutesUntil <= 0 {
                    message = "It's been \(Int(elapsed / 60)) minutes since \(dogName)'s last meal — toilet time is due."
                } else {
                    message = "Feeding was \(Int(elapsed / 60)) min ago. Toilet break in about \(minutesUntil) minutes."
                }
                return ToiletPrediction(
                    predictedTime: predictedTime,
                    minutesUntil: minutesUntil,
                    urgency: urgency,
                    triggerReason: .afterFeeding(minutesAgo: Int(elapsed / 60)),
                    message: message
                )
            }
        }

        // Time-based interval
        let lastEvent  = [lastToiletDate, lastFeedingDate].compactMap { $0 }.max() ?? .distantPast
        let elapsed    = now.timeIntervalSince(lastEvent)
        let interval   = Double(phase.toiletIntervalMinutes) * 60.0
        let remaining  = interval - elapsed

        if remaining < interval * 0.3 || remaining < 0 {    // approaching or past interval
            let predictedTime = lastEvent.addingTimeInterval(interval)
            let minutesUntil  = Int(predictedTime.timeIntervalSince(now) / 60)
            let urgency       = remaining <= 0 ? 0.8 : 0.5

            return ToiletPrediction(
                predictedTime: predictedTime,
                minutesUntil: minutesUntil,
                urgency: urgency,
                triggerReason: .intervalElapsed(intervalMinutes: phase.toiletIntervalMinutes),
                message: minutesUntil <= 0
                    ? "Toilet timing is likely due — take \(dogName) outside."
                    : "Toilet break expected in about \(minutesUntil) minutes."
            )
        }

        return nil   // no prediction needed right now
    }

    // MARK: - Urgency from elapsed time (0.0–1.0)

    static func urgencyLevel(
        lastToiletDate: Date?,
        phase: AgePhase,
        pattern: AdaptiveDogPattern
    ) -> Double {
        guard let last = lastToiletDate else { return 0.3 }
        let elapsed   = Date().timeIntervalSince(last) / 60  // minutes
        let threshold = Double(pattern.resolvedToiletAfterSleep(phaseDefault: phase.toiletIntervalMinutes))
        return min(elapsed / threshold, 1.0)
    }
}
