import Foundation

/// Mirrors local data writes to the Railway backend.
/// All methods are fire-and-forget — failures are logged but never surface to the UI.
/// The app keeps working from local state if the backend is unreachable.
final class BackendSyncService {
    static let shared = BackendSyncService()
    private let client = APIClient.shared
    private var backendDogId: String?

    private init() {}

    // MARK: - Dog Profile

    func syncDogProfile(_ dog: DogProfile) {
        Task {
            do {
                struct Body: Encodable {
                    let name: String; let gender: String; let ageGroup: String
                    let breed: String?; let isBreedUnknown: Bool
                    let size: String?; let activityLevel: String; let issues: [String]
                    let birthDate: String?
                }
                let fmt = ISO8601DateFormatter()
                let body = Body(
                    name:           dog.name,
                    gender:         dog.gender.rawValue,
                    ageGroup:       dog.ageGroup.rawValue,
                    breed:          dog.isBreedUnknown ? nil : dog.breed,
                    isBreedUnknown: dog.isBreedUnknown,
                    size:           dog.size?.rawValue,
                    activityLevel:  dog.activityLevel.rawValue,
                    issues:         dog.issues.map(\.rawValue),
                    birthDate:      dog.birthDate.map { fmt.string(from: $0) }
                )
                struct Response: Decodable { let id: String }
                let res: Response = try await client.request(
                    APIEndpoint(path: "/dogs", method: "POST", body: body)
                )
                backendDogId = res.id
                UserDefaultsManager.shared.saveBackendDogId(res.id)
            } catch {
                log("syncDogProfile failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Walk

    func syncWalk(_ activity: DailyActivity) {
        guard let dogId = backendDogId else { return }
        Task {
            do {
                struct Body: Encodable {
                    let loggedAt: String; let durationMinutes: Int
                    let distanceKm: Double?; let walkQuality: String?; let notes: String
                }
                let body = Body(
                    loggedAt:        ISO8601DateFormatter().string(from: activity.date),
                    durationMinutes: activity.durationMinutes,
                    distanceKm:      activity.distanceKm,
                    walkQuality:     activity.walkQuality?.rawValue,
                    notes:           activity.notes
                )
                try await client.send(
                    APIEndpoint(path: "/dogs/\(dogId)/logs/walk", method: "POST", body: body)
                )
            } catch { log("syncWalk failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Feeding

    func syncFeeding(_ activity: DailyActivity) {
        guard let dogId = backendDogId else { return }
        Task {
            do {
                struct Body: Encodable {
                    let loggedAt: String; let foodType: String?
                    let feedingNumber: Int?; let notes: String
                }
                let body = Body(
                    loggedAt:      ISO8601DateFormatter().string(from: activity.date),
                    foodType:      activity.foodType?.rawValue,
                    feedingNumber: activity.feedingNumber,
                    notes:         activity.notes
                )
                try await client.send(
                    APIEndpoint(path: "/dogs/\(dogId)/logs/feeding", method: "POST", body: body)
                )
            } catch { log("syncFeeding failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Play

    func syncPlay(_ activity: DailyActivity) {
        guard let dogId = backendDogId else { return }
        Task {
            do {
                struct Body: Encodable {
                    let loggedAt: String; let durationMinutes: Int
                    let playActivity: String?; let notes: String
                }
                let body = Body(
                    loggedAt:        ISO8601DateFormatter().string(from: activity.date),
                    durationMinutes: activity.durationMinutes,
                    playActivity:    activity.playActivity?.rawValue,
                    notes:           activity.notes
                )
                try await client.send(
                    APIEndpoint(path: "/dogs/\(dogId)/logs/play", method: "POST", body: body)
                )
            } catch { log("syncPlay failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Training

    func syncTraining(_ activity: DailyActivity) {
        guard let dogId = backendDogId else { return }
        Task {
            do {
                struct Body: Encodable {
                    let loggedAt: String; let durationMinutes: Int; let notes: String
                }
                let body = Body(
                    loggedAt:        ISO8601DateFormatter().string(from: activity.date),
                    durationMinutes: activity.durationMinutes,
                    notes:           activity.notes
                )
                try await client.send(
                    APIEndpoint(path: "/dogs/\(dogId)/logs/training", method: "POST", body: body)
                )
            } catch { log("syncTraining failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Toilet event

    func syncToiletEvent(_ event: ToiletEvent) {
        guard let dogId = backendDogId else { return }
        Task {
            do {
                struct Body: Encodable {
                    let occurredAt: String; let outcome: String
                    let minutesAfterLastFeeding: Int?; let minutesAfterLastSleep: Int?
                    let notes: String
                }
                let body = Body(
                    occurredAt:              ISO8601DateFormatter().string(from: event.date),
                    outcome:                 event.outcome.rawValue,
                    minutesAfterLastFeeding: event.minutesAfterLastFeeding,
                    minutesAfterLastSleep:   event.minutesAfterLastSleep,
                    notes:                   event.notes
                )
                try await client.send(
                    APIEndpoint(path: "/dogs/\(dogId)/logs/toilet", method: "POST", body: body)
                )
            } catch { log("syncToiletEvent failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Behavior event

    func syncBehaviorEvent(_ event: BehaviorEvent) {
        guard let dogId = backendDogId else { return }
        Task {
            do {
                struct Body: Encodable {
                    let occurredAt: String; let activityType: String?
                    let issues: [String]; let notes: String
                }
                let body = Body(
                    occurredAt:   ISO8601DateFormatter().string(from: event.date),
                    activityType: event.activityType?.rawValue,
                    issues:       event.issues.map(\.rawValue),
                    notes:        event.notes
                )
                try await client.send(
                    APIEndpoint(path: "/dogs/\(dogId)/logs/behavior", method: "POST", body: body)
                )
            } catch { log("syncBehaviorEvent failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Notification token

    func registerPushToken(_ token: String) {
        Task {
            do {
                struct Body: Encodable { let token: String; let platform: String }
                try await client.send(
                    APIEndpoint(
                        path:   "/notifications/token",
                        method: "POST",
                        body:   Body(token: token, platform: "ios")
                    )
                )
            } catch { log("registerPushToken failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Helpers

    /// Called by AppState after dog profile is loaded — resolves the backend dog ID.
    func setBackendDogId(_ id: String?) {
        backendDogId = id
    }

    private func log(_ msg: String) {
        #if DEBUG
        print("[BackendSync] \(msg)")
        #endif
    }
}
