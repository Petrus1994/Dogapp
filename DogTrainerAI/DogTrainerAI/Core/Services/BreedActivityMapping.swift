import Foundation

/// Single source of truth on iOS for breed → activity level.
/// Mirrors the backend ActivityNormService.BREED_LEVEL_MAP exactly.
/// When the backend mapping changes, update this file in sync.
struct BreedActivityMapping {

    static func activityLevel(for breed: String?) -> DogProfile.ActivityLevel {
        guard let breed = breed, !breed.isEmpty else { return .medium }
        let key = breed.lowercased().trimmingCharacters(in: .whitespaces)
        return breedMap[key] ?? .medium
    }

    private static let breedMap: [String: DogProfile.ActivityLevel] = [

        // MARK: Low energy
        "basset hound":                   .low,
        "bulldog":                        .low,
        "english bulldog":                .low,
        "french bulldog":                 .low,
        "chow chow":                      .low,
        "shih tzu":                       .low,
        "pug":                            .low,
        "maltese":                        .low,
        "bichon frise":                   .low,
        "cavalier king charles spaniel":  .low,
        "boston terrier":                 .low,
        "great dane":                     .low,
        "mastiff":                        .low,
        "english mastiff":                .low,
        "saint bernard":                  .low,
        "bloodhound":                     .low,
        "chinese shar-pei":               .low,
        "shar pei":                       .low,
        "neapolitan mastiff":             .low,
        "tibetan mastiff":                .low,
        "clumber spaniel":                .low,
        "susquehanna spaniel":            .low,
        "greyhound":                      .low,   // surprisingly low-energy at rest
        "italian greyhound":              .low,

        // MARK: Medium energy
        "labrador retriever":             .medium,
        "golden retriever":               .medium,
        "german shepherd":                .medium,
        "poodle":                         .medium,
        "standard poodle":                .medium,
        "miniature poodle":               .medium,
        "beagle":                         .medium,
        "dachshund":                      .medium,
        "rottweiler":                     .medium,
        "boxer":                          .medium,
        "husky":                          .medium,
        "doberman":                       .medium,
        "doberman pinscher":              .medium,
        "cocker spaniel":                 .medium,
        "english cocker spaniel":         .medium,
        "schnauzer":                      .medium,
        "standard schnauzer":             .medium,
        "miniature schnauzer":            .medium,
        "samoyed":                        .medium,
        "akita":                          .medium,
        "alaskan malamute":               .medium,
        "bernese mountain dog":           .medium,
        "shiba inu":                      .medium,
        "corgi":                          .medium,
        "pembroke welsh corgi":           .medium,
        "cardigan welsh corgi":           .medium,
        "german short-haired pointer":    .medium,
        "flat-coated retriever":          .medium,
        "english setter":                 .medium,
        "gordon setter":                  .medium,
        "brittany spaniel":               .medium,

        // MARK: High energy
        "border collie":                  .high,
        "belgian malinois":               .high,
        "jack russell terrier":           .high,
        "jack russel terrier":            .high,
        "australian shepherd":            .high,
        "vizsla":                         .high,
        "weimaraner":                     .high,
        "dalmatian":                      .high,
        "pointer":                        .high,
        "english pointer":                .high,
        "springer spaniel":               .high,
        "english springer spaniel":       .high,
        "irish setter":                   .high,
        "siberian husky":                 .high,
        "whippet":                        .high,
        "rat terrier":                    .high,
        "rhodesian ridgeback":            .high,
        "belgian tervuren":               .high,
        "belgian sheepdog":               .high,
        "airedale terrier":               .high,
        "fox terrier":                    .high,
        "wire fox terrier":               .high,
        "smooth fox terrier":             .high,
        "kelpie":                         .high,
        "australian kelpie":              .high,
        "border terrier":                 .high,
        "dutch shepherd":                 .high,
    ]
}
