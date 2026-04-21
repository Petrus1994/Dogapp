import Foundation

// MARK: - Plan generation — input

struct PlanGenerationInput {
    let scenario: User.ScenarioType?
    let dogProfile: DogProfile?
    let selectedBreed: String?

    /// Serialises the input into a human-readable context block for the prompt.
    var contextBlock: String {
        var parts: [String] = []

        if let dog = dogProfile {
            parts.append("""
            DOG PROFILE
            - Name: \(dog.name)
            - Gender: \(dog.gender.displayName)
            - Age group: \(dog.ageGroup.displayName)
            - Breed: \(dog.breed)\(dog.isBreedUnknown ? " (unknown/mixed)" : "")
            - Size: \(dog.size?.displayName ?? "not specified")
            - Activity level: \(dog.activityLevel.displayName)
            - Current issues: \(dog.issues.isEmpty ? "none" : dog.issues.map { $0.displayName }.joined(separator: ", "))
            """)
        }

        if let breed = selectedBreed {
            parts.append("SELECTED BREED (no dog yet): \(breed)")
        }

        if let sc = scenario {
            let label: String
            switch sc {
            case .hasDog:              label = "User has a dog"
            case .noDogChoosingBreed:  label = "User choosing a breed"
            case .noDogBreedSelected:  label = "User has chosen breed, no dog yet"
            case .noDogSkipped:        label = "User skipped breed selection"
            }
            parts.append("SCENARIO: \(label)")
        }

        return parts.joined(separator: "\n\n")
    }
}

// MARK: - Plan generation — structured output

/// The exact JSON shape the model is instructed to return.
struct PlanGenerationOutput: Decodable {
    let title: String
    let planType: String
    let goal: String
    let weeklyFocus: String
    let tasks: [TaskOutput]
    let tips: [String]

    struct TaskOutput: Decodable {
        let title: String
        let description: String
        let category: String
        let difficulty: Int
        let expectedOutcome: String
        let scheduledDay: Int

        enum CodingKeys: String, CodingKey {
            case title, description, category, difficulty
            case expectedOutcome = "expected_outcome"
            case scheduledDay    = "scheduled_day"
        }
    }

    enum CodingKeys: String, CodingKey {
        case title, goal, tasks, tips
        case planType     = "plan_type"
        case weeklyFocus  = "weekly_focus"
    }

    // MARK: JSON Schema (sent to OpenAI structured outputs)
    static var jsonSchema: JSONValue {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array(["title","plan_type","goal","weekly_focus","tasks","tips"].map { .string($0) }),
            "properties": .object([
                "title":        .object(["type": .string("string"), "description": .string("Short plan title")]),
                "plan_type":    .object(["type": .string("string"), "description": .string("One of: puppy_plan | adult_dog_correction_plan | pre_dog_preparation_plan | breed_preparation_plan")]),
                "goal":         .object(["type": .string("string"), "description": .string("Primary training goal in 1-2 sentences")]),
                "weekly_focus": .object(["type": .string("string"), "description": .string("Focus topic for the first week")]),
                "tips": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("3-5 practical tips")
                ]),
                "tasks": .object([
                    "type": .string("array"),
                    "description": .string("5-7 training tasks"),
                    "items": .object([
                        "type": .string("object"),
                        "additionalProperties": .bool(false),
                        "required": .array(["title","description","category","difficulty","expected_outcome","scheduled_day"].map { .string($0) }),
                        "properties": .object([
                            "title":            .object(["type": .string("string")]),
                            "description":      .object(["type": .string("string"), "description": .string("Step-by-step instructions, 2-4 sentences")]),
                            "category":         .object(["type": .string("string"), "description": .string("One of: toilet|routine|leash|socialization|feeding|contact|exercise|breedSelection|preparation")]),
                            "difficulty":       .object(["type": .string("integer"), "description": .string("1 (easy) to 5 (hard)")]),
                            "expected_outcome": .object(["type": .string("string"), "description": .string("What success looks like")]),
                            "scheduled_day":    .object(["type": .string("integer"), "description": .string("Which day of the plan this task is scheduled for (1–7)")])
                        ])
                    ])
                ])
            ])
        ])
    }
}

// MARK: - Converter: AI output → app Plan model

extension PlanGenerationOutput {
    func toPlan() -> Plan {
        let mappedTasks = tasks.enumerated().map { idx, t in
            TrainingTask(
                id:              "ai-task-\(idx + 1)-\(UUID().uuidString.prefix(8))",
                title:            t.title,
                description:      t.description,
                category:         TrainingTask.TaskCategory(rawValue: t.category) ?? .routine,
                difficulty:       max(1, min(5, t.difficulty)),
                expectedOutcome:  t.expectedOutcome,
                status:           .pending,
                scheduledDay:     max(1, min(7, t.scheduledDay))
            )
        }
        return Plan(
            id:          "plan-\(UUID().uuidString.prefix(12))",
            title:        title,
            type:         Plan.PlanType(rawValue: planType) ?? .puppyPlan,
            goal:         goal,
            weeklyFocus:  weeklyFocus,
            tasks:        mappedTasks,
            tips:         tips,
            startDate:    Date()
        )
    }
}
