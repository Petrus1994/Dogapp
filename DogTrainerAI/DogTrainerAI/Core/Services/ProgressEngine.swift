import Foundation

struct ProgressEngine {

    // MARK: - Main entry: process all of today's data and return updated progress

    static func process(
        current: BehaviorProgress,
        activities: [DailyActivity],
        events: [BehaviorEvent],
        feedbacks: [TaskFeedback],
        norms: ActivityNorms?
    ) -> BehaviorProgress {
        let signals = SignalMapper.dailySignals(
            activities: activities,
            events: events,
            feedbacks: feedbacks,
            norms: norms
        )

        var updated = current

        for signal in signals {
            guard var dimensionScore = updated.scores.first(where: { $0.dimension == signal.dimension }),
                  let idx = updated.scores.firstIndex(where: { $0.dimension == signal.dimension })
            else { continue }

            let prevScore = previousDayScore(history: dimensionScore.history) ?? dimensionScore.score
            let newScore  = applySmoothing(previous: prevScore, dailySignal: signal.rawSignal)

            let confidence = calculateConfidence(
                activities: activities,
                events: events,
                feedbacks: feedbacks,
                dimension: signal.dimension
            )

            let today     = Calendar.current.startOfDay(for: Date())
            let snapshot  = DimensionSnapshot(
                date: today,
                score: newScore,
                dailySignal: signal.rawSignal,
                confidence: confidence,
                activityCount: signal.sources.count
            )

            // Replace today's entry or append
            if let lastIdx = dimensionScore.history.indices.last,
               Calendar.current.isDate(dimensionScore.history[lastIdx].date, inSameDayAs: Date()) {
                dimensionScore.history[lastIdx] = snapshot
            } else {
                dimensionScore.history.append(snapshot)
            }
            // Keep max 30 days
            if dimensionScore.history.count > 30 {
                dimensionScore.history.removeFirst(dimensionScore.history.count - 30)
            }

            dimensionScore.score      = newScore
            dimensionScore.trend      = calculateTrend(history: dimensionScore.history)
            dimensionScore.confidence = confidence
            updated.scores[idx]       = dimensionScore
        }

        updated.lastProcessedDate = Date()
        return updated
    }

    // MARK: - Smoothing formula (applied against previous day's score)

    // new_score = old * 0.85 + signal * 0.15, capped ±4/±6 per day
    static func applySmoothing(previous: Double, dailySignal: Double) -> Double {
        let smoothed = previous * 0.85 + dailySignal * 0.15
        let maxUp    = previous + 4
        let maxDown  = previous - 6
        return min(maxUp, max(maxDown, smoothed))
    }

    // MARK: - Trend: compare last 3 days vs previous 7 days

    static func calculateTrend(history: [DimensionSnapshot]) -> BehaviorDimensionScore.Trend {
        guard history.count >= 4 else { return .stable }
        let last3  = history.suffix(3).map  { $0.score }
        let prev7  = history.dropLast(3).suffix(7).map { $0.score }

        let avg3 = last3.reduce(0, +)  / Double(last3.count)
        let avg7 = prev7.reduce(0, +) / Double(max(1, prev7.count))

        if avg3 > avg7 + 2 { return .improving }
        if avg3 < avg7 - 2 { return .needsAttention }
        return .stable
    }

    // MARK: - Confidence based on data density

    static func calculateConfidence(
        activities: [DailyActivity],
        events: [BehaviorEvent],
        feedbacks: [TaskFeedback],
        dimension: BehaviorDimension
    ) -> Double {
        var count = 0
        var hasNotes = false

        switch dimension {
        case .foodBehavior:
            let feedings = activities.filter { $0.type == .feeding }
            count += feedings.count
            hasNotes = feedings.contains { !$0.notes.isEmpty }
            count += events.filter { $0.issues.contains(.beggingForFood) || $0.issues.contains(.pickingFoodFromGround) }.count

        case .activityExcitement:
            count += activities.filter { $0.type == .walking || $0.type == .playing || $0.type == .training }.count
            hasNotes = activities.filter { $0.type == .walking }.contains { !$0.notes.isEmpty }
            count += events.filter { $0.issues.contains(.overexcitement) || $0.issues.contains(.leashPulling) }.count

        case .ownerContact:
            count += activities.filter { $0.type == .training }.count
            count += feedbacks.count
            hasNotes = feedbacks.contains { $0.freeTextComment != nil }

        case .socialization:
            count += activities.filter { $0.type == .walking }.count
            count += events.filter {
                $0.issues.contains(.reactingToDogs) || $0.issues.contains(.reactingToPeople) ||
                $0.issues.contains(.fearReactions)  || $0.issues.contains(.barking)
            }.count
            hasNotes = events.contains { !$0.notes.isEmpty }
        }

        var confidence: Double
        switch count {
        case 0:    confidence = 0
        case 1:    confidence = 25
        case 2:    confidence = 45
        case 3:    confidence = 65
        case 4:    confidence = 78
        default:   confidence = 90
        }
        if hasNotes { confidence = min(100, confidence + 10) }
        return confidence
    }

    // MARK: - Helper: previous day's score from history

    private static func previousDayScore(history: [DimensionSnapshot]) -> Double? {
        let today = Calendar.current.startOfDay(for: Date())
        // Find the most recent snapshot that is NOT today
        return history
            .filter { !Calendar.current.isDate($0.date, inSameDayAs: today) }
            .last?
            .score
    }
}
