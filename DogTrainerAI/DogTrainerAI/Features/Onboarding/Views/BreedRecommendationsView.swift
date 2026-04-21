import SwiftUI

struct BreedRecommendationsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @ObservedObject var vm: BreedSelectionViewModel
    @State private var expandedId: String?

    var body: some View {
        Group {
            if vm.isLoading {
                LoadingView(message: "Finding your perfect match…")
            } else if vm.recommendations.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.m) {
                        VStack(spacing: AppTheme.Spacing.s) {
                            Text("Your Top Matches")
                                .font(AppTheme.Font.headline())
                            Text("Based on your lifestyle, we recommend these breeds.")
                                .font(AppTheme.Font.body())
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, AppTheme.Spacing.m)

                        ForEach(vm.recommendations) { breed in
                            BreedCard(
                                breed: breed,
                                isExpanded: expandedId == breed.id,
                                onExpand: { expandedId = expandedId == breed.id ? nil : breed.id },
                                onSelect: {
                                    appState.selectedBreed = breed
                                    router.navigateOnboarding(to: .planGeneration)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.l)
                    .padding(.bottom, AppTheme.Spacing.xl)
                }
            }
        }
        .navigationTitle("Breed Recommendations")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Text("😕")
                .font(.system(size: 52))
            Text("No results found")
                .font(AppTheme.Font.headline())
            Text("Try adjusting your preferences.")
                .foregroundColor(.secondary)
            SecondaryButton(title: "Back") {
                router.popOnboarding()
            }
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }
}

struct BreedCard: View {
    let breed: BreedRecommendation
    let isExpanded: Bool
    let onExpand: () -> Void
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                Button(action: onExpand) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(breed.name)
                                .font(AppTheme.Font.title(16))
                                .foregroundColor(.primary)
                            Text(breed.breedDescription)
                                .font(AppTheme.Font.caption())
                                .foregroundColor(.secondary)
                                .lineLimit(isExpanded ? nil : 1)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if !isExpanded {
                    Button(action: onExpand) {
                        Text("See why →")
                            .font(AppTheme.Font.body(13))
                            .foregroundColor(AppTheme.primaryFallback)
                            .padding(.horizontal, AppTheme.Spacing.m)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().stroke(AppTheme.primaryFallback.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                    Label("Why it fits you", systemImage: "checkmark.seal.fill")
                        .font(AppTheme.Font.caption())
                        .foregroundColor(AppTheme.primaryFallback)

                    Text(breed.reason)
                        .font(AppTheme.Font.body(15))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }

                PrimaryButton(title: "Choose \(breed.name)", action: onSelect)
            }
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
        .animation(.spring(response: 0.35), value: isExpanded)
    }
}

#Preview {
    BreedRecommendationsView(vm: {
        let vm = BreedSelectionViewModel()
        vm.recommendations = MockData.moderateBreeds
        return vm
    }())
    .environmentObject(AppState())
    .environmentObject(AppRouter())
}
