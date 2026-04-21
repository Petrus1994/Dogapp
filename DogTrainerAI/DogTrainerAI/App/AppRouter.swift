import SwiftUI

// MARK: - Navigation Routes
enum OnboardingRoute: Hashable {
    case hasDogQuestion
    case dogProfile
    case noDogScenario
    case breedQuestionnaire
    case breedRecommendations
    case breedPicker
    case planGeneration
}

enum TodayRoute: Hashable {
    case taskDetail(String)
    case feedback(String)
    case clarification(String, TaskFeedback.FeedbackResult)
    case aiAdjustment(AIAdjustment)
    case dailySummary
    case challenges
    case behaviorProgress
}

enum MainTab: Int {
    case today   = 0
    case plan    = 1
    case chat    = 2
    case profile = 3
}

// MARK: - Router
@MainActor
final class AppRouter: ObservableObject {
    @Published var onboardingPath = NavigationPath()
    @Published var todayPath      = NavigationPath()
    @Published var selectedTab: MainTab = .today
    @Published var presentedSheet: SheetDestination?

    // Sheets triggered by activity logging
    @Published var activityToLog: DailyActivity.ActivityType?
    @Published var showActivityLog   = false
    @Published var pendingActivityForBehavior: DailyActivity?
    @Published var showBehaviorIssue = false
    @Published var showToiletLog     = false

    // Quick log (simplified flow)
    @Published var quickLogType: DailyActivity.ActivityType?
    @Published var quickLogLinkedTaskId: String?
    @Published var showQuickLog = false

    // Toast feedback
    @Published var toastMessage: String?

    func startQuickLog(type: DailyActivity.ActivityType, linkedTaskId: String? = nil) {
        quickLogType         = type
        quickLogLinkedTaskId = linkedTaskId
        showQuickLog         = true
    }

    enum SheetDestination: Identifiable {
        case chat
        var id: String { "chat" }
    }

    func navigateOnboarding(to route: OnboardingRoute) {
        onboardingPath.append(route)
    }

    func popOnboarding() {
        if !onboardingPath.isEmpty { onboardingPath.removeLast() }
    }

    func navigateToday(to route: TodayRoute) {
        todayPath.append(route)
    }

    func popToday() {
        if !todayPath.isEmpty { todayPath.removeLast() }
    }

    func popToTodayRoot() {
        todayPath = NavigationPath()
    }

    func showChat() {
        selectedTab = .chat
    }

    // Called when user taps an activity card
    func startActivityLog(type: DailyActivity.ActivityType) {
        activityToLog   = type
        showActivityLog = true
    }

    // Called after activity is saved — chains behavior issue sheet
    func didSaveActivity(_ activity: DailyActivity) {
        pendingActivityForBehavior = activity
        showBehaviorIssue = true
    }
}
