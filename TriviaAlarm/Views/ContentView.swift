import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var scheduler: AlarmSchedulingService
    @Query(sort: \AlarmItem.timeMinutes) private var alarms: [AlarmItem]
    @StateObject private var streakStore = StreakStore.shared

    @State private var showingNewAlarm = false
    @State private var editingAlarm: AlarmItem?
    @State private var showingSettings = false
    @State private var expandedHours: Set<Int> = []

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        DashboardHeader(
                            activeCount: alarms.filter(\.isEnabled).count,
                            currentStreak: streakStore.currentStreak,
                            onSettings: { showingSettings = true }
                        )

                        StreakHistoryView(streakStore: streakStore)
                            .padding(.horizontal, 24)

                        if let nextAlarm {
                            NextChallengeView(alarm: nextAlarm)
                                .padding(.horizontal, 24)
                        }

                        if alarms.isEmpty {
                            EmptyChallengeView {
                                showingNewAlarm = true
                            }
                            .padding(.horizontal, 24)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(hourSections) { section in
                                AlarmHourSectionView(
                                    section: section,
                                    isExpanded: expandedHours.contains(section.hour),
                                    onToggleExpanded: {
                                        toggleSection(section.hour)
                                    },
                                    onEdit: { alarm in
                                        editingAlarm = alarm
                                    },
                                    onDelete: delete
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 92)
                }
                .background(AppTheme.sunriseBackground)

                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Spacer()

                        Button {
                            showingNewAlarm = true
                        } label: {
                            Label("Add alarm", systemImage: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(.horizontal, 18)
                                .frame(minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .floatingCard()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                streakStore.refresh()
                if expandedHours.isEmpty, let firstHour = hourSections.first?.hour {
                    expandedHours = [firstHour]
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let message = scheduler.authorizationMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.78))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)
                }
            }
        }
        .sheet(isPresented: $showingNewAlarm) {
            AlarmFormView(mode: .create)
        }
        .sheet(item: $editingAlarm) { alarm in
            AlarmFormView(mode: .edit(alarm))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private func delete(_ alarm: AlarmItem) {
        scheduler.cancel(alarm: alarm)
        modelContext.delete(alarm)
        try? modelContext.save()
    }

    private var nextAlarm: AlarmItem? {
        alarms
            .filter(\.isEnabled)
            .min { lhs, rhs in
                minutesUntilFire(lhs) < minutesUntilFire(rhs)
            }
    }

    private func minutesUntilFire(_ alarm: AlarmItem) -> Int {
        let now = AlarmItem.minutes(from: Date())
        let delta = alarm.timeMinutes - now
        return delta >= 0 ? delta : delta + 24 * 60
    }

    private var hourSections: [AlarmHourSection] {
        Dictionary(grouping: alarms, by: \.hour)
            .sorted { $0.key < $1.key }
            .map { key, groupedAlarms in
                AlarmHourSection(
                    hour: key,
                    alarms: groupedAlarms.sorted { $0.timeMinutes < $1.timeMinutes }
                )
            }
    }

    private func toggleSection(_ hour: Int) {
        if expandedHours.contains(hour) {
            expandedHours.remove(hour)
        } else {
            expandedHours.insert(hour)
        }
    }
}

    private struct DashboardHeader: View {
    let activeCount: Int
    let currentStreak: Int
    let onSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Alarm: Trivia")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("\(activeCount) armed · \(currentStreak) day streak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 10) {
                FloatingIconButton(systemName: "gearshape", label: "Settings", action: onSettings)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
}

private struct StreakHistoryView: View {
    @ObservedObject var streakStore: StreakStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current streak")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(streakTitle)
                        .font(.title2.weight(.black))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                Image(systemName: streakStore.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(streakStore.currentStreak > 0 ? AppTheme.accent : AppTheme.textSecondary.opacity(0.30))
            }

            HStack(spacing: 8) {
                ForEach(streakStore.recentDays(), id: \.self) { day in
                    VStack(spacing: 7) {
                        Text(DateFormatter.streakDay.string(from: day))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)

                        Circle()
                            .fill(streakStore.isCompleted(day) ? AppTheme.accent : AppTheme.textSecondary.opacity(0.14))
                            .frame(width: 22, height: 22)
                            .overlay {
                                if streakStore.isCompleted(day) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .floatingCard()
    }

    private var streakTitle: String {
        switch streakStore.currentStreak {
        case 0: "No active streak"
        case 1: "1 day"
        default: "\(streakStore.currentStreak) days"
        }
    }
}

private struct NextChallengeView: View {
    let alarm: AlarmItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 48, height: 48)
                .background(AppTheme.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Next challenge")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("\(DateFormatter.alarmDashboardTime.string(from: alarm.timeDate)) · \(alarm.label.isEmpty ? "Alarm" : alarm.label)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(24)
        .floatingCard()
    }
}

private struct AlarmHourSection: Identifiable {
    let hour: Int
    let alarms: [AlarmItem]

    var id: Int { hour }
}

private struct AlarmHourSectionView: View {
    let section: AlarmHourSection
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onEdit: (AlarmItem) -> Void
    let onDelete: (AlarmItem) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onToggleExpanded) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hourLabel)
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(summaryText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Text("\(section.alarms.count)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.14), in: Capsule())

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .floatingCard()
            }
            .buttonStyle(.plain)

            if isExpanded {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16, alignment: .top),
                        GridItem(.flexible(), spacing: 16, alignment: .top)
                    ],
                    spacing: 16
                ) {
                    ForEach(section.alarms) { alarm in
                        AlarmRowView(alarm: alarm)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEdit(alarm)
                            }
                            .contextMenu {
                                Button {
                                    onEdit(alarm)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    onDelete(alarm)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    private var hourLabel: String {
        let hourValue = section.hour % 24
        let date = Calendar.current.date(bySettingHour: hourValue, minute: 0, second: 0, of: Date()) ?? Date()
        return DateFormatter.hourBucket.string(from: date)
    }

    private var summaryText: String {
        let armed = section.alarms.filter(\.isEnabled).count
        if armed == section.alarms.count {
            return "All armed"
        }
        if armed == 0 {
            return "All paused"
        }
        return "\(armed) armed · \(section.alarms.count - armed) paused"
    }
}

private struct EmptyChallengeView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 8) {
                Text("Build your first wake-up challenge.")
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Pick a time, choose trivia categories, and make the morning prove you are awake.")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onAdd) {
                Label("Add Alarm", systemImage: "plus")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .floatingCard()
    }
}

private struct FloatingIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .padding(12)
        .floatingCard()
    }
}

private extension DateFormatter {
    static let alarmDashboardTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    static let hourBucket: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter
    }()

    static let streakDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
}
