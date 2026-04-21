import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TodayFlowView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(MainTab.today)

            PlanView()
                .tabItem { Label("Plan", systemImage: "list.bullet.clipboard") }
                .tag(MainTab.plan)

            ChatView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(MainTab.chat)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(MainTab.profile)
        }
        .tint(AppTheme.primaryFallback)
    }
}

struct TodayFlowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.todayPath) {
            TodayView()
                .navigationDestination(for: TodayRoute.self) { route in
                    switch route {
                    case .taskDetail(let taskId):
                        if let task = appState.currentPlan?.tasks.first(where: { $0.id == taskId }) {
                            TaskDetailView(task: task)
                        }
                    case .feedback(let taskId):
                        if let task = appState.currentPlan?.tasks.first(where: { $0.id == taskId }) {
                            FeedbackView(task: task)
                        }
                    case .clarification(let taskId, let result):
                        if let task = appState.currentPlan?.tasks.first(where: { $0.id == taskId }) {
                            ClarificationView(task: task, result: result)
                        }
                    case .aiAdjustment(let adjustment):
                        AIAdjustmentView(adjustment: adjustment)
                    case .dailySummary:
                        DailySummaryView()
                    case .challenges:
                        ChallengesView()
                    case .behaviorProgress:
                        BehaviorProgressView()
                    }
                }
        }
    }
}
