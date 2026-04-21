import SwiftUI

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var greeting: String = ""

    func buildGreeting(userName: String?) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name: String = userName.flatMap { email in
            let prefix = email.components(separatedBy: "@").first ?? ""
            let parts = prefix
                .components(separatedBy: CharacterSet(charactersIn: "._-"))
                .filter { !$0.isEmpty }
            return (parts.first { $0.count > 2 } ?? parts.first)?.capitalized
        } ?? "there"
        switch hour {
        case 5..<12:  return "Good morning, \(name) 🌅"
        case 12..<17: return "Good afternoon, \(name) ☀️"
        case 17..<21: return "Good evening, \(name) 🌆"
        default:      return "Hey, \(name) 🌙"
        }
    }

    func dogSummary(dogProfile: DogProfile?) -> String {
        guard let dog = dogProfile else { return "Universal preparation plan" }
        return "\(dog.name) • \(dog.ageGroup.displayName) • \(dog.breed)"
    }

    func progressStats(from plan: Plan?) -> (completed: Int, partial: Int, failed: Int, total: Int) {
        guard let plan else { return (0, 0, 0, 0) }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: plan.startDate, to: Date()).day ?? 0
        let currentDay = max(1, daysSinceStart + 1)
        let todayTasks = plan.tasks.filter { $0.scheduledDay <= currentDay }
        let completed = todayTasks.filter { $0.status == .completed }.count
        let partial   = todayTasks.filter { $0.status == .partial }.count
        let failed    = todayTasks.filter { $0.status == .failed }.count
        return (completed, partial, failed, todayTasks.count)
    }
}
