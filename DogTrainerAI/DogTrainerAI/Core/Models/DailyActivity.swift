import Foundation

struct DailyActivity: Codable, Identifiable {
    var id: String
    var date: Date
    var type: ActivityType
    var durationMinutes: Int
    var completed: Bool
    var walkQuality: WalkQuality?
    var distanceKm: Double?       // walk only
    var stepCount: Int?           // walk only (estimated)
    var foodType: FoodType?       // feeding only
    var feedingNumber: Int?       // which feeding of the day (1, 2, 3…)
    var playActivity: PlayActivity? // play only
    var notes: String

    // MARK: - Codable (backward-compatible: all new fields are optional)

    enum CodingKeys: String, CodingKey {
        case id, date, type, durationMinutes, completed
        case walkQuality, distanceKm, stepCount
        case foodType, feedingNumber, playActivity, notes
    }

    init(
        id: String, date: Date, type: ActivityType,
        durationMinutes: Int, completed: Bool,
        walkQuality: WalkQuality? = nil,
        distanceKm: Double? = nil, stepCount: Int? = nil,
        foodType: FoodType? = nil, feedingNumber: Int? = nil,
        playActivity: PlayActivity? = nil,
        notes: String = ""
    ) {
        self.id = id; self.date = date; self.type = type
        self.durationMinutes = durationMinutes; self.completed = completed
        self.walkQuality = walkQuality; self.distanceKm = distanceKm
        self.stepCount = stepCount; self.foodType = foodType
        self.feedingNumber = feedingNumber; self.playActivity = playActivity
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self,       forKey: .id)
        date            = try c.decode(Date.self,         forKey: .date)
        type            = try c.decode(ActivityType.self, forKey: .type)
        durationMinutes = try c.decode(Int.self,          forKey: .durationMinutes)
        completed       = try c.decode(Bool.self,         forKey: .completed)
        walkQuality     = try? c.decode(WalkQuality.self,   forKey: .walkQuality)
        distanceKm      = try? c.decode(Double.self,        forKey: .distanceKm)
        stepCount       = try? c.decode(Int.self,           forKey: .stepCount)
        foodType        = try? c.decode(FoodType.self,      forKey: .foodType)
        feedingNumber   = try? c.decode(Int.self,           forKey: .feedingNumber)
        playActivity    = try? c.decode(PlayActivity.self,  forKey: .playActivity)
        notes           = (try? c.decode(String.self,       forKey: .notes)) ?? ""
    }

    // MARK: - Activity types

    enum ActivityType: String, Codable, CaseIterable {
        case feeding, walking, playing, training, parkSession

        var displayName: String {
            switch self {
            case .feeding:     return "Feeding"
            case .walking:     return "Walk"
            case .playing:     return "Play"
            case .training:    return "Training"
            case .parkSession: return "Park Session"
            }
        }

        var icon: String {
            switch self {
            case .feeding:     return "🍖"
            case .walking:     return "🦮"
            case .playing:     return "🎾"
            case .training:    return "🎯"
            case .parkSession: return "🌳"
            }
        }

        var systemIcon: String {
            switch self {
            case .feeding:     return "fork.knife"
            case .walking:     return "figure.walk"
            case .playing:     return "figure.play"
            case .training:    return "brain.head.profile"
            case .parkSession: return "tree"
            }
        }

        var defaultDurationMinutes: Int {
            switch self {
            case .feeding:     return 10
            case .walking:     return 30
            case .playing:     return 20
            case .training:    return 15
            case .parkSession: return 45
            }
        }

        var pointValue: Int {
            switch self {
            case .feeding:     return 5
            case .walking:     return 8
            case .playing:     return 6
            case .training:    return 5
            case .parkSession: return 12  // bonus: covers walk + play in one
            }
        }

        // Park sessions count as both walk and play for norm completion
        var countsAsWalk: Bool  { self == .walking  || self == .parkSession }
        var countsAsPlay: Bool  { self == .playing   || self == .parkSession }
    }

    // MARK: - Walk quality

    enum WalkQuality: String, Codable, CaseIterable {
        case calm, pulling, distracted

        var displayName: String {
            switch self {
            case .calm:       return "Calm"
            case .pulling:    return "Pulling"
            case .distracted: return "Distracted"
            }
        }

        var icon: String {
            switch self {
            case .calm:       return "😌"
            case .pulling:    return "😤"
            case .distracted: return "😵"
            }
        }
    }

    // MARK: - Food types

    enum FoodType: String, Codable, CaseIterable {
        case dry, wet, natural, mixed

        var displayName: String {
            switch self {
            case .dry:     return "Dry food"
            case .wet:     return "Wet food"
            case .natural: return "Natural / raw"
            case .mixed:   return "Mixed"
            }
        }

        var icon: String {
            switch self {
            case .dry:     return "🥣"
            case .wet:     return "🫙"
            case .natural: return "🥩"
            case .mixed:   return "🍽️"
            }
        }
    }

    // MARK: - Play activities

    enum PlayActivity: String, Codable, CaseIterable {
        case fetch, tug, agility, hiddenTreats, freePark, puzzle, other

        var displayName: String {
            switch self {
            case .fetch:        return "Fetch"
            case .tug:          return "Tug of war"
            case .agility:      return "Agility"
            case .hiddenTreats: return "Scent / hidden treats"
            case .freePark:     return "Free run (park)"
            case .puzzle:       return "Puzzle toy"
            case .other:        return "Other"
            }
        }

        var icon: String {
            switch self {
            case .fetch:        return "🎾"
            case .tug:          return "🪢"
            case .agility:      return "🏃"
            case .hiddenTreats: return "👃"
            case .freePark:     return "🌳"
            case .puzzle:       return "🧩"
            case .other:        return "🐾"
            }
        }
    }
}
