import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @StateObject private var vm = ProfileViewModel()
    @ObservedObject private var sub = SubscriptionService.shared
    @State private var dogPhoto: UIImage?
    @State private var selectedLanguage = UserDefaultsManager.shared.preferredLanguage

    var body: some View {
        NavigationStack {
            List {
                // Account
                Section("Account") {
                    profileRow(icon: "envelope.fill", label: "Email", value: appState.currentUser?.email ?? "—")
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(AppTheme.primaryFallback)
                            .frame(width: 20)
                        Text("Language")
                            .foregroundColor(.primary)
                        Spacer()
                        Picker("", selection: $selectedLanguage) {
                            ForEach(UserDefaultsManager.supportedLanguages, id: \.self) { lang in
                                Text(lang).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedLanguage) { _, newLang in
                            UserDefaultsManager.shared.preferredLanguage = newLang
                        }
                    }
                }

                // Your Dogs (always visible dog management section)
                let dogs = appState.dogs
                Section("Your Dogs") {
                    ForEach(dogs) { dog in
                        VStack(spacing: 0) {
                            if dog.type == .real, !activeDog(dog),
                               let profile = appState.dogProfile(for: dog.id) {
                                Button {
                                    appState.switchActiveDog(to: profile)
                                } label: {
                                    DogEntityRow(dog: dog, isActive: false)
                                }
                                .buttonStyle(.plain)
                            } else {
                                DogEntityRow(dog: dog, isActive: activeDog(dog))
                            }

                            if dog.type == .real && dog.subscriptionStatus != .premium {
                                Button {
                                    router.paywallDogId    = dog.id
                                    router.paywallTrigger  = "per_dog_upgrade"
                                    router.showPaywall     = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 11))
                                        Text("Upgrade \(dog.name) to Premium")
                                            .font(AppTheme.Font.caption(12))
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(AppTheme.primaryFallback)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, AppTheme.Spacing.m)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppTheme.primaryFallback.opacity(0.05))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .padding(.horizontal, AppTheme.Spacing.m)
                        .padding(.vertical, AppTheme.Spacing.s)
                    }

                    // Add Real Dog
                    if appState.dogProfile == nil {
                        Button {
                            appState.currentUser?.scenarioType = .hasDog
                            router.onboardingPath = NavigationPath()
                            router.onboardingPath.append(OnboardingRoute.hasDogQuestion)
                            router.onboardingPath.append(OnboardingRoute.dogProfile)
                            appState.flow = .onboarding
                        } label: {
                            Label("Add Real Dog", systemImage: "plus.circle.fill")
                                .foregroundColor(AppTheme.primaryFallback)
                                .font(AppTheme.Font.body(14))
                        }
                    }

                    // Add Virtual Dog
                    if appState.futureDogProfile == nil {
                        Button {
                            router.onboardingPath = NavigationPath()
                            router.onboardingPath.append(OnboardingRoute.futureDogSetup)
                            appState.flow = .onboarding
                        } label: {
                            Label("Add Virtual Dog", systemImage: "plus.circle")
                                .foregroundColor(.purple)
                                .font(AppTheme.Font.body(14))
                        }
                    }
                }

                // Subscription
                Section("Subscription") {
                    HStack {
                        Text(sub.status.icon)
                            .font(.system(size: 16))
                        Text(sub.status.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        if sub.status == .trial {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(sub.trialDaysRemaining)d remaining")
                                    .font(AppTheme.Font.caption(12))
                                    .foregroundColor(.secondary)
                                Text("\(sub.trialAIRemaining) AI chats left")
                                    .font(AppTheme.Font.caption(11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    if sub.status != .premium {
                        Button {
                            router.showPaywall = true
                            router.paywallTrigger = "profile"
                        } label: {
                            HStack(spacing: AppTheme.Spacing.m) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(AppTheme.primaryFallback)
                                    .frame(width: 20)
                                Text("Upgrade to Premium")
                                    .foregroundColor(AppTheme.primaryFallback)
                                    .font(AppTheme.Font.body())
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Training streak
                if appState.userProgress.currentStreak > 0 || appState.userProgress.longestStreak > 0 {
                    Section("Training Streak") {
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
                        if appState.userProgress.streakShields > 0 {
                            HStack {
                                Text("🛡️").font(.system(size: 18))
                                Text("Streak shields")
                                Spacer()
                                Text("\(appState.userProgress.streakShields)/3")
                                    .foregroundColor(.secondary)
                            }
                        }
                        if appState.dogProfile != nil {
                            NavigationLink(destination: WeeklySummaryView()) {
                                HStack {
                                    Text("📈").font(.system(size: 18))
                                    Text("Review Progress")
                                    Spacer()
                                }
                            }
                        }
                    }
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
                    }
                }

                // Future Dog Mode section
                if appState.isFutureDogMode, let fdProfile = appState.futureDogProfile {
                    Section("Future Dog Preparation") {
                        if let breed = fdProfile.preferredBreed {
                            profileRow(icon: "🐾", label: "Preparing for", value: breed, isEmoji: true)
                        }
                        profileRow(icon: "🏠", label: "Home", value: fdProfile.homeType.label, isEmoji: true)
                        profileRow(icon: "⚡️", label: "Lifestyle", value: fdProfile.lifestyle.label, isEmoji: true)
                        let readiness = appState.learningProfile.map { Int(($0.overallReadinessScore * 100).rounded()) } ?? 0
                        let completed = appState.learningProfile?.scenariosCompleted ?? 0
                        profileRow(icon: "📊", label: "Readiness", value: "\(readiness)%", isEmoji: true)
                        profileRow(icon: "✅", label: "Scenarios done", value: "\(completed)", isEmoji: true)
                    }

                    Section {
                        Button {
                            router.showTransformationFlow = true
                        } label: {
                            HStack(spacing: AppTheme.Spacing.m) {
                                Text("🎉").font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("I got my dog!")
                                        .foregroundColor(AppTheme.primaryFallback)
                                        .font(AppTheme.Font.body())
                                    Text("Transfer your preparation to your real dog's training")
                                        .font(AppTheme.Font.caption())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // No-dog scenario
                if appState.dogProfile == nil && !appState.isFutureDogMode, let scenario = appState.currentUser?.scenarioType {
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

                // Referral
                Section {
                    Button {
                        router.showReferralSheet = true
                    } label: {
                        HStack(spacing: AppTheme.Spacing.m) {
                            Image(systemName: "gift.fill")
                                .foregroundColor(AppTheme.primaryFallback)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Invite Friends, Earn Premium")
                                    .foregroundColor(.primary)
                                    .font(AppTheme.Font.body())
                                if let info = appState.referralInfo, info.successfulReferrals > 0 {
                                    Text("\(info.successfulReferrals) friend\(info.successfulReferrals == 1 ? "" : "s") subscribed · \(info.totalRewardDaysEarned) days earned")
                                        .font(AppTheme.Font.caption(12))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Earn free Premium for every friend who subscribes")
                                        .font(AppTheme.Font.caption(12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, AppTheme.Spacing.xs)
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
            .scrollContentBackground(.hidden)
            .background(AppTheme.appBackground.ignoresSafeArea())
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

    private func activeDog(_ entity: DogEntity) -> Bool {
        if entity.type == .real {
            return entity.id == appState.dogProfile?.id
        } else {
            return appState.isFutureDogMode && entity.id == appState.futureDogProfile?.id
        }
    }

    private func scenarioName(_ scenario: User.ScenarioType) -> String {
        switch scenario {
        case .hasDog:             return "Has a dog"
        case .noDogChoosingBreed: return "Choosing a breed"
        case .noDogBreedSelected: return "Breed selected"
        case .noDogSkipped:       return "General prep"
        case .futureDog:          return "Future Dog Mode"
        }
    }
}

// MARK: - Dog Entity Row

private struct DogEntityRow: View {
    let dog: DogEntity
    let isActive: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(dog.type == .future ? Color.purple.opacity(0.12) : AppTheme.primaryFallback.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(dog.type.icon)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dog.name)
                        .font(AppTheme.Font.body())
                        .fontWeight(isActive ? .semibold : .regular)
                    Text(dog.type.displayName)
                        .font(AppTheme.Font.caption(10))
                        .foregroundColor(dog.type == .future ? .purple : AppTheme.primaryFallback)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((dog.type == .future ? Color.purple : AppTheme.primaryFallback).opacity(0.1))
                        .cornerRadius(4)
                }
                if let breed = dog.breed {
                    Text(breed)
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(dog.subscriptionStatus.icon)
                    .font(.system(size: 14))
                if isActive {
                    Text("Active")
                        .font(AppTheme.Font.caption(10))
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
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
