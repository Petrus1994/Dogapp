import Foundation

final class BehaviorTrackingService {
    static let shared = BehaviorTrackingService()
    private let legacyKey = "behavior_events_v1"
    private var dogId: String?
    private init() {}

    private var key: String {
        guard let dogId else { return legacyKey }
        return "behavior_events_v1_\(dogId)"
    }

    func configure(dogId: String) {
        let isNew = self.dogId != dogId
        self.dogId = dogId
        if isNew { migrateLegacyIfNeeded(dogId: dogId) }
    }

    private func migrateLegacyIfNeeded(dogId: String) {
        let perDogKey = "behavior_events_v1_\(dogId)"
        guard UserDefaults.standard.data(forKey: perDogKey) == nil,
              let legacyData = UserDefaults.standard.data(forKey: legacyKey) else { return }
        UserDefaults.standard.set(legacyData, forKey: perDogKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    func saveAll(_ events: [BehaviorEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadAll() -> [BehaviorEvent] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let events = try? JSONDecoder().decode([BehaviorEvent].self, from: data)
        else { return [] }
        return events
    }

    func add(_ event: BehaviorEvent) {
        var all = loadAll()
        all.append(event)
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        all = all.filter { $0.date >= cutoff }
        saveAll(all)
    }

    func frequentIssues(lastDays: Int = 14) -> [(BehaviorEvent.BehaviorIssue, Int)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lastDays, to: Date()) ?? Date()
        let events = loadAll().filter { $0.date >= cutoff }
        var counts: [BehaviorEvent.BehaviorIssue: Int] = [:]
        for event in events {
            for issue in event.issues where issue != .noIssues {
                counts[issue, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }

    func daysWithIssues() -> Set<String> {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return Set(loadAll().filter { $0.hasRealIssues }.map { fmt.string(from: $0.date) })
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
