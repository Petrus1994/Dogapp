import Foundation

enum MockData {

    // MARK: - Plans

    static let puppyPlan = Plan(
        id: "plan-puppy-1",
        title: "Puppy Foundation Plan",
        type: .puppyPlan,
        goal: "Build a calm, trusting relationship and establish key habits in the first weeks.",
        weeklyFocus: "Toilet training & basic contact",
        tasks: [
            TrainingTask(
                id: "t1", title: "Morning Potty Routine",
                description: "Take your puppy outside immediately after waking up. Use a consistent cue word like 'outside' and reward within 3 seconds of them going.",
                category: .toilet, difficulty: 1,
                expectedOutcome: "Puppy goes outside and receives immediate reward. Begin building the association.",
                status: .pending
            ),
            TrainingTask(
                id: "t2", title: "Name Recognition",
                description: "Say the dog's name once clearly. The moment they look at you, mark with 'yes!' and give a treat. Repeat 5 times. Do not repeat the name if ignored.",
                category: .contact, difficulty: 1,
                expectedOutcome: "Puppy turns toward you when they hear their name at least 3/5 times.",
                status: .pending
            ),
            TrainingTask(
                id: "t3", title: "Handling & Touch",
                description: "Gently touch paws, ears, and mouth for 1–2 seconds each. Pair each touch with a treat. Keep sessions under 5 minutes.",
                category: .contact, difficulty: 2,
                expectedOutcome: "Puppy tolerates handling without pulling away or showing stress.",
                status: .pending
            ),
            TrainingTask(
                id: "t4", title: "Scheduled Feeding",
                description: "Feed at the same times each day (morning, noon, evening). Remove the bowl after 15 minutes whether finished or not.",
                category: .feeding, difficulty: 1,
                expectedOutcome: "Puppy eats at set times, making digestion and toilet schedule predictable.",
                status: .completed
            ),
            TrainingTask(
                id: "t5", title: "Collar & Leash Introduction",
                description: "Let the puppy sniff the collar before putting it on. Leave it on for 10 minutes, reward calm behavior. Attach leash and let puppy drag it indoors supervised.",
                category: .leash, difficulty: 2,
                expectedOutcome: "Puppy accepts collar without pawing at it. No fear response to leash.",
                status: .pending
            ),
        ],
        tips: [
            "Keep training sessions to 5 minutes maximum at this age.",
            "Always end on a win — ask for something easy before finishing.",
            "Puppies need 16–18 hours of sleep. Overtired puppies can't learn.",
            "Reward with tiny treats (pea-sized). Too much food reduces motivation.",
        ]
    )

    static let adultCorrectionPlan = Plan(
        id: "plan-adult-1",
        title: "Correction & Foundation Plan",
        type: .adultDogCorrectionPlan,
        goal: "Address key behavioral issues through positive redirection and clear communication.",
        weeklyFocus: "Leash manners & impulse control",
        tasks: [
            TrainingTask(
                id: "a1", title: "Leash Stop Technique",
                description: "On your walk, the moment the leash tightens, stop completely. Stand still. Wait for slack in the leash, then resume. Repeat every single time.",
                category: .leash, difficulty: 3,
                expectedOutcome: "Dog begins to self-regulate leash tension. You can walk at least 50 meters without pulling.",
                status: .pending
            ),
            TrainingTask(
                id: "a2", title: "Sit Before Everything",
                description: "Ask for 'sit' before meals, before going through doors, before playtime. This simple rule builds impulse control throughout the day.",
                category: .routine, difficulty: 2,
                expectedOutcome: "Dog automatically sits at door and bowl without being asked within a week.",
                status: .pending
            ),
            TrainingTask(
                id: "a3", title: "Focus & Eye Contact",
                description: "Hold a treat near your face. Say 'look'. When dog makes eye contact, reward immediately. Practice 10 repetitions twice daily.",
                category: .contact, difficulty: 2,
                expectedOutcome: "Dog can hold eye contact for 3 seconds on cue in a calm environment.",
                status: .partial
            ),
        ],
        tips: [
            "Consistency beats intensity. 5 minutes twice daily is better than 30 minutes once a week.",
            "Every family member must use the same commands and rules.",
            "Management (leash, gates, crates) prevents mistakes while training takes effect.",
        ]
    )

