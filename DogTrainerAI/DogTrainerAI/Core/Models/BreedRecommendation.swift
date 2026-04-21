import Foundation

struct BreedRecommendation: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var breedDescription: String
    var reason: String
    var imageName: String?

    // Backward-compatible decoder: read legacy shortDescription/whyItFits if new keys absent
    enum CodingKeys: String, CodingKey {
        case id, name, imageName
        case breedDescription
        case reason
        case shortDescription   // legacy
        case whyItFits          // legacy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        name      = try c.decode(String.self, forKey: .name)
        imageName = try? c.decode(String.self, forKey: .imageName)
        breedDescription = (try? c.decode(String.self, forKey: .breedDescription))
                        ?? (try? c.decode(String.self, forKey: .shortDescription))
                        ?? ""
        reason    = (try? c.decode(String.self, forKey: .reason))
                 ?? (try? c.decode(String.self, forKey: .whyItFits))
                 ?? ""
    }

    init(id: String, name: String, breedDescription: String, reason: String, imageName: String? = nil) {
        self.id               = id
        self.name             = name
        self.breedDescription = breedDescription
        self.reason           = reason
        self.imageName        = imageName
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,               forKey: .id)
        try c.encode(name,             forKey: .name)
        try c.encode(breedDescription, forKey: .breedDescription)
        try c.encode(reason,           forKey: .reason)
        try c.encodeIfPresent(imageName, forKey: .imageName)
    }

    static func == (lhs: BreedRecommendation, rhs: BreedRecommendation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
