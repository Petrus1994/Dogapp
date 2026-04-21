import SwiftUI

struct BreedQuestionnaireView: View {
    @EnvironmentObject var router: AppRouter
    @ObservedObject var vm: BreedSelectionViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {
                    OnboardingStepDots(current: 3)
                        .padding(.top, AppTheme.Spacing.s)

                    VStack(spacing: AppTheme.Spacing.s) {
                        Text("Let's find your match")
                            .font(AppTheme.Font.headline())
                        Text("Answer a few questions and we'll recommend the best breeds for you.")
                            .font(AppTheme.Font.body())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppTheme.Spacing.m)

                    questionSection("Your lifestyle") {
                        IconPickerRow(
                            options: BreedSelectionProfile.Lifestyle.allCases,
                            selected: $vm.lifestyle,
                            displayName: { $0.displayName },
                            icon: { $0.icon }
                        )
                    }

                    questionSection("Where you live") {
                        IconPickerRow(
                            options: BreedSelectionProfile.HomeType.allCases,
                            selected: $vm.homeType,
                            displayName: { $0.displayName },
                            icon: { $0.icon }
                        )
                    }

                    questionSection("Your dog experience") {
                        IconPickerRow(
                            options: BreedSelectionProfile.ExperienceLevel.allCases,
                            selected: $vm.experience,
                            displayName: { $0.displayName },
                            icon: { $0.icon }
                        )
                    }

                    questionSection("Time available for dog care daily") {
                        IconPickerRow(
                            options: BreedSelectionProfile.AvailableTime.allCases,
                            selected: $vm.availableTime,
                            displayName: { $0.displayName },
                            icon: { $0.icon }
                        )
                    }

                    questionSection("Children at home?") {
                        HStack(spacing: AppTheme.Spacing.m) {
                            toggleChip("Yes 👨‍👩‍👧", isSelected: vm.hasChildren)  { vm.hasChildren = true }
                            toggleChip("No 🧑",       isSelected: !vm.hasChildren) { vm.hasChildren = false }
                        }
                    }

                    questionSection("Your goal with a dog") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.s) {
                            ForEach(BreedSelectionProfile.DogGoal.allCases, id: \.self) { g in
                                toggleChip("\(g.icon) \(g.displayName)", isSelected: vm.goal == g) {
                                    vm.goal = g
                                }
                            }
                        }
                    }

                    questionSection("Preferred dog size") {
                        IconPickerRow(
                            options: BreedSelectionProfile.SizePreference.allCases,
                            selected: $vm.sizePreference,
                            displayName: { $0.displayName },
                            icon: { $0.icon }
                        )
                    }

                    questionSection("Preferred weight range") {
                        IconPickerRow(
                            options: BreedSelectionProfile.WeightPreference.allCases,
                            selected: $vm.weightPreference,
                            displayName: { $0.displayName },
                            icon: { $0.icon }
                        )
                    }

                    questionSection("Coat type preference") {
                        IconPickerRow(
                            options: BreedSelectionProfile.CoatType.allCases,
                            selected: $vm.coatType,
                            displayName: { $0.displayName },
                            icon: { $0.icon }
                        )
                    }

                    questionSection("How much grooming are you prepared for?") {
                        IconPickerRow(
                            options: BreedSelectionProfile.GroomingTolerance.allCases,
                            selected: $vm.groomingTolerance,
                            displayName: { $0.displayName },
                            icon: { $0.icon }
                        )
                    }

                    questionSection("Noise / barking tolerance") {
                        HStack(spacing: AppTheme.Spacing.m) {
                            ForEach(BreedSelectionProfile.NoiseTolerance.allCases, id: \.self) { n in
                                toggleChip("\(n.icon) \(n.displayName)", isSelected: vm.noiseTolerance == n) {
                                    vm.noiseTolerance = n
                                }
                            }
                        }
                    }

                    questionSection("Expected energy level") {
                        IconPickerRow(
                            options: BreedSelectionProfile.EnergyExpectation.allCases,
                            selected: $vm.energyExpectation,
                            displayName: { $0.displayName },
                            icon: { $0.icon }
                        )
                    }

                    if let error = vm.errorMessage {
                        ErrorBanner(message: error)
                            .padding(.horizontal, AppTheme.Spacing.l)
                    }

                    Spacer(minLength: AppTheme.Spacing.xl)
                }
            }

            // Sticky submit button
            VStack(spacing: 0) {
                Divider()
                PrimaryButton(title: "Find My Breed", action: {
                    Task {
                        await vm.fetchRecommendations()
                        if !vm.recommendations.isEmpty {
                            router.navigateOnboarding(to: .breedRecommendations)
                        }
                    }
                }, isLoading: vm.isLoading)
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.vertical, AppTheme.Spacing.m)
            }
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("Breed Finder")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func questionSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text(title)
                .font(AppTheme.Font.title(15))
                .padding(.horizontal, AppTheme.Spacing.l)
            content()
                .padding(.horizontal, AppTheme.Spacing.l)
        }
    }

    private func toggleChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTheme.Font.body(15))
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.vertical, AppTheme.Spacing.s)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                        .fill(isSelected ? AppTheme.primaryFallback.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                .stroke(isSelected ? AppTheme.primaryFallback : Color.clear, lineWidth: 1.5)
                        )
                )
                .foregroundColor(isSelected ? AppTheme.primaryFallback : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct IconPickerRow<T: Hashable>: View {
    let options: [T]
    @Binding var selected: T
    let displayName: (T) -> String
    let icon: (T) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.s) {
                ForEach(options, id: \.self) { option in
                    Button(action: { selected = option }) {
                        VStack(spacing: 4) {
                            Text(icon(option)).font(.system(size: 24))
                            Text(displayName(option))
                                .font(AppTheme.Font.caption(12))
                                .multilineTextAlignment(.center)
                        }
                        .frame(minWidth: 70)
                        .padding(.vertical, AppTheme.Spacing.s)
                        .padding(.horizontal, AppTheme.Spacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                .fill(selected == option ? AppTheme.primaryFallback.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                        .stroke(selected == option ? AppTheme.primaryFallback : Color.clear, lineWidth: 1.5)
                                )
                        )
                        .foregroundColor(selected == option ? AppTheme.primaryFallback : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    BreedQuestionnaireView(vm: BreedSelectionViewModel())
        .environmentObject(AppRouter())
}
