import Foundation

struct TrainingTask: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var description: String
    var category: TaskCategory
    var difficulty: Int
    var expectedOutcome: String
    var status: TaskStatus
    var scheduledDay: Int
    var notes: String

    init(
        id: String, title: String, description: String,
        category: TaskCategory, difficulty: Int,
        expectedOutcome: String, status: TaskStatus,
        scheduledDay: Int = 1, notes: String = ""
    ) {
        self.id = id; self.title = title; self.description = description
        self.category = category; self.difficulty = difficulty
        self.expectedOutcome = expectedOutcome; self.status = status
        self.scheduledDay = scheduledDay; self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self,       forKey: .id)
        title           = try c.decode(String.self,       forKey: .title)
        description     = try c.decode(String.self,       forKey: .description)
        category        = try c.decode(TaskCategory.self, forKey: .category)
        difficulty      = try c.decode(Int.self,          forKey: .difficulty)
        expectedOutcome = try c.decode(String.self,       forKey: .expectedOutcome)
        status          = try c.decode(TaskStatus.self,   forKey: .status)
        scheduledDay    = (try? c.decode(Int.self,    forKey: .scheduledDay)) ?? 1
        notes           = (try? c.decode(String.self, forKey: .notes))        ?? ""
    }

    static func == (lhs: TrainingTask, rhs: TrainingTask) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    enum TaskCategory: String, Codable, CaseIterable {
        case toilet, routine, leash, socialization, feeding
        case contact, exercise, breedSelection, preparation

        var displayName: String {
            switch self {
            case .toilet:          return "Toilet Training"
            case .routine:         return "Daily Routine"
            case .leash:           return "Leash Training"
            case .socialization:   return "Socialization"
            case .feeding:         return "Feeding"
            case .contact:         return "Contact & Touch"
            case .exercise:        return "Exercise"
            case .breedSelection:  return "Breed Selection"
            case .preparation:     return "Preparation"
            }
        }

        var icon: String {
            switch self {
            case .toilet:          return "🚿"
            case .routine:         return "📅"
            case .leash:           return "🦮"
            case .socialization:   return "🐾"
            case .feeding:         return "🍖"
            case .contact:         return "🤝"
            case .exercise:        return "🏃"
            case .breedSelection:  return "🔍"
            case .preparation:     return "📋"
            }
        }

        var color: String {
            switch self {
            case .toilet:          return "teal"
            case .routine:         return "blue"
            case .leash:           return "orange"
            case .socialization:   return "green"
            case .feeding:         return "brown"
            case .contact:         return "purple"
            case .exercise:        return "red"
            case .breedSelection:  return "indigo"
            case .preparation:     return "gray"
            }
        }
    }

    enum TaskStatus: String, Codable {
        case pending, completed, partial, failed
    }
}
