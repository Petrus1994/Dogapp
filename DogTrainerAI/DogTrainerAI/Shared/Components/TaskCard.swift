import SwiftUI

struct TaskCard: View {
    let task: TrainingTask
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: AppTheme.Spacing.m) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(task.category.icon)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(AppTheme.Font.title(15))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if task.status == .failed {
                        Text("Failed — tap to retry")
                            .font(AppTheme.Font.caption())
                            .foregroundColor(.red)
                    } else {
                        Text(task.category.displayName)
                            .font(AppTheme.Font.caption())
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                statusIcon
            }
            .padding(AppTheme.Spacing.m)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch task.status {
        case .pending:   return AppTheme.primaryFallback
        case .completed: return .green
        case .partial:   return .orange
        case .failed:    return .red
        }
    }

    private var statusIcon: some View {
        Group {
            switch task.status {
            case .pending:
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .partial:
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.orange)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TaskCard(task: MockData.puppyPlan.tasks[0])
        TaskCard(task: MockData.puppyPlan.tasks[3])
    }
    .padding()
}
