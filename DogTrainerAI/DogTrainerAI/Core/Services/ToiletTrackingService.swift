import Foundation

final class ToiletTrackingService {
    static let shared = ToiletTrackingService()
    private let key = "toilet_events_v1"
    private init() {}

    func saveAll(_ events: [ToiletEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadAll() -> [ToiletEvent] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let events = try? JSONDecoder().decode([ToiletEvent].self, from: data)
        else { return [] }
        return events
    }

    func todayEvents() -> [ToiletEvent] {
        loadAll().filter { Calendar.current.isDateInToday($0.date) }
    }

    func add(_ event: ToiletEvent) {
        var all = loadAll()
        all.append(event)
        // Keep last 60 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        all = all.filter { $0.date >= cutoff }
        saveAll(all)
    }

    /// The most recent successful toilet event
    func lastSuccess() -> ToiletEvent? {
        loadAll().filter { $0.outcome == .success }.last
    }

    /// Events in the last N days (for adaptive learning)
    func recentEvents(days: Int = 14) -> [ToiletEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return loadAll().filter { $0.date >= cutoff }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
