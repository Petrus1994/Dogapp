import SwiftUI

struct ProgressBarView: View {
    var progress: Double   // 0.0 – 1.0
    var height: CGFloat = 8
    var color: Color = AppTheme.primaryFallback
    var backgroundColor: Color = Color.gray.opacity(0.2)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(backgroundColor)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(1, max(0, progress))), height: height)
                    .animation(.spring(response: 0.5), value: progress)
            }
        }
        .frame(height: height)
    }
}

struct DailyProgressView: View {
    let completed: Int
    let partial: Int
    let failed: Int
    let total: Int

    var completedFraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    var partialFraction: Double   { total > 0 ? Double(partial) / Double(total) : 0 }
    var failedFraction: Double    { total > 0 ? Double(failed) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                Text("Today's Progress")
                    .font(AppTheme.Font.title(15))
                Spacer()
                Text("\(completed)/\(total)")
                    .font(AppTheme.Font.caption())
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    if completed > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green)
                            .frame(width: geo.size.width * completedFraction)
                    }
                    if partial > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: geo.size.width * partialFraction)
                    }
                    if failed > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red)
                            .frame(width: geo.size.width * failedFraction)
                    }
                    Spacer()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                }
                .frame(height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .animation(.spring(response: 0.5), value: completed)
            }
            .frame(height: 10)

            HStack(spacing: AppTheme.Spacing.m) {
                legendDot(color: .green, label: "Done")
                legendDot(color: .orange, label: "Partial")
                legendDot(color: .red, label: "Failed")
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(AppTheme.Font.caption()).foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ProgressBarView(progress: 0.65)
        DailyProgressView(completed: 2, partial: 1, failed: 0, total: 5)
    }
    .padding()
}
