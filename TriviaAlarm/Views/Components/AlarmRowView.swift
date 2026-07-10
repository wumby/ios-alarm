import SwiftUI

struct AlarmRowView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var scheduler: AlarmSchedulingService
    @Bindable var alarm: AlarmItem
    var showsEnabledToggle = true
    var showsFavoriteButton = true
    var isFavoriteButtonInteractive = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                if showsFavoriteButton {
                    if isFavoriteButtonInteractive {
                        Button {
                            alarm.isFavorite = !(alarm.isFavorite == true)
                            try? modelContext.save()
                        } label: {
                            favoriteIcon
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(alarm.isFavorite == true ? "Remove favorite" : "Add favorite")
                    } else {
                        favoriteIcon
                    }
                }

                Spacer()

                if showsEnabledToggle {
                    ThemeToggle(isOn: $alarm.isEnabled)
                        .onChange(of: alarm.isEnabled) { _, _ in
                            try? modelContext.save()
                            Task {
                                await scheduler.schedule(alarm: alarm)
                            }
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
                MetadataLine(systemName: alarm.triviaEnabled ? "questionmark.circle" : "bell.slash", text: categorySummary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 162, alignment: .topLeading)
        .floatingCard()
    }

    private var favoriteIcon: some View {
        Image(systemName: alarm.isFavorite == true ? "star.fill" : "star")
            .font(.title3.weight(.bold))
            .foregroundStyle(alarm.isFavorite == true ? AppTheme.accent : AppTheme.textSecondary)
            .frame(width: 38, height: 38)
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
        guard alarm.triviaEnabled else { return "Trivia off" }
        let names = categoryNames
        if names.isEmpty { return "Mixed trivia" }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names[0]), \(names[1]) +\(names.count - 2)"
    }

    private var categoryNames: [String] {
        alarm.categoryIDs.compactMap { TriviaCategory(rawValue: $0)?.title }.sorted()
    }
}

private struct ThemeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(
                    isOn
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [AppTheme.skyBlue, AppTheme.peach, AppTheme.warmOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(AppTheme.cardSurface)
                )
                .frame(width: 62, height: 34)
                .overlay {
                    Capsule()
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                }
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? AppTheme.accent : AppTheme.textSecondary.opacity(0.48))
                        .frame(width: 26, height: 26)
                        .padding(4)
                        .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Alarm enabled")
        .accessibilityValue(isOn ? "On" : "Off")
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
