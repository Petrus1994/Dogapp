import Foundation

final class ActivityTrackingService {
    static let shared = ActivityTrackingService()
    private let legacyKey = "daily_activities_v1"
    private var dogId: String?
    private init() {}

    private var key: String {
        guard let dogId else { return legacyKey }
        return "daily_activities_v1_\(dogId)"
    }

    func configure(dogId: String) {
        let isNew = self.dogId != dogId
        self.dogId = dogId
        if isNew { migrateLegacyIfNeeded(dogId: dogId) }
    }

    private func migrateLegacyIfNeeded(dogId: String) {
        let perDogKey = "daily_activities_v1_\(dogId)"
        guard UserDefaults.standard.data(forKey: perDogKey) == nil,
              let legacyData = UserDefaults.standard.data(forKey: legacyKey) else { return }
        UserDefaults.standard.set(legacyData, forKey: perDogKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

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
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        all = all.filter { $0.date >= cutoff }
        saveAll(all)
    }

    func activeDayStrings() -> Set<String> {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return Set(loadAll().filter { $0.completed }.map { fmt.string(from: $0.date) })
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
