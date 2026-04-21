import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @StateObject private var vm = ProfileViewModel()
    @State private var dogPhoto: UIImage?

    var body: some View {
        NavigationStack {
            List {
                // Progress section
                Section(header: Text("Your Progress"), footer: Text("Points track how consistently and honestly you train. They don't unlock anything — they reflect real effort.").font(.caption).foregroundColor(.secondary)) {
                    // Level
                    HStack(spacing: AppTheme.Spacing.m) {
                        Text(appState.userProgress.level.icon).font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.userProgress.level.displayName)
                                .font(AppTheme.Font.title(15))
                            if let next = appState.userProgress.level.nextLevel {
                                Text("\(appState.userProgress.pointsToNextLevel) pts to \(next.displayName)")
                                    .font(AppTheme.Font.caption(12))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Maximum level reached")
                                    .font(AppTheme.Font.caption(12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(appState.userProgress.totalPoints) pts")
                            .font(AppTheme.Font.title(14))
                            .foregroundColor(AppTheme.primaryFallback)
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)

                    // Level progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressBarView(
                            progress: appState.userProgress.progressToNextLevel,
                            color: AppTheme.primaryFallback
                        )
                        .frame(height: 6)
                    }

                    // Streak
                    HStack {
                        Text("🔥").font(.system(size: 18))
                        Text("Current streak")
                        Spacer()
                        Text("\(appState.userProgress.currentStreak) days")
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("🏅").font(.system(size: 18))
                        Text("Best streak")
                        Spacer()
                        Text("\(appState.userProgress.longestStreak) days")
                            .foregroundColor(.secondary)
                    }

                    // Challenges link
                    NavigationLink(destination: ChallengesView()) {
                        HStack {
                            Text("🎯").font(.system(size: 18))
                            Text("Challenges")
                            Spacer()
                            let done = appState.challenges.filter { $0.isCompleted }.count
                            Text("\(done)/\(appState.challenges.count) done")
                                .foregroundColor(.secondary)
                                .font(AppTheme.Font.body(14))
                        }
                    }

                    // Leaderboard link
                    NavigationLink(destination: LeaderboardView()) {
                        HStack {
                            Text("🏆").font(.system(size: 18))
                            Text("Leaderboard")
                            Spacer()
                            Text("#\(leaderboardRank) of 16")
                                .foregroundColor(.secondary)
                                .font(AppTheme.Font.body(14))
                        }
                    }

                    // Behavior progress
                    if appState.dogProfile != nil {
                        NavigationLink(destination: BehaviorProgressView()) {
                            HStack {
                                Text("📈").font(.system(size: 18))
                                Text("Behavior Progress")
                                Spacer()
                                let improving = appState.behaviorProgress.scores
                                    .filter { $0.trend == .improving && $0.confidence > 20 }.count
                                if improving > 0 {
                                    Text("\(improving) improving")
                                        .foregroundColor(.green)
                                        .font(AppTheme.Font.body(14))
                                } else {
                                    Text("View report")
                                        .foregroundColor(.secondary)
                                        .font(AppTheme.Font.body(14))
                                }
                            }
                        }
                    }
                }

                // Account
                Section("Account") {
                    profileRow(icon: "envelope.fill", label: "Email", value: appState.currentUser?.email ?? "—")
                }

                // Dog
                if let dog = appState.dogProfile {
                    Section("Your Dog") {
                        if let photo = dogPhoto {
                            HStack {
                                Spacer()
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                        profileRow(icon: "🐕", label: "Name", value: dog.name, isEmoji: true)
                        profileRow(icon: "📅", label: "Age", value: dog.ageGroup.displayName, isEmoji: true)
                        profileRow(icon: "🦴", label: "Breed", value: dog.breed, isEmoji: true)
                        profileRow(icon: "⚡️", label: "Activity", value: dog.activityLevel.displayName, isEmoji: true)
                        if !dog.issues.isEmpty {
                            profileRow(icon: "🎯", label: "Focus areas", value: dog.issues.map { $0.displayName }.joined(separator: ", "), isEmoji: true)
                        }
                        Button {
                            router.onboardingPath = NavigationPath()
                            router.onboardingPath.append(OnboardingRoute.hasDogQuestion)
                            router.onboardingPath.append(OnboardingRoute.dogProfile)
                            appState.flow = .onboarding
                        } label: {
                            Label("Edit dog profile", systemImage: "pencil")
                                .foregroundColor(AppTheme.primaryFallback)
                                .font(AppTheme.Font.body(14))
                        }
                    }
                }

                // Plan
                if let plan = appState.currentPlan {
                    Section("Current Plan") {
                        profileRow(icon: "list.clipboard.fill", label: "Plan", value: plan.title)
                        profileRow(icon: "chart.bar.fill", label: "Progress", value: "\(Int(plan.progressFraction * 100))% complete")
                    }
                }

                // No-dog scenario
                if appState.dogProfile == nil, let scenario = appState.currentUser?.scenarioType {
                    Section("Your Scenario") {
                        profileRow(icon: "info.circle.fill", label: "Mode", value: scenarioName(scenario))
                        if let breed = appState.selectedBreed {
                            profileRow(icon: "🔍", label: "Selected breed", value: breed.name, isEmoji: true)
                        }
                    }

                    Section {
                        Button {
                            vm.showHasDogConfirm = true
                        } label: {
                            HStack(spacing: AppTheme.Spacing.m) {
                                Text("🐕").font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("I now have a dog!")
                                        .foregroundColor(AppTheme.primaryFallback)
                                        .font(AppTheme.Font.body())
                                    Text("Set up your dog's profile and get a personalised plan")
                                        .font(AppTheme.Font.caption())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        vm.showLogoutConfirm = true
                    } label: {
                        HStack {
                            if vm.isLoggingOut {
                                ProgressView().tint(.red)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                            }
                            Text("Log Out")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .task {
                guard let urlString = appState.dogProfile?.photoURL,
                      let url = URL(string: urlString),
                      let data = try? Data(contentsOf: url) else { return }
                dogPhoto = UIImage(data: data)
            }
            .confirmationDialog("Log out?", isPresented: $vm.showLogoutConfirm, titleVisibility: .visible) {
                Button("Log Out", role: .destructive) {
                    Task { await vm.logout(appState: appState) }
                }
            } message: {
                Text("You'll need to sign in again.")
            }
            .confirmationDialog("Set up your dog?", isPresented: $vm.showHasDogConfirm, titleVisibility: .visible) {
                Button("Yes, set up dog profile") {
                    appState.currentUser?.scenarioType = .hasDog
                    router.onboardingPath = NavigationPath()
                    router.onboardingPath.append(OnboardingRoute.hasDogQuestion)
                    router.onboardingPath.append(OnboardingRoute.dogProfile)
                    appState.flow = .onboarding
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll enter your dog's details and we'll generate a personalised training plan. Your preparation tasks will stay saved.")
            }
        }
    }

    private func profileRow(icon: String, label: String, value: String, isEmoji: Bool = false) -> some View {
        HStack {
            Group {
                if isEmoji {
                    Text(icon).font(.system(size: 16))
                } else {
                    Image(systemName: icon)
                        .foregroundColor(AppTheme.primaryFallback)
                        .frame(width: 20)
                }
            }
            Text(label).foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .font(AppTheme.Font.body(14))
                .lineLimit(1)
        }
    }

    private var leaderboardRank: Int {
        let entries = LeaderboardEntry.mockEntries(
            userPoints: appState.userProgress.totalPoints,
            userLevel: appState.userProgress.level,
            userStreak: appState.userProgress.currentStreak
        )
        return (entries.firstIndex { $0.isCurrentUser } ?? 0) + 1
    }

    private func scenarioName(_ scenario: User.ScenarioType) -> String {
        switch scenario {
        case .hasDog:             return "Has a dog"
        case .noDogChoosingBreed: return "Choosing a breed"
        case .noDogBreedSelected: return "Breed selected"
        case .noDogSkipped:       return "General prep"
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject({
            let s = AppState()
            s.currentUser = User(id: "1", email: "test@example.com", onboardingCompleted: true, scenarioType: .hasDog)
            s.dogProfile  = DogProfile(id: "1", name: "Luna", gender: .female, ageGroup: .twoTo3Months, breed: "Golden Retriever", isBreedUnknown: false, size: nil, activityLevel: .medium, issues: [.indoorAccidents], photoURL: nil)
            s.currentPlan = MockData.puppyPlan
            return s
        }())
        .environmentObject(AppRouter())
}
