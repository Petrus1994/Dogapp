import SwiftUI

// MARK: - Navigation Routes
enum OnboardingRoute: Hashable {
    case hasDogQuestion
    case dogProfile
    case avatarReveal
    case problemIdentification
    case instantAICoach
    case avatarSetup
    case noDogScenario
    case breedQuestionnaire
    case breedRecommendations
    case breedPicker
    case planGeneration
    case futureDogSetup
}

enum TodayRoute: Hashable {
    case taskDetail(String)
    case feedback(String)
    case clarification(String, TaskFeedback.FeedbackResult)
    case aiAdjustment(AIAdjustment)
    case dailySummary
    case challenges
    case behaviorProgress
    case weeklySummary
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

    // Voice quick log
    @Published var showVoiceLog = false

    // Activity-specific chat
    @Published var showActivityChat = false
    @Published var activityChatType: DailyActivity.ActivityType? = nil
    // Pre-loads a message into the activity chat input on open (e.g. from notification)
    @Published var pendingActivityChatMessage: String? = nil

    // Referral sheet
    @Published var showReferralSheet = false

    // Paywall + trial activation
    @Published var showPaywall: Bool = false
    @Published var paywallTrigger: String? = nil
    @Published var paywallDogId: String? = nil
    @Published var showTrialActivation: Bool = false

    // Future Dog transformation flow
    @Published var showTransformationFlow = false

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

    func openActivityChat(type: DailyActivity.ActivityType, preloadedMessage: String? = nil) {
        activityChatType          = type
        pendingActivityChatMessage = preloadedMessage
        showActivityChat          = true
    }

    // Called when a push notification is tapped — routes to correct screen
    func routeFromNotification(_ route: String) {
        switch route {
        case "feeding":  openActivityChat(type: .feeding)
        case "walking":  openActivityChat(type: .walking)
        case "playing":  openActivityChat(type: .playing)
        case "training": openActivityChat(type: .training)
        case "ai_insight": selectedTab = .chat
        default:         selectedTab = .today
        }
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
