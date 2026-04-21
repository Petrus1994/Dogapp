import Foundation

final class ActivityTrackingService {
    static let shared = ActivityTrackingService()
    private let key = "daily_activities_v1"
    private init() {}

    func saveAll(_ activities: [DailyActivity]) {
        if let data = try? JSONEncoder().encode(activities) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadAll() -> [DailyActivity] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let activities = try? JSONDecoder().decode([DailyActivity].self, from: data)
        else { return [] }
        return activities
    }

    func todayActivities() -> [DailyActivity] {
        loadAll().filter { Calendar.current.isDateInToday($0.date) }
    }

    func add(_ activity: DailyActivity) {
        var all = loadAll()
        all.append(activity)
        // Keep last 90 days only
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        all = all.filter { $0.date >= cutoff }
        saveAll(all)
    }

    // Returns day strings (yyyy-MM-dd) where any completed activity was logged
    func activeDayStrings() -> Set<String> {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return Set(loadAll().filter { $0.completed }.map { fmt.string(from: $0.date) })
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
