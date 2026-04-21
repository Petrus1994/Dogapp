import SwiftUI

struct BreedPickerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @ObservedObject var vm: BreedSelectionViewModel
    @State private var searchText = ""

    var filteredBreeds: [String] {
        searchText.isEmpty
            ? vm.allBreeds
            : vm.allBreeds.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepDots(current: 3, total: 4)
                .padding(.vertical, AppTheme.Spacing.s)

            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search breeds…", text: $searchText)
                    .font(AppTheme.Font.body())
            }
            .padding(AppTheme.Spacing.m)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(AppTheme.Radius.m)
            .padding(AppTheme.Spacing.m)

            if vm.isLoading {
                LoadingView(message: "Loading breeds…")
            } else {
                List(filteredBreeds, id: \.self) { breed in
                    Button(action: { vm.selectedBreedName = breed }) {
                        HStack {
                            Text(breed)
                                .font(AppTheme.Font.body())
                                .foregroundColor(.primary)
                            Spacer()
                            if vm.selectedBreedName == breed {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.primaryFallback)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            if !vm.selectedBreedName.isEmpty {
                PrimaryButton(title: "Continue with \(vm.selectedBreedName)") {
                    appState.selectedBreed = BreedRecommendation(
                        id: UUID().uuidString,
                        name: vm.selectedBreedName,
                        breedDescription: "",
                        reason: "",
                        imageName: nil
                    )
                    router.navigateOnboarding(to: .planGeneration)
                }
                .padding(AppTheme.Spacing.m)
                .background(Color(UIColor.systemBackground))
            }
        }
        .navigationTitle("Choose a Breed")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.fetchAllBreeds() }
    }
}

#Preview {
    BreedPickerView(vm: {
        let vm = BreedSelectionViewModel()
        vm.allBreeds = MockData.allBreedNames
        return vm
    }())
    .environmentObject(AppState())
    .environmentObject(AppRouter())
}
