import Foundation

// MARK: - Avatar generation status

enum AvatarGenerationStatus: String, Codable {
    case none         // never started
    case pending      // created in DB, not yet kicked off
    case uploading    // uploading reference photos
    case analyzing    // running trait extraction
    case generating   // image being generated
    case completed    // avatar URL available
    case failed       // generation failed

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AvatarGenerationStatus(rawValue: raw) ?? .none
    }
}

// MARK: - Dog Avatar metadata (mirrors backend DogAvatar)

struct DogAvatar: Codable {
    var id: String
    var dogId: String
    var masterAvatarUrl: String?
    var thumbnailUrl: String?
    var currentAgeStage: String
    var avatarVersion: Int
    var provider: String?
    var generationStatus: AvatarGenerationStatus
    var regenerationCount: Int
    var maxRegenerations: Int
    var referencePhotoUrls: [String]
    var createdAt: Date?
    var updatedAt: Date?

    var canRegenerate: Bool { regenerationCount < maxRegenerations }
    var regenerationsLeft: Int { max(0, maxRegenerations - regenerationCount) }
}

// MARK: - Dog Visual Traits

struct DogVisualTraits: Codable {
    var breedGuessFromImage: String?
    var coatColor: String?
    var coatPattern: String?
    var coatLength: String?
    var coatTexture: String?
    var earType: String?
    var muzzleShape: String?
    var noseColor: String?
    var eyeColor: String?
    var tailType: String?
    var bodyShape: String?
    var sizeClass: String?
    var ageStage: String?
    var distinctiveMarks: String?
    var confidenceScore: Double?
    var warnings: [String]
}

// MARK: - Generation job response

struct AvatarGenerationJob: Codable {
    var jobId: String
    var status: String
    var message: String?
    var regenerationsLeft: Int?
}

// MARK: - Avatar API response

struct AvatarResponse: Codable {
    var avatar: DogAvatar?
    var visualTraits: DogVisualTraits?
    var regenerationsLeft: Int
}

// MARK: - Avatar state result from backend

struct AvatarStateResult: Codable {
    var state: String
    var stateReason: String
    var recommendedCopy: String
}
