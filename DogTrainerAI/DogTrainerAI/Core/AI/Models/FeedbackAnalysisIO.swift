import Foundation

// MARK: - Feedback analysis — input

struct FeedbackAnalysisInput {
    let task: TrainingTask
    let feedback: TaskFeedback
    let dogProfile: DogProfile?
    let clarificationAnswers: [String: String]

    var contextBlock: String {
        var lines: [String] = []

        lines.append("""
        TASK
        - Title: \(task.title)
        - Category: \(task.category.displayName)
        - Description: \(task.description)
        - Expected outcome: \(task.expectedOutcome)
        - Difficulty: \(task.difficulty)/5
        """)

        lines.append("""
        RESULT: \(feedback.result.rawValue.uppercased())
        """)

        if let dog = dogProfile {
            lines.append("""
            DOG
            - Name: \(dog.name), \(dog.ageGroup.displayName) \(dog.breed)
            - Activity level: \(dog.activityLevel.displayName)
            """)
        }

        var answers: [String] = []
        if let a = clarificationAnswers["1"] { answers.append("Timing/situation: \(a)") }
        if let a = clarificationAnswers["2"] { answers.append("Dog behavior: \(a)") }
        if let a = clarificationAnswers["3"], !a.isEmpty { answers.append("Additional context: \(a)") }
        if !answers.isEmpty {
            lines.append("USER ANSWERS\n" + answers.joined(separator: "\n"))
        }

        return lines.joined(separator: "\n\n")
    }
}

// MARK: - Feedback analysis — structured output

struct FeedbackAnalysisOutput: Decodable {
    let probableCause: String
    let probableMistake: String
    let doNow: [String]
    let avoid: [String]
    let nextAttempt: String

    enum CodingKeys: String, CodingKey {
        case probableCause   = "probable_cause"
        case probableMistake = "probable_mistake"
        case doNow           = "do_now"
        case avoid
        case nextAttempt     = "next_attempt"
    }

    static var jsonSchema: JSONValue {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array(["probable_cause","probable_mistake","do_now","avoid","next_attempt"].map { .string($0) }),
            "properties": .object([
                "probable_cause":   .object(["type": .string("string"), "description": .string("Why the task likely failed, 1-2 sentences")]),
                "probable_mistake": .object(["type": .string("string"), "description": .string("The most likely training error, 1 sentence")]),
                "do_now": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("2-4 actionable steps to take immediately")
                ]),
                "avoid": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("2-3 things to avoid on the next attempt")
                ]),
                "next_attempt": .object(["type": .string("string"), "description": .string("Concrete advice for the next training session, 2-3 sentences")])
            ])
        ])
    }

    func toAIAdjustment(taskId: String) -> AIAdjustment {
        AIAdjustment(
            id:              UUID().uuidString,
            taskId:          taskId,
            probableCause:   probableCause,
            probableMistake: probableMistake,
            doNow:           doNow,
            avoid:           avoid,
            nextAttempt:     nextAttempt
        )
    }
}
