import SwiftUI
import PhotosUI

enum AgeInputMode: Equatable {
    case exactDate
    case approximate
}

@MainActor
final class DogProfileViewModel: ObservableObject {
    @Published var name           = ""
    @Published var gender         = DogProfile.Gender.male
    @Published var breed          = ""
    @Published var isBreedUnknown = false
    @Published var size           = DogProfile.DogSize.medium
    @Published var coatColor      = CoatColor.golden
    @Published var selectedIssues = Set<DogProfile.DogIssue>()
    @Published var photoItem: PhotosPickerItem?
    @Published var selectedPhoto: UIImage?
    @Published var validationError: String?

    var derivedActivityLevel: DogProfile.ActivityLevel {
        isBreedUnknown ? .medium : BreedActivityMapping.activityLevel(for: breed)
    }

    // Age input
    @Published var ageInputMode: AgeInputMode = .approximate
    @Published var birthDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @Published var approximateYears: Int = 0
    @Published var approximateMonths: Int = 0

    private var savedPhotoURL: String?

    // Derived birth date from approximate input
    var computedBirthDate: Date {
        switch ageInputMode {
        case .exactDate:
            return birthDate
        case .approximate:
            let totalMonths = approximateYears * 12 + approximateMonths
            return Calendar.current.date(
                byAdding: .month, value: -max(0, totalMonths), to: Date()
            ) ?? Date()
        }
    }

    // Human-readable age summary
    var ageSummaryLabel: String {
        let date = computedBirthDate
        let now  = Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: date, to: now)
        let y = comps.year  ?? 0
        let m = comps.month ?? 0
        if y == 0 && m == 0 { return "Less than 1 month old" }
        if y == 0 { return "\(m) month\(m == 1 ? "" : "s") old" }
        if m == 0 { return "\(y) year\(y == 1 ? "" : "s") old" }
        return "\(y) year\(y == 1 ? "" : "s") \(m) month\(m == 1 ? "" : "s") old"
    }

    // Derive AgeGroup from computed birth date
    private var derivedAgeGroup: DogProfile.AgeGroup {
        let months = monthsFromDate(computedBirthDate)
        switch months {
        case ..<1.75:  return .under2Months
        case ..<3.5:   return .twoTo3Months
        case ..<5.5:   return .threeTo5Months
        case ..<8.0:   return .sixTo8Months
        case ..<12.0:  return .eightTo12Months
        case ..<36.0:  return .oneToThreeYears
        case ..<84.0:  return .threeToSevenYears
        default:       return .overSevenYears
        }
    }

    private func monthsFromDate(_ date: Date) -> Double {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return Double(days) / 30.44
    }

    func loadPhoto() async {
        guard let item = photoItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        selectedPhoto = image
        savedPhotoURL = persistPhoto(data)
    }

    private func persistPhoto(_ data: Data) -> String? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = dir.appendingPathComponent("dog-photo.jpg")
        try? data.write(to: url)
        return url.absoluteString
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (isBreedUnknown || !breed.trimmingCharacters(in: .whitespaces).isEmpty) &&
        !(ageInputMode == .approximate && approximateYears == 0 && approximateMonths == 0)
    }

    func toggleIssue(_ issue: DogProfile.DogIssue) {
        if selectedIssues.contains(issue) {
            selectedIssues.remove(issue)
        } else {
            selectedIssues.insert(issue)
        }
    }

    func buildProfile() -> DogProfile? {
        guard isValid else {
            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                validationError = "Please enter your dog's name."
            } else if ageInputMode == .approximate && approximateYears == 0 && approximateMonths == 0 {
                validationError = "Please enter your dog's age."
            }
            return nil
        }
        return DogProfile(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            gender: gender,
            ageGroup: derivedAgeGroup,
            birthDate: computedBirthDate,
            breed: isBreedUnknown ? "Unknown / Mixed" : breed,
            isBreedUnknown: isBreedUnknown,
            size: isBreedUnknown ? size : nil,
            activityLevel: derivedActivityLevel,
            coatColor: coatColor,
            issues: Array(selectedIssues),
            photoURL: savedPhotoURL
        )
    }
}
