import Foundation

final class BehaviorTrackingService {
    static let shared = BehaviorTrackingService()
    private let key = "behavior_events_v1"
    private init() {}

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

    // Returns the most frequent issues over the last N days, sorted by count descending
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

    // Days (as date-only strings) where real issues were reported
    func daysWithIssues() -> Set<String> {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return Set(loadAll().filter { $0.hasRealIssues }.map { fmt.string(from: $0.date) })
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
