import SwiftUI

struct ClarificationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter
    @StateObject private var vm: TaskViewModel
    let task: TrainingTask

    init(task: TrainingTask, result: TaskFeedback.FeedbackResult) {
        self.task = task
        self._vm = StateObject(wrappedValue: TaskViewModel(taskId: task.id, result: result))
    }

    var questions: [ClarificationQuestion] {
        vm.questions(for: task)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                VStack(spacing: AppTheme.Spacing.s) {
                    Text("🤔")
                        .font(.system(size: 44))
                    Text("Let's understand what happened")
                        .font(AppTheme.Font.headline())
                        .multilineTextAlignment(.center)
                    Text("Answer a few quick questions so your AI trainer can help.")
                        .font(AppTheme.Font.body())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.Spacing.m)
                .padding(.horizontal, AppTheme.Spacing.l)

                ForEach(questions) { question in
                    QuestionCard(
                        question: question,
                        answer: Binding(
                            get: { vm.clarificationAnswers[question.id] ?? "" },
                            set: { vm.clarificationAnswers[question.id] = $0 }
                        )
                    )
                    .padding(.horizontal, AppTheme.Spacing.l)
                }

                if vm.isLoading {
                    ProgressView().padding()
                } else {
                    PrimaryButton(title: "Get AI Advice", action: {
                        Task {
                            await vm.submitClarificationAndGetAdjustment(
                                task: task,
                                dogProfile: appState.dogProfile
                            )
                        }
                    }, isDisabled: !canSubmit)
                    .padding(.horizontal, AppTheme.Spacing.l)
                }

                if let error = vm.errorMessage {
                    ErrorBanner(message: error).padding(AppTheme.Spacing.l)
                }

                Spacer(minLength: AppTheme.Spacing.xl)
            }
        }
        .navigationTitle("What Happened?")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.adjustment) { _, adj in
            if let adj {
                router.navigateToday(to: .aiAdjustment(adj))
            }
        }
    }

    private var canSubmit: Bool {
        questions
            .filter { $0.type == .singleChoice }
            .allSatisfy { !(vm.clarificationAnswers[$0.id] ?? "").isEmpty }
    }
}

struct QuestionCard: View {
    let question: ClarificationQuestion
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            Text(question.question)
                .font(AppTheme.Font.title(15))

            switch question.type {
            case .singleChoice:
                VStack(spacing: AppTheme.Spacing.s) {
                    ForEach(question.options, id: \.self) { option in
                        Button(action: { answer = option }) {
                            HStack {
                                Text(option)
                                    .font(AppTheme.Font.body())
                                    .foregroundColor(answer == option ? AppTheme.primaryFallback : .primary)
                                Spacer()
                                if answer == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.primaryFallback)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(AppTheme.Spacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.s)
                                    .fill(answer == option
                                          ? AppTheme.primaryFallback.opacity(0.08)
                                          : Color(UIColor.tertiarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

            case .freeText:
                TextField("Describe what happened…", text: $answer, axis: .vertical)
                    .font(AppTheme.Font.body())
                    .lineLimit(4...6)
                    .padding(AppTheme.Spacing.m)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(AppTheme.Radius.s)
            }
        }
        .padding(AppTheme.Spacing.m)
        .cardStyle()
    }
}

#Preview {
    ClarificationView(task: MockData.puppyPlan.tasks[0], result: .partial)
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
