import Foundation
import CoreMotion
import Combine

/// Tracks steps in real-time using CMPedometer during a walk session.
@MainActor
final class StepTrackingService: ObservableObject {

    static let shared = StepTrackingService()
    private init() {}

    @Published var isTracking: Bool = false
    @Published var liveSteps: Int = 0
    @Published var liveDistanceM: Double = 0  // meters

    private let pedometer = CMPedometer()
    private var sessionStart: Date?

    static var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    var liveDistanceKm: Double { liveDistanceM / 1000.0 }
    var liveStepLabel: String { "\(liveSteps) steps" }
    var liveDistanceLabel: String { String(format: "%.2f km", liveDistanceKm) }

    // MARK: - Session control

    func startSession() {
        guard Self.isAvailable, !isTracking else { return }
        let start = Date()
        sessionStart = start
        isTracking = true
        liveSteps = 0
        liveDistanceM = 0

        pedometer.startUpdates(from: start) { [weak self] data, error in
            guard let data, error == nil else { return }
            Task { @MainActor [weak self] in
                self?.liveSteps    = data.numberOfSteps.intValue
                self?.liveDistanceM = data.distance?.doubleValue ?? 0
            }
        }
    }

    /// Stops tracking and returns final step count and distance. Falls back to estimation.
    func stopSession(estimatedDurationMinutes: Int = 30) -> (steps: Int, distanceKm: Double) {
        pedometer.stopUpdates()
        isTracking = false
        sessionStart = nil

        let steps    = liveSteps
        let distance = liveDistanceKm

        // If pedometer returned nothing (simulator), estimate from duration
        let finalSteps    = steps > 0 ? steps    : estimatedSteps(forMinutes: estimatedDurationMinutes)
        let finalDistance = distance > 0 ? distance : estimatedDistanceKm(forMinutes: estimatedDurationMinutes)

        liveSteps = 0
        liveDistanceM = 0

        return (finalSteps, finalDistance)
    }

    // MARK: - Historical query

    /// Query total steps for a given time range (used for daily summary).
    func querySteps(from start: Date, to end: Date) async -> Int {
        guard Self.isAvailable else { return 0 }
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, error in
                continuation.resume(returning: data?.numberOfSteps.intValue ?? 0)
            }
        }
    }

    // MARK: - Estimation fallbacks

    private func estimatedSteps(forMinutes minutes: Int) -> Int {
        // Average 100 steps/minute at a comfortable walking pace
        return minutes * 100
    }

    private func estimatedDistanceKm(forMinutes minutes: Int) -> Double {
        // ~80m per minute = 4.8 km/h average
        return Double(minutes) * 0.08
    }
}
