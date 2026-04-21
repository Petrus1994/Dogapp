import Foundation

struct DogProfile: Codable, Identifiable {
    var id: String
    var name: String
    var gender: Gender
    var ageGroup: AgeGroup
    var birthDate: Date?          // exact birth date if known; drives aging logic
    var breed: String
    var isBreedUnknown: Bool
    var size: DogSize?
    var activityLevel: ActivityLevel
    var issues: [DogIssue]
    var photoURL: String?

    // MARK: - Exact age helpers

    var exactAgeInDays: Int {
        guard let bd = birthDate else { return ageGroup.approximateDays }
        return max(0, Calendar.current.dateComponents([.day], from: bd, to: Date()).day ?? 0)
    }

    var exactAgeInMonths: Double { Double(exactAgeInDays) / 30.44 }

    /// The current behavioral development phase, using birthDate when available.
    var currentPhase: AgePhase {
        birthDate != nil
            ? AgePhase.from(ageInMonths: exactAgeInMonths)
            : AgePhase.from(ageGroup: ageGroup)
    }

    // MARK: - Codable (backward-compat: birthDate is optional)

    enum CodingKeys: String, CodingKey {
        case id, name, gender, ageGroup, birthDate, breed, isBreedUnknown, size, activityLevel, issues, photoURL
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(String.self,         forKey: .id)
        name           = try c.decode(String.self,         forKey: .name)
        gender         = try c.decode(Gender.self,         forKey: .gender)
        ageGroup       = try c.decode(AgeGroup.self,       forKey: .ageGroup)
        birthDate      = try? c.decode(Date.self,          forKey: .birthDate)
        breed          = try c.decode(String.self,         forKey: .breed)
        isBreedUnknown = try c.decode(Bool.self,           forKey: .isBreedUnknown)
        size           = try? c.decode(DogSize.self,       forKey: .size)
        activityLevel  = try c.decode(ActivityLevel.self,  forKey: .activityLevel)
        issues         = (try? c.decode([DogIssue].self,   forKey: .issues)) ?? []
        photoURL       = try? c.decode(String.self,        forKey: .photoURL)
    }

    init(
        id: String, name: String, gender: Gender, ageGroup: AgeGroup,
        birthDate: Date? = nil, breed: String, isBreedUnknown: Bool,
        size: DogSize? = nil, activityLevel: ActivityLevel,
        issues: [DogIssue] = [], photoURL: String? = nil
    ) {
        self.id = id; self.name = name; self.gender = gender; self.ageGroup = ageGroup
        self.birthDate = birthDate; self.breed = breed; self.isBreedUnknown = isBreedUnknown
        self.size = size; self.activityLevel = activityLevel
        self.issues = issues; self.photoURL = photoURL
    }

    enum Gender: String, Codable, CaseIterable {
        case male, female
        var displayName: String {
            switch self {
            case .male: return "Male"
            case .female: return "Female"
            }
        }
    }

    enum AgeGroup: String, Codable, CaseIterable {
        case under2Months    = "under_2_months"
        case twoTo3Months    = "2_3_months"
        case threeTo5Months  = "3_5_months"
        case sixTo8Months    = "6_8_months"
        case eightTo12Months = "8_12_months"
        case oneToThreeYears = "1_3_years"
        case threeToSevenYears = "3_7_years"
        case overSevenYears  = "over_7_years"
        // Legacy — kept for backward compat with stored data
        case overOneYear     = "over_1_year"

        var displayName: String {
            switch self {
            case .under2Months:      return "Under 2 months"
            case .twoTo3Months:      return "2–3 months"
            case .threeTo5Months:    return "3–5 months"
            case .sixTo8Months:      return "6–8 months"
            case .eightTo12Months:   return "8–12 months"
            case .oneToThreeYears:   return "1–3 years"
            case .threeToSevenYears: return "3–7 years"
            case .overSevenYears:    return "7+ years"
            case .overOneYear:       return "1+ year"
            }
        }

        // Exclude legacy case from picker
        static var selectableCases: [AgeGroup] {
            allCases.filter { $0 != .overOneYear }
        }

        // Approximate midpoint in days (used when birthDate is absent)
        var approximateDays: Int {
            switch self {
            case .under2Months:      return 30
            case .twoTo3Months:      return 75
            case .threeTo5Months:    return 120
            case .sixTo8Months:      return 210
            case .eightTo12Months:   return 300
            case .oneToThreeYears, .overOneYear: return 540
            case .threeToSevenYears:             return 1825
            case .overSevenYears:                return 2920
            }
        }
    }

    enum DogSize: String, Codable, CaseIterable {
        case small, medium, large
        var displayName: String { rawValue.capitalized }
    }

    enum ActivityLevel: String, Codable, CaseIterable {
        case low, medium, high
        var displayName: String { rawValue.capitalized }
    }

    enum DogIssue: String, Codable, CaseIterable {
        case indoorAccidents  = "indoor_accidents"
        case leashPulling     = "leash_pulling"
        case biting
        case jumpingOnPeople  = "jumping_on_people"
        case fearfulness
        case disobedience
        case other

        var displayName: String {
            switch self {
            case .indoorAccidents: return "Indoor accidents"
            case .leashPulling:    return "Leash pulling"
            case .biting:          return "Biting"
            case .jumpingOnPeople: return "Jumping on people"
            case .fearfulness:     return "Fearfulness"
            case .disobedience:    return "Disobedience"
            case .other:           return "Other"
            }
        }

        var icon: String {
            switch self {
            case .indoorAccidents: return "💧"
            case .leashPulling:    return "🦮"
            case .biting:          return "🦷"
            case .jumpingOnPeople: return "⬆️"
            case .fearfulness:     return "😟"
            case .disobedience:    return "🚫"
            case .other:           return "❓"
            }
        }
    }
}
