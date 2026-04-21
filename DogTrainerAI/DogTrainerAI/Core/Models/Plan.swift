import Foundation

struct Plan: Codable, Identifiable {
    var id: String
    var title: String
    var type: PlanType
    var goal: String
    var weeklyFocus: String
    var tasks: [TrainingTask]
    var tips: [String]
    var startDate: Date

    init(
        id: String, title: String, type: PlanType, goal: String,
        weeklyFocus: String, tasks: [TrainingTask], tips: [String],
        startDate: Date = Date()
    ) {
        self.id = id; self.title = title; self.type = type; self.goal = goal
        self.weeklyFocus = weeklyFocus; self.tasks = tasks; self.tips = tips
        self.startDate = startDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self,         forKey: .id)
        title       = try c.decode(String.self,         forKey: .title)
        type        = try c.decode(PlanType.self,        forKey: .type)
        goal        = try c.decode(String.self,         forKey: .goal)
        weeklyFocus = try c.decode(String.self,         forKey: .weeklyFocus)
        tasks       = try c.decode([TrainingTask].self, forKey: .tasks)
        tips        = try c.decode([String].self,       forKey: .tips)
        startDate   = (try? c.decode(Date.self, forKey: .startDate)) ?? Date()
    }

    enum PlanType: String, Codable {
        case puppyPlan               = "puppy_plan"
        case adultDogCorrectionPlan  = "adult_dog_correction_plan"
        case preDogPreparationPlan   = "pre_dog_preparation_plan"
        case breedPreparationPlan    = "breed_preparation_plan"

        var displayName: String {
            switch self {
            case .puppyPlan:               return "Puppy Training Plan"
            case .adultDogCorrectionPlan:  return "Correction Plan"
            case .preDogPreparationPlan:   return "Pre-Dog Preparation"
            case .breedPreparationPlan:    return "Breed Preparation"
            }
        }
    }

    var todaysTasks: [TrainingTask] {
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        let currentDay = max(1, daysSinceStart + 1)
        return tasks.filter {
            $0.scheduledDay <= currentDay && $0.status != .completed
        }
    }

    var completedTasks: [TrainingTask] {
        tasks.filter { $0.status == .completed }
    }

    var progressFraction: Double {
        guard !tasks.isEmpty else { return 0 }
        let score = tasks.reduce(0.0) { sum, task in
            switch task.status {
            case .completed: return sum + 1.0
            case .partial:   return sum + 0.5
            default:         return sum
            }
        }
        return score / Double(tasks.count)
    }
}
