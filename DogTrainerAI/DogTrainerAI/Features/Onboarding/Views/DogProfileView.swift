import SwiftUI
import PhotosUI

struct DogProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @ObservedObject var vm: DogProfileViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {
                    OnboardingStepDots(current: 2, total: 3)
                        .padding(.top, AppTheme.Spacing.s)

                    PhotosPickerSection(photoItem: $vm.photoItem, selectedPhoto: vm.selectedPhoto) {
                        Task { await vm.loadPhoto() }
                    }

                    formSection("Basic Info") {
                        FloatingTextField("Dog's name", text: $vm.name)

                        SegmentedRow(label: "Gender", options: DogProfile.Gender.allCases, selected: $vm.gender) { $0.displayName }
                    }

                    formSection("Age") {
                        AgeInputSection(vm: vm)
                    }

                    formSection("Breed") {
                        Toggle("I don't know the breed / Mixed", isOn: $vm.isBreedUnknown)
                            .font(AppTheme.Font.body())
                            .padding(AppTheme.Spacing.m)

                        if !vm.isBreedUnknown {
                            FloatingTextField("Breed (e.g. Golden Retriever)", text: $vm.breed)
                        } else {
                            SegmentedRow(label: "Size", options: DogProfile.DogSize.allCases, selected: $vm.size) { $0.displayName }
                        }
                    }

                    formSection("Coat Color") {
                        CoatColorPickerView(selected: $vm.coatColor)
                    }

                    formSection("Current Issues (select all that apply)") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.s) {
                            ForEach(DogProfile.DogIssue.allCases, id: \.self) { issue in
                                IssueToggleChip(
                                    issue: issue,
                                    isSelected: vm.selectedIssues.contains(issue)
                                ) {
                                    vm.toggleIssue(issue)
                                }
                            }
                        }
                    }

                    if let error = vm.validationError {
                        ErrorBanner(message: error)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: AppTheme.Spacing.xl)
                }
                .padding(.top, AppTheme.Spacing.m)
            }

            // Sticky Continue button — always visible
            VStack(spacing: 0) {
                Divider()
                PrimaryButton(title: "Continue") {
                    if let profile = vm.buildProfile() {
                        appState.dogProfile = profile
                        router.navigateOnboarding(to: .planGeneration)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.vertical, AppTheme.Spacing.m)
            }
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("Dog Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.name)  { vm.validationError = nil }
        .onChange(of: vm.breed) { vm.validationError = nil }
    }

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text(title)
                .font(AppTheme.Font.title(15))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            VStack(spacing: AppTheme.Spacing.s) {
                content()
            }
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }
}

// MARK: - Sub-components

// MARK: - Age Input Section

struct AgeInputSection: View {
    @ObservedObject var vm: DogProfileViewModel

    var body: some View {
        VStack(spacing: AppTheme.Spacing.m) {

            // Mode toggle
            HStack(spacing: 0) {
                modeButton("Approximate", mode: .approximate)
                modeButton("Exact date", mode: .exactDate)
            }
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(AppTheme.Radius.s)

            // Input
            if vm.ageInputMode == .exactDate {
                exactDateInput
            } else {
                approximateInput
            }

            // Summary label
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 13))
                Text(vm.ageSummaryLabel)
                    .font(AppTheme.Font.caption(13))
                    .foregroundColor(.secondary)
            }
        }
    }

    // Mode toggle button
    private func modeButton(_ label: String, mode: AgeInputMode) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { vm.ageInputMode = mode } } label: {
            Text(label)
                .font(AppTheme.Font.body(14))
                .fontWeight(vm.ageInputMode == mode ? .semibold : .regular)
                .foregroundColor(vm.ageInputMode == mode ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.s)
                .background(
                    vm.ageInputMode == mode
                        ? AppTheme.primaryFallback
                        : Color.clear
                )
                .cornerRadius(AppTheme.Radius.s)
        }
        .buttonStyle(.plain)
    }

    // Exact date picker
    private var exactDateInput: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            DatePicker(
                "Date of birth",
                selection: $vm.birthDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .tint(AppTheme.primaryFallback)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTheme.Spacing.m)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(AppTheme.Radius.s)
        .transition(.opacity)
    }

    // Approximate: year + month wheel pickers
    private var approximateInput: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Years")
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                    Picker("Years", selection: $vm.approximateYears) {
                        ForEach(0...20, id: \.self) { y in
                            Text("\(y)").tag(y)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                VStack(spacing: 4) {
                    Text("Months")
                        .font(AppTheme.Font.caption(12))
                        .foregroundColor(.secondary)
                    Picker("Months", selection: $vm.approximateMonths) {
                        ForEach(0...11, id: \.self) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
            }
            .frame(height: 120)
            .padding(AppTheme.Spacing.m)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(AppTheme.Radius.s)

            if vm.approximateYears == 0 && vm.approximateMonths == 0 {
                Text("Set at least 1 month to continue")
                    .font(AppTheme.Font.caption(12))
                    .foregroundColor(.orange)
            }
        }
        .transition(.opacity)
    }
}

struct PhotosPickerSection: View {
    @Binding var photoItem: PhotosPickerItem?
    var selectedPhoto: UIImage?
    let onPhotoSelected: () -> Void

    var body: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(width: 96, height: 96)
                if let photo = selectedPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.primaryFallback)
                        Text("Add photo")
                            .font(AppTheme.Font.caption(11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onChange(of: photoItem) { _, _ in onPhotoSelected() }
    }
}

struct FloatingTextField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .font(AppTheme.Font.body())
            .padding(AppTheme.Spacing.m)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(AppTheme.Radius.s)
    }
}

struct SegmentedRow<T: Hashable>: View {
    let label: String
    let options: [T]
    @Binding var selected: T
    let displayName: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(label)
                .font(AppTheme.Font.caption())
                .foregroundColor(.secondary)
            HStack(spacing: AppTheme.Spacing.s) {
                ForEach(options, id: \.self) { option in
                    Button(action: { selected = option }) {
                        Text(displayName(option))
                            .font(AppTheme.Font.body(14))
                            .foregroundColor(selected == option ? .white : .primary)
                            .padding(.horizontal, AppTheme.Spacing.m)
                            .padding(.vertical, AppTheme.Spacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                    .fill(selected == option ? AppTheme.primaryFallback : Color(UIColor.tertiarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CoatColorPickerView: View {
    @Binding var selected: CoatColor

    private let columns = [GridItem(.adaptive(minimum: 56))]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("This colors your dog's avatar")
                .font(AppTheme.Font.caption(12))
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.l)

            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.s) {
                ForEach(CoatColor.allCases) { color in
                    Button {
                        selected = color
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(color.primary)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selected == color ? AppTheme.primaryFallback : Color.clear,
                                                lineWidth: 2.5
                                            )
                                            .padding(-3)
                                    )
                                if selected == color {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(color.needsDarkLabel ? .black.opacity(0.6) : .white)
                                }
                            }
                            Text(color.displayName)
                                .font(AppTheme.Font.caption(10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.l)
        }
    }
}

struct IssueToggleChip: View {
    let issue: DogProfile.DogIssue
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Text(issue.icon).font(.system(size: 14))
                Text(issue.displayName)
                    .font(AppTheme.Font.caption(13))
                    .lineLimit(1)
            }
            .padding(.horizontal, AppTheme.Spacing.s)
            .padding(.vertical, AppTheme.Spacing.s)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                    .fill(isSelected ? AppTheme.primaryFallback.opacity(0.15) : Color(UIColor.tertiarySystemBackground))
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

#Preview {
    DogProfileView(vm: DogProfileViewModel())
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
