import Foundation

/// Recommended daily activity targets for a specific dog profile.
struct ActivityNorms: Codable {

    // Walk
    var walkMinPerDay: Int            // target total walk minutes
    var walkDistanceKmPerDay: Double  // estimated target distance
    var walkSessionsPerDay: Int       // how many separate walks recommended

    // Play
    var playMinPerDay: Int
    var playSessionsPerDay: Int

    // Training
    var trainingMinPerSession: Int    // max per session to avoid overload
    var trainingSessionsPerDay: Int

    // Feeding
    var feedingsPerDay: Int

    // MARK: - Computed helpers

    /// Friendly walk range label e.g. "45–60 min"
    var walkRangeLabel: String {
        let low = max(walkMinPerDay - 15, 10)
        return "\(low)–\(walkMinPerDay) min"
    }

    var playRangeLabel: String { "\(playMinPerDay) min / day" }
    var trainingLabel: String { "\(trainingMinPerSession) min max / session" }
}
