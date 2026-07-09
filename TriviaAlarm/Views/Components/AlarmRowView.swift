import SwiftUI

struct AlarmRowView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var scheduler: AlarmSchedulingService
    @Bindable var alarm: AlarmItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                statusMark

                Spacer()

                Toggle("Enabled", isOn: $alarm.isEnabled)
                    .labelsHidden()
                    .tint(AppTheme.accent)
                    .padding(6)
                    .frame(width: 64, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(alarm.isEnabled ? AppTheme.accent.opacity(0.16) : Color.white.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(alarm.isEnabled ? AppTheme.cardBorder : AppTheme.textSecondary.opacity(0.18), lineWidth: 1)
                    )
                    .onChange(of: alarm.isEnabled) { _, _ in
                        try? modelContext.save()
                        Task {
                            await scheduler.schedule(alarm: alarm)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(timeText)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(alarm.label.isEmpty ? "Wake challenge" : alarm.label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 7) {
                MetadataLine(systemName: "calendar", text: repeatText)
                MetadataLine(systemName: "speedometer", text: alarm.difficulty.rawValue)
                MetadataLine(systemName: "questionmark.circle", text: categorySummary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 162, alignment: .topLeading)
        .floatingCard()
    }

    private var statusMark: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(alarm.isEnabled ? AppTheme.accent : AppTheme.textSecondary.opacity(0.28))
                .frame(width: 8, height: 8)

            Text(alarm.isEnabled ? "Armed" : "Paused")
                .font(.caption2.weight(.black))
                .foregroundStyle(alarm.isEnabled ? AppTheme.accent : AppTheme.textSecondary)
                .textCase(.uppercase)
        }
    }

    private var timeText: String {
        DateFormatter.alarmTime.string(from: alarm.timeDate)
    }

    private var repeatText: String {
        let days = alarm.repeatDays.sorted { $0.rawValue < $1.rawValue }
        if days.isEmpty { return "Once" }
        if Set(days) == Set(RepeatDay.allCases) { return "Every day" }
        return days.map(\.shortName).joined(separator: " ")
    }

    private var categorySummary: String {
        let names = categoryNames
        if names.isEmpty { return "Mixed trivia" }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names[0]), \(names[1]) +\(names.count - 2)"
    }

    private var categoryNames: [String] {
        alarm.categoryIDs.compactMap { TriviaCategory(rawValue: $0)?.title }.sorted()
    }
}

private struct MetadataLine: View {
    let systemName: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }
}

private extension DateFormatter {
    static let alarmTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
