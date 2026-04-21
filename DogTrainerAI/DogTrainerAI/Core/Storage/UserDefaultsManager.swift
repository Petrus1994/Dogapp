import Foundation

final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    private let defaults = UserDefaults.standard
    private init() {}

    private enum Keys {
        static let onboardingCompleted = "onboarding_completed"
        static let dogProfile          = "dog_profile"
        static let currentPlan         = "current_plan"
        static let currentUser         = "current_user"
        static let scenarioType        = "scenario_type"
        static let userProgress        = "user_progress_v1"
        static let challenges          = "challenges_v1"
        static let dailyRoutine        = "daily_routine_v1"
        static let adaptivePattern     = "adaptive_pattern_v1"
        static let lastKnownPhaseId    = "last_known_phase_id"
        static let behaviorProgress    = "behavior_progress_v1"
        static let backendDogId        = "backend_dog_id"
    }

    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Keys.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Keys.onboardingCompleted) }
    }

    func saveDogProfile(_ profile: DogProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Keys.dogProfile)
        }
    }

    func loadDogProfile() -> DogProfile? {
        guard let data = defaults.data(forKey: Keys.dogProfile) else { return nil }
        return try? JSONDecoder().decode(DogProfile.self, from: data)
    }

    func savePlan(_ plan: Plan) {
        if let data = try? JSONEncoder().encode(plan) {
            defaults.set(data, forKey: Keys.currentPlan)
        }
    }

    func loadPlan() -> Plan? {
        guard let data = defaults.data(forKey: Keys.currentPlan) else { return nil }
        return try? JSONDecoder().decode(Plan.self, from: data)
    }

    func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: Keys.currentUser)
        }
    }

    func loadUser() -> User? {
        guard let data = defaults.data(forKey: Keys.currentUser) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    func saveUserProgress(_ progress: UserProgress) {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: Keys.userProgress)
        }
    }

    func loadUserProgress() -> UserProgress? {
        guard let data = defaults.data(forKey: Keys.userProgress) else { return nil }
        return try? JSONDecoder().decode(UserProgress.self, from: data)
    }

    func saveChallenges(_ challenges: [Challenge]) {
        if let data = try? JSONEncoder().encode(challenges) {
            defaults.set(data, forKey: Keys.challenges)
        }
    }

    func loadChallenges() -> [Challenge]? {
        guard let data = defaults.data(forKey: Keys.challenges) else { return nil }
        return try? JSONDecoder().decode([Challenge].self, from: data)
    }

    func saveDailyRoutine(_ routine: DailyRoutine) {
        if let data = try? JSONEncoder().encode(routine) {
            defaults.set(data, forKey: Keys.dailyRoutine)
        }
    }

    func loadDailyRoutine() -> DailyRoutine? {
        guard let data = defaults.data(forKey: Keys.dailyRoutine) else { return nil }
        return try? JSONDecoder().decode(DailyRoutine.self, from: data)
    }

    func saveAdaptivePattern(_ pattern: AdaptiveDogPattern) {
        if let data = try? JSONEncoder().encode(pattern) {
            defaults.set(data, forKey: Keys.adaptivePattern)
        }
    }

    func loadAdaptivePattern() -> AdaptiveDogPattern? {
        guard let data = defaults.data(forKey: Keys.adaptivePattern) else { return nil }
        return try? JSONDecoder().decode(AdaptiveDogPattern.self, from: data)
    }

    func saveLastKnownPhaseId(_ id: String) {
        defaults.set(id, forKey: Keys.lastKnownPhaseId)
    }

    func loadLastKnownPhaseId() -> String? {
        defaults.string(forKey: Keys.lastKnownPhaseId)
    }

    func saveBehaviorProgress(_ progress: BehaviorProgress) {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: Keys.behaviorProgress)
        }
    }

    func loadBehaviorProgress() -> BehaviorProgress? {
        guard let data = defaults.data(forKey: Keys.behaviorProgress) else { return nil }
        return try? JSONDecoder().decode(BehaviorProgress.self, from: data)
    }

    func saveBackendDogId(_ id: String) {
        defaults.set(id, forKey: Keys.backendDogId)
    }

    func loadBackendDogId() -> String? {
        defaults.string(forKey: Keys.backendDogId)
    }

    func clearAll() {
        defaults.removeObject(forKey: Keys.onboardingCompleted)
        defaults.removeObject(forKey: Keys.dogProfile)
        defaults.removeObject(forKey: Keys.currentPlan)
        defaults.removeObject(forKey: Keys.currentUser)
        defaults.removeObject(forKey: Keys.userProgress)
        defaults.removeObject(forKey: Keys.challenges)
        defaults.removeObject(forKey: Keys.dailyRoutine)
        defaults.removeObject(forKey: Keys.adaptivePattern)
        defaults.removeObject(forKey: Keys.lastKnownPhaseId)
        defaults.removeObject(forKey: Keys.behaviorProgress)
        defaults.removeObject(forKey: Keys.backendDogId)
    }
}
