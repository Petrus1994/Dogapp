import Foundation

/// Persistent memory about the dog's onboarding context and AI interaction history.
/// Used to personalize AI responses across sessions.
struct DogMemory: Codable {
    var initialProblem: String?
    var firstAIResponse: String?
    var onboardingDate: Date?
    var recentContextSummaries: [String]

    init(
        initialProblem: String? = nil,
        firstAIResponse: String? = nil,
        onboardingDate: Date? = nil,
        recentContextSummaries: [String] = []
    ) {
        self.initialProblem = initialProblem
        self.firstAIResponse = firstAIResponse
        self.onboardingDate = onboardingDate
        self.recentContextSummaries = recentContextSummaries
    }
}

// MARK: - Persistence

extension DogMemory {
    private static let legacyKey = "dog_memory_v1"
    private static var activeDogId: String?

    static func configure(dogId: String) {
        let isNew = activeDogId != dogId
        activeDogId = dogId
        if isNew { migrateLegacyIfNeeded(dogId: dogId) }
    }

    private static var key: String {
        guard let id = activeDogId else { return legacyKey }
        return "dog_memory_v1_\(id)"
    }

    private static func migrateLegacyIfNeeded(dogId: String) {
        let perDogKey = "dog_memory_v1_\(dogId)"
        guard UserDefaults.standard.data(forKey: perDogKey) == nil,
              let legacyData = UserDefaults.standard.data(forKey: legacyKey) else { return }
        UserDefaults.standard.set(legacyData, forKey: perDogKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    static func load() -> DogMemory {
        guard let data = UserDefaults.standard.data(forKey: key),
              let memory = try? JSONDecoder().decode(DogMemory.self, from: data) else {
            return DogMemory()
        }
        return memory
    }

    static func save(initialProblem: String?, firstAIResponse: String?) {
        var memory = load()
        if let p = initialProblem { memory.initialProblem = p }
        if let r = firstAIResponse { memory.firstAIResponse = r }
        if memory.onboardingDate == nil { memory.onboardingDate = Date() }
        persist(memory)
    }

    static func appendContextSummary(_ summary: String) {
        var memory = load()
        memory.recentContextSummaries.append(summary)
        if memory.recentContextSummaries.count > 10 {
            memory.recentContextSummaries = Array(memory.recentContextSummaries.suffix(10))
        }
        persist(memory)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func persist(_ memory: DogMemory) {
        if let data = try? JSONEncoder().encode(memory) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Context block for AI prompts

    var contextBlock: String? {
        guard initialProblem != nil || firstAIResponse != nil else { return nil }
        var block = "OWNER'S INITIAL CHALLENGE\n"
        if let p = initialProblem { block += "Reported problem: \(p)\n" }
        if let r = firstAIResponse { block += "Initial AI diagnosis: \(r)\n" }
        if let d = onboardingDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            block += "Training started: \(formatter.string(from: d))\n"
        }
        if !recentContextSummaries.isEmpty {
            block += "\nRECENT CONTEXT\n"
            for summary in recentContextSummaries.suffix(3) {
                block += "- \(summary)\n"
            }
        }
        return block
    }
}
