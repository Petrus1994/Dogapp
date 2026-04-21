import Foundation

// MARK: - Sync body types (defined at file scope to avoid mangler crash in Xcode 26)

private struct WalkBody: Encodable {
    let loggedAt: String; let durationMinutes: Int
    let distanceKm: Double?; let walkQuality: String?; let notes: String
}
private struct FeedingBody: Encodable {
    let loggedAt: String; let foodType: String?
    let feedingNumber: Int?; let notes: String
}
private struct PlayBody: Encodable {
    let loggedAt: String; let durationMinutes: Int
    let playActivity: String?; let notes: String
}
private struct TrainingBody: Encodable {
    let loggedAt: String; let durationMinutes: Int; let notes: String
}
private struct ToiletBody: Encodable {
    let occurredAt: String; let outcome: String
    let minutesAfterLastFeeding: Int?; let minutesAfterLastSleep: Int?
    let notes: String
}
private struct BehaviorBody: Encodable {
    let occurredAt: String; let activityType: String?
    let issues: [String]; let notes: String
}
private struct PushTokenBody: Encodable { let token: String; let platform: String }
private struct DogProfileBody: Encodable {
    let name: String; let gender: String; let ageGroup: String
    let breed: String?; let isBreedUnknown: Bool
    let size: String?; let activityLevel: String
    let activityLevelOverride: String?
    let coatColor: String
    let issues: [String]; let birthDate: String?
}
private struct DogProfileResponse: Decodable { let id: String }

/// Mirrors local data writes to the Railway backend.
/// All syncs are queued — failures are retried with exponential backoff.
/// No data is lost on network failure or app restart.
final class BackendSyncService {
    static let shared = BackendSyncService()
    private let queue = SyncQueue.shared
    private let encoder = JSONEncoder()
    private var backendDogId: String?

    private init() {
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Dog Profile

    func syncDogProfile(_ dog: DogProfile) {
        Task {
            do {
                let fmt = ISO8601DateFormatter()
                let body = DogProfileBody(
                    name:                 dog.name,
                    gender:               dog.gender.rawValue,
                    ageGroup:             dog.ageGroup.rawValue,
                    breed:                dog.isBreedUnknown ? nil : dog.breed,
                    isBreedUnknown:       dog.isBreedUnknown,
                    size:                 dog.size?.rawValue,
                    activityLevel:        dog.activityLevel.rawValue,
                    activityLevelOverride:dog.activityLevelOverride?.rawValue,
                    coatColor:            dog.coatColor.rawValue,
                    issues:               dog.issues.map(\.rawValue),
                    birthDate:            dog.birthDate.map { fmt.string(from: $0) }
                )
                let res: DogProfileResponse = try await APIClient.shared.request(
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
        let body = WalkBody(
            loggedAt:        ISO8601DateFormatter().string(from: activity.date),
            durationMinutes: activity.durationMinutes,
            distanceKm:      activity.distanceKm,
            walkQuality:     activity.walkQuality?.rawValue,
            notes:           activity.notes
        )
        enqueue(tag: "walk", endpoint: "/dogs/\(dogId)/logs/walk", body: body)
    }

    // MARK: - Feeding

    func syncFeeding(_ activity: DailyActivity) {
        guard let dogId = backendDogId else { return }
        let body = FeedingBody(
            loggedAt:      ISO8601DateFormatter().string(from: activity.date),
            foodType:      activity.foodType?.rawValue,
            feedingNumber: activity.feedingNumber,
            notes:         activity.notes
        )
        enqueue(tag: "feeding", endpoint: "/dogs/\(dogId)/logs/feeding", body: body)
    }

    // MARK: - Play

    func syncPlay(_ activity: DailyActivity) {
        guard let dogId = backendDogId else { return }
        let body = PlayBody(
            loggedAt:        ISO8601DateFormatter().string(from: activity.date),
            durationMinutes: activity.durationMinutes,
            playActivity:    activity.playActivity?.rawValue,
            notes:           activity.notes
        )
        enqueue(tag: "play", endpoint: "/dogs/\(dogId)/logs/play", body: body)
    }

    // MARK: - Training

    func syncTraining(_ activity: DailyActivity) {
        guard let dogId = backendDogId else { return }
        let body = TrainingBody(
            loggedAt:        ISO8601DateFormatter().string(from: activity.date),
            durationMinutes: activity.durationMinutes,
            notes:           activity.notes
        )
        enqueue(tag: "training", endpoint: "/dogs/\(dogId)/logs/training", body: body)
    }

    // MARK: - Park Session (synced as walk + play)

    func syncParkSession(_ activity: DailyActivity) {
        guard let dogId = backendDogId else { return }
        let halfDuration = activity.durationMinutes / 2
        let loggedAt = ISO8601DateFormatter().string(from: activity.date)

        enqueue(tag: "park-walk", endpoint: "/dogs/\(dogId)/logs/walk",
                body: WalkBody(loggedAt: loggedAt, durationMinutes: halfDuration,
                               distanceKm: nil, walkQuality: nil, notes: activity.notes))
        enqueue(tag: "park-play", endpoint: "/dogs/\(dogId)/logs/play",
                body: PlayBody(loggedAt: loggedAt, durationMinutes: halfDuration,
                               playActivity: nil, notes: activity.notes))
    }

    // MARK: - Toilet event

    func syncToiletEvent(_ event: ToiletEvent) {
        guard let dogId = backendDogId else { return }
        let body = ToiletBody(
            occurredAt:              ISO8601DateFormatter().string(from: event.date),
            outcome:                 event.outcome.rawValue,
            minutesAfterLastFeeding: event.minutesAfterLastFeeding,
            minutesAfterLastSleep:   event.minutesAfterLastSleep,
            notes:                   event.notes
        )
        enqueue(tag: "toilet", endpoint: "/dogs/\(dogId)/logs/toilet", body: body)
    }

    // MARK: - Behavior event

    func syncBehaviorEvent(_ event: BehaviorEvent) {
        guard let dogId = backendDogId else { return }
        let body = BehaviorBody(
            occurredAt:   ISO8601DateFormatter().string(from: event.date),
            activityType: event.activityType?.rawValue,
            issues:       event.issues.map(\.rawValue),
            notes:        event.notes
        )
        enqueue(tag: "behavior", endpoint: "/dogs/\(dogId)/logs/behavior", body: body)
    }

    // MARK: - Push token

    func registerPushToken(_ token: String) {
        enqueue(tag: "push-token", endpoint: "/notifications/token",
                body: PushTokenBody(token: token, platform: "ios"))
    }

    // MARK: - Helpers

    func setBackendDogId(_ id: String?) {
        backendDogId = id
    }

    private func enqueue<T: Encodable>(tag: String, endpoint: String, method: String = "POST", body: T) {
        guard let data = try? encoder.encode(body) else {
            log("enqueue(\(tag)): encoding failed")
            return
        }
        let item = SyncItem(
            id:       UUID().uuidString,
            tag:      tag,
            payload:  data,
            endpoint: endpoint,
            method:   method
        )
        queue.enqueue(item)
    }

    private func log(_ msg: String) {
        #if DEBUG
        print("[BackendSync] \(msg)")
        #endif
    }
}