    static let preparationPlan = Plan(
        id: "plan-prep-1",
        title: "New Dog Preparation Plan",
        type: .preDogPreparationPlan,
        goal: "Prepare your home, mindset, and schedule before bringing a dog home.",
        weeklyFocus: "Home setup & knowledge building",
        tasks: [
            TrainingTask(
                id: "p1", title: "Set Up a Safe Space",
                description: "Prepare a quiet corner with a crate or bed, water bowl, and a few toys. This will be your dog's retreat — a place they can always go to feel safe.",
                category: .preparation, difficulty: 1,
                expectedOutcome: "Designated safe area ready before dog arrives.",
                status: .pending
            ),
            TrainingTask(
                id: "p2", title: "Puppy-Proof the Home",
                description: "Remove cables, toxic plants, and small objects from floor level. Secure trash cans and close off rooms you don't want the dog in.",
                category: .preparation, difficulty: 2,
                expectedOutcome: "Home is safe for a curious dog or puppy.",
                status: .pending
            ),
            TrainingTask(
                id: "p3", title: "Plan the Daily Schedule",
                description: "Write out your daily routine: when you wake up, work hours, when you'll be home. Map out feeding, walk, and training times that fit realistically.",
                category: .routine, difficulty: 1,
                expectedOutcome: "Realistic 7-day schedule drafted for first week with the dog.",
                status: .pending
            ),
            TrainingTask(
                id: "p4", title: "Research a Local Vet",
                description: "Find a vet nearby and schedule a first check-up for within the first week of getting the dog. Note emergency clinic hours.",
                category: .preparation, difficulty: 1,
                expectedOutcome: "Vet appointment booked. Emergency clinic identified.",
                status: .completed
            ),
        ],
        tips: [
            "The first 72 hours set the tone. Stay calm, let the dog explore at their own pace.",
            "Don't invite everyone over in the first week — it's overwhelming.",
            "Have treats ready from day one. You'll use them constantly early on.",
        ]
    )

    // MARK: - Breed Recommendations

    static let calmBreeds: [BreedRecommendation] = [
        BreedRecommendation(
            id: "b1", name: "Cavalier King Charles Spaniel",
            breedDescription: "Gentle, affectionate, and low-energy. Perfect indoor companion.",
            reason: "Adapts well to apartment living, loves cuddles, and rarely needs vigorous exercise.",
            imageName: nil
        ),
        BreedRecommendation(
            id: "b2", name: "Basset Hound",
            breedDescription: "Laid-back, friendly, and patient.",
            reason: "Content with moderate walks and long naps. Great with families who prefer a relaxed pace.",
            imageName: nil
        ),
        BreedRecommendation(
            id: "b3", name: "Shih Tzu",
            breedDescription: "Calm, sociable, and easy to manage.",
            reason: "Thrives indoors, minimal exercise needs, and highly adaptable to your lifestyle.",
            imageName: nil
        ),
    ]

    static let moderateBreeds: [BreedRecommendation] = [
        BreedRecommendation(
            id: "b4", name: "Labrador Retriever",
            breedDescription: "Friendly, trainable, and versatile family dog.",
            reason: "Responds well to positive training, loves people, and fits most lifestyles with regular exercise.",
            imageName: nil
        ),
        BreedRecommendation(
            id: "b5", name: "Golden Retriever",
            breedDescription: "Patient, gentle, and great with kids.",
            reason: "One of the most trainable breeds. Perfect for first-time owners with moderate activity level.",
            imageName: nil
        ),
        BreedRecommendation(
            id: "b6", name: "Poodle (Standard)",
            breedDescription: "Intelligent, hypoallergenic, and highly adaptable.",
            reason: "Learns commands quickly, great for active households, minimal shedding.",
            imageName: nil
        ),
    ]

    static let activeBreeds: [BreedRecommendation] = [
        BreedRecommendation(
            id: "b7", name: "Border Collie",
            breedDescription: "The world's most intelligent dog. Needs a job to do.",
            reason: "Thrives with active owners who want to do dog sports, long hikes, or advanced training.",
            imageName: nil
        ),
        BreedRecommendation(
            id: "b8", name: "Belgian Malinois",
            breedDescription: "High-drive, athletic, and extremely loyal.",
            reason: "Ideal for experienced owners who are very active and want a serious training partner.",
            imageName: nil
        ),
        BreedRecommendation(
            id: "b9", name: "Siberian Husky",
            breedDescription: "Energetic, adventurous, and sociable.",
            reason: "Loves running and outdoor activities. Best for active families in cooler climates.",
            imageName: nil
        ),
    ]

    static let allBreedNames: [String] = [
        "Affenpinscher", "Afghan Hound", "Airedale Terrier", "Akita", "Alaskan Malamute",
        "Basenji", "Basset Hound", "Beagle", "Belgian Malinois", "Bernese Mountain Dog",
        "Bichon Frise", "Border Collie", "Boxer", "Bulldog", "Bull Terrier",
        "Cavalier King Charles Spaniel", "Chihuahua", "Chow Chow", "Cocker Spaniel",
        "Dachshund", "Dalmatian", "Doberman Pinscher",
        "French Bulldog", "German Shepherd", "Golden Retriever", "Great Dane",
        "Havanese", "Irish Setter",
        "Jack Russell Terrier",
        "Labrador Retriever", "Lhasa Apso",
        "Maltese", "Miniature Schnauzer", "Mixed Breed / Unknown",
        "Pomeranian", "Poodle", "Pug",
        "Rottweiler",
        "Saint Bernard", "Samoyed", "Shiba Inu", "Shih Tzu", "Siberian Husky",
        "Vizsla",
        "Weimaraner", "Welsh Corgi", "West Highland Terrier",
        "Yorkshire Terrier",
    ]

    // MARK: - Suggested chat prompts

    static let suggestedChatPrompts = [
        "How do I stop my dog from jumping on guests?",
        "My puppy cries at night — what should I do?",
        "How long should training sessions be?",
        "Why does my dog ignore commands outside?",
        "What treats work best for training?",
        "How do I teach 'leave it'?",
    ]
}
