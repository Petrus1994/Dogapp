import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ChatViewModel()
    @State private var showSuggestions = true

    var chatContext: ChatContext {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentEvents = appState.allBehaviorEvents.filter { $0.date >= cutoff }
        return ChatContext(
            dogProfile:          appState.dogProfile,
            plan:                appState.currentPlan,
            scenarioType:        appState.currentUser?.scenarioType,
            recentFeedback:      appState.recentFeedback,
            behaviorProgress:    appState.behaviorProgress,
            todayActivities:     appState.todayActivities,
            recentBehaviorEvents: recentEvents
        )
    }

    var suggestedPrompts: [String] {
        guard appState.dogProfile != nil else {
            return [
                "What should I prepare before bringing a dog home?",
                "How do I choose the right breed for my lifestyle?",
                "What supplies do I need for a new puppy?"
            ]
        }
        var prompts: [String] = []
        if let issues = appState.dogProfile?.issues, !issues.isEmpty {
            let issue = issues.first!
            prompts.append("How do I work on \(issue.displayName.lowercased())?")
        }
        if let focus = appState.currentPlan?.weeklyFocus {
            prompts.append("Tips for this week's focus: \(focus)")
        }
        if let name = appState.dogProfile?.name {
            prompts.append("Why does \(name) get distracted during training?")
        }
        let fallbacks = MockData.suggestedChatPrompts
        while prompts.count < 3, !fallbacks.isEmpty {
            let candidate = fallbacks[prompts.count % fallbacks.count]
            if !prompts.contains(candidate) { prompts.append(candidate) }
            else { break }
        }
        return Array(prompts.prefix(3))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.s) {
                            if showSuggestions && vm.messages.count <= 1 {
                                SuggestedPromptsView(prompts: suggestedPrompts) { prompt in
                                    vm.useSuggestion(prompt)
                                    showSuggestions = false
                                    Task { await vm.sendMessage(context: chatContext) }
                                }
                                .padding(.top, AppTheme.Spacing.m)
                            }

                            ForEach(vm.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if vm.chatState == .failed, let error = vm.errorMessage {
                                ErrorRetryBubble(message: error) {
                                    Task { await vm.retry(context: chatContext) }
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.m)
                    }
                    .onChange(of: vm.messages.last?.id) { _, _ in
                        withAnimation {
                            proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Input bar
                ChatInputBar(
                    text: $vm.inputText,
                    isSending: vm.chatState == .sending,
                    canSend: vm.canSend
                ) {
                    Task { await vm.sendMessage(context: chatContext) }
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.s) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                Text("🐾")
                    .font(.system(size: 18))
                    .frame(width: 28, height: 28)
            }

            Group {
                if message.isLoading {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 6, height: 6)
                                .animation(
                                    .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                                    value: true
                                )
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.m)
                    .padding(.vertical, AppTheme.Spacing.s + 4)
                } else {
                    Text(message.content)
                        .font(AppTheme.Font.body(15))
                        .foregroundColor(isUser ? .white : .primary)
                        .lineSpacing(4)
                        .padding(.horizontal, AppTheme.Spacing.m)
                        .padding(.vertical, AppTheme.Spacing.s + 4)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isUser ? AppTheme.primaryFallback : Color(UIColor.secondarySystemBackground))
            )

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Suggested Prompts

struct SuggestedPromptsView: View {
    let prompts: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Suggested questions")
                .font(AppTheme.Font.caption())
                .foregroundColor(.secondary)
                .padding(.horizontal, AppTheme.Spacing.xs)

            ForEach(prompts, id: \.self) { prompt in
                Button(action: { onSelect(prompt) }) {
                    Text(prompt)
                        .font(AppTheme.Font.body(14))
                        .foregroundColor(AppTheme.primaryFallback)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, AppTheme.Spacing.m)
                        .padding(.vertical, AppTheme.Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                                .stroke(AppTheme.primaryFallback.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            TextField("Ask your trainer…", text: $text, axis: .vertical)
                .font(AppTheme.Font.body())
                .lineLimit(1...5)
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.vertical, AppTheme.Spacing.s + 2)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(22)

            Button(action: onSend) {
                Group {
                    if isSending {
                        ProgressView().tint(.white).scaleEffect(0.9)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(canSend ? AppTheme.primaryFallback : Color.gray.opacity(0.3))
                )
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s)
    }
}

// MARK: - Error Retry

struct ErrorRetryBubble: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Text(message)
                .font(AppTheme.Font.caption())
                .foregroundColor(.red)
            Button("Retry", action: onRetry)
                .font(AppTheme.Font.caption())
                .foregroundColor(AppTheme.primaryFallback)
        }
        .padding(AppTheme.Spacing.s)
    }
}

#Preview {
    ChatView()
        .environmentObject(AppState())
}
