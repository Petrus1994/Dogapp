import Foundation

// MARK: - Breed recommendation — input

extension BreedSelectionProfile {
    var contextBlock: String {
        """
        OWNER PROFILE
        - Lifestyle: \(lifestyle.displayName)
        - Home type: \(homeType.displayName)
        - Dog experience: \(experienceLevel.displayName)
        - Available time per day for dog care: \(availableTime.displayName)
        - Children at home: \(hasChildren ? "yes" : "no")
        - Goal with dog: \(goal.displayName)
        - Preferred dog size: \(sizePreference.displayName)
        - Preferred weight range: \(weightPreference.displayName)
        - Coat type preference: \(coatType.displayName)
        - Grooming tolerance: \(groomingTolerance.displayName)
        - Noise/barking tolerance: \(noiseTolerance.displayName)
        - Energy level expectation: \(energyExpectation.displayName)
        """
    }
}

// MARK: - Breed recommendation — structured output

struct BreedRecommendationOutput: Decodable {
    let breeds: [BreedOutput]

    struct BreedOutput: Decodable {
        let name:        String
        let description: String
        let reason:      String
    }

    static var jsonSchema: JSONValue {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array([.string("breeds")]),
            "properties": .object([
                "breeds": .object([
                    "type": .string("array"),
                    "description": .string("3 to 5 breed recommendations"),
                    "items": .object([
                        "type": .string("object"),
                        "additionalProperties": .bool(false),
                        "required": .array(["name", "description", "reason"].map { .string($0) }),
                        "properties": .object([
                            "name":        .object(["type": .string("string")]),
                            "description": .object([
                                "type": .string("string"),
                                "description": .string("One sentence: breed temperament and energy, no appearance")
                            ]),
                            "reason": .object([
                                "type": .string("string"),
                                "description": .string("2–3 sentences: why this breed fits THIS specific owner — reference at least 2 profile criteria and explain the natural-need fit")
                            ])
                        ])
                    ])
                ])
            ])
        ])
    }

    func toRecommendations() -> [BreedRecommendation] {
        breeds.map { b in
            BreedRecommendation(
                id:               UUID().uuidString,
                name:             b.name,
                breedDescription: b.description,
                reason:           b.reason,
                imageName:        nil
            )
        }
    }
}
