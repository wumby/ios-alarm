import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var scheduler: AlarmSchedulingService
    @Query(sort: \AlarmItem.timeMinutes) private var alarms: [AlarmItem]
    @StateObject private var streakStore = StreakStore.shared

    @State private var showingNewAlarm = false
    @State private var editingAlarm: AlarmItem?
    @State private var expandedHours: Set<Int> = []
    @State private var alarmFilter: AlarmFilter = .all
    @State private var scrollTargetAlarmID: UUID?
    @State private var streakPulse = false
    @State private var isEditingAlarms = false
    @State private var selectedAlarmIDs: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    var body: some View {
        TabView {
            homeView
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(AppTheme.accent)
        .toolbarBackground(AppTheme.cream, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    private var homeView: some View {
        NavigationStack {
            ZStack {
                AppTheme.sunriseBackground

                VStack(spacing: 0) {
                    DashboardHeader(
                        activeCount: alarms.filter(\.isEnabled).count,
                        filter: $alarmFilter,
                        onAdd: { showingNewAlarm = true },
                        isEditing: isEditingAlarms,
                        hasSelection: !selectedAlarmIDs.isEmpty,
                        onToggleEditing: {
                            isEditingAlarms.toggle()
                            if isEditingAlarms {
                                alarmFilter = .all
                            }
                            selectedAlarmIDs.removeAll()
                        },
                        onDeleteSelected: { showingDeleteConfirmation = true }
                    )

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 24) {
                            if !isEditingAlarms {
                                StreakHistoryView(streakStore: streakStore)
                                    .padding(.horizontal, 24)
                                    .scaleEffect(streakPulse ? 1.03 : 1)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.65), value: streakPulse)

                                if let nextAlarm {
                                    NextChallengeView(
                                        alarm: nextAlarm,
                                        fireDate: nextFireDate(for: nextAlarm),
                                        title: alarmFilter == .favorites ? "Next favorite alarm" : "Next alarm"
                                    ) {
                                        expandedHours.insert(nextAlarm.hour)
                                        scrollToAlarm(nextAlarm.id, hour: nextAlarm.hour, using: proxy)
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }

                            if alarms.isEmpty {
                                EmptyChallengeView {
                                    showingNewAlarm = true
                                }
                                .padding(.horizontal, 24)
                            } else if filteredAlarms.isEmpty {
                                EmptyFavoritesView()
                                    .padding(.horizontal, 24)
                            } else if isEditingAlarms {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 16, alignment: .top),
                                        GridItem(.flexible(), spacing: 16, alignment: .top)
                                    ],
                                    spacing: 16
                                ) {
                                    ForEach(filteredAlarms) { alarm in
                                        AlarmSelectionCard(
                                            alarm: alarm,
                                            isSelected: selectedAlarmIDs.contains(alarm.id),
                                            onToggle: { toggleSelection(alarm) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                            } else {
                                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
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
                                            onDelete: delete,
                                            isEditing: isEditingAlarms,
                                            selectedAlarmIDs: selectedAlarmIDs,
                                            onToggleSelection: toggleSelection
                                        )
                                        .id("alarm-hour-\(section.hour)")
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                            }
                            }
                            .padding(.top, 24)
                            .padding(.bottom, 24)
                        }
                        .onChange(of: scrollTargetAlarmID) { _, targetID in
                            guard let targetID else { return }
                            scrollToAlarm(targetID, using: proxy)
                        }
                        .onChange(of: alarms.count) { _, _ in
                            guard let targetID = scrollTargetAlarmID,
                                  let alarm = alarms.first(where: { $0.id == targetID }) else { return }
                            scrollToAlarm(targetID, hour: alarm.hour, using: proxy)
                            scrollTargetAlarmID = nil
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                streakStore.refresh()
                if expandedHours.isEmpty, let firstHour = hourSections.first?.hour {
                    expandedHours = [firstHour]
                }
            }
            .onChange(of: streakStore.currentStreak) { _, _ in
                streakPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    streakPulse = false
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
            .alert("Delete alarms?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteSelected)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(selectedAlarmIDs.count) alarms?")
            }
        }
        .sheet(isPresented: $showingNewAlarm) {
            AlarmFormView(mode: .create) { alarm in
                alarmFilter = .all
                expandedHours.insert(alarm.hour)
                scrollTargetAlarmID = alarm.id
            }
        }
        .sheet(item: $editingAlarm) { alarm in
            AlarmFormView(mode: .edit(alarm))
        }
    }

    private func delete(_ alarm: AlarmItem) {
        scheduler.cancel(alarm: alarm)
        modelContext.delete(alarm)
        try? modelContext.save()
    }

    private func toggleSelection(_ alarm: AlarmItem) {
        if selectedAlarmIDs.contains(alarm.id) {
            selectedAlarmIDs.remove(alarm.id)
        } else {
            selectedAlarmIDs.insert(alarm.id)
        }
    }

    private func deleteSelected() {
        for alarm in alarms where selectedAlarmIDs.contains(alarm.id) {
            scheduler.cancel(alarm: alarm)
            modelContext.delete(alarm)
        }
        try? modelContext.save()
        selectedAlarmIDs.removeAll()
        isEditingAlarms = false
    }

    private func scrollToAlarm(_ id: UUID, hour: Int? = nil, using proxy: ScrollViewProxy) {
        for delay in [0.1, 0.35, 0.7] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation {
                    if let hour {
                        proxy.scrollTo("alarm-hour-\(hour)", anchor: .top)
                    }
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var nextAlarm: AlarmItem? {
        filteredAlarms
            .filter(\.isEnabled)
            .min { lhs, rhs in
                minutesUntilFire(lhs) < minutesUntilFire(rhs)
            }
    }

    private var filteredAlarms: [AlarmItem] {
        switch alarmFilter {
        case .all:
            alarms
        case .favorites:
            alarms.filter { $0.isFavorite == true }
        }
    }

    private func minutesUntilFire(_ alarm: AlarmItem) -> Int {
        let now = AlarmItem.minutes(from: Date())
        let delta = alarm.timeMinutes - now
        return delta >= 0 ? delta : delta + 24 * 60
    }

    private func nextFireDate(for alarm: AlarmItem) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let weekday = RepeatDay(rawValue: calendar.component(.weekday, from: day)),
                  alarm.repeatDays.isEmpty || alarm.repeatDays.contains(weekday),
                  let candidate = calendar.date(
                    bySettingHour: alarm.hour,
                    minute: alarm.minute,
                    second: 0,
                    of: day
                  ) else {
                continue
            }

            if candidate >= now {
                return candidate
            }
        }

        return alarm.timeDate
    }

    private var hourSections: [AlarmHourSection] {
        Dictionary(grouping: filteredAlarms, by: \.hour)
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

private enum AlarmFilter: String, CaseIterable, Identifiable {
    case all
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All alarms"
        case .favorites: "Favorites"
        }
    }
}

private struct DashboardHeader: View {
    let activeCount: Int
    @Binding var filter: AlarmFilter
    let onAdd: () -> Void
    let isEditing: Bool
    let hasSelection: Bool
    let onToggleEditing: () -> Void
    let onDeleteSelected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditing {
                HStack {
                    Button("Cancel", action: onToggleEditing)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button(action: onDeleteSelected) {
                        Label("Delete", systemImage: "trash")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(hasSelection ? AppTheme.accent : AppTheme.textSecondary.opacity(0.45))
                    }
                    .disabled(!hasSelection)
                }
            } else {
                HStack {
                    filterSwitcher
                    Spacer()

                    Button(action: onToggleEditing) {
                        Image(systemName: "pencil")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.cardSurface, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit alarms")

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.cardSurface, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add alarm")
                }

                Text("\(activeCount) active alarms")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var filterSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(AlarmFilter.allCases) { option in
                Button {
                    filter = option
                } label: {
                    HStack(spacing: 6) {
                        if option == .favorites {
                            Image(systemName: "star.fill")
                                .font(.caption2.weight(.bold))
                        }

                        Text(option.title)
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(filter == option ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .frame(minWidth: 88, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                filter == option
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [
                                                AppTheme.skyBlue.opacity(0.55),
                                                AppTheme.peach.opacity(0.72),
                                                AppTheme.warmOrange.opacity(0.52)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    : AnyShapeStyle(Color.clear)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
    }
}

private struct StreakHistoryView: View {
    @ObservedObject var streakStore: StreakStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(streakText)
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                Image(systemName: streakStore.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(streakStore.currentStreak > 0 ? AppTheme.accent : AppTheme.textSecondary.opacity(0.30))
            }

            HStack(spacing: 6) {
                ForEach(streakStore.recentDays(), id: \.self) { day in
                    VStack(spacing: 7) {
                        Text(DateFormatter.streakDay.string(from: day))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)

                        Circle()
                            .fill(streakStore.isCompleted(day) ? AppTheme.accent : AppTheme.textSecondary.opacity(0.14))
                            .frame(width: 20, height: 20)
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
        .padding(18)
        .floatingCard()
    }

    private var streakText: String {
        let dayLabel = streakStore.currentStreak == 1 ? "day" : "days"
        return "Correct answer streak - \(streakStore.currentStreak) \(dayLabel)"
    }
}

private struct NextChallengeView: View {
    let alarm: AlarmItem
    let fireDate: Date
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "alarm.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.accent.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(DateFormatter.alarmDashboardDateTime.string(from: fireDate))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(alarm.label.isEmpty ? "Alarm" : alarm.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .floatingCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct AlarmHourSection: Identifiable {
    let hour: Int
    let alarms: [AlarmItem]

    var id: Int { hour }
}

private struct AlarmSelectionCard: View {
    let alarm: AlarmItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        ZStack {
            AlarmRowView(alarm: alarm, showsEnabledToggle: false, isFavoriteButtonInteractive: false)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .stroke(isSelected ? AppTheme.accent : .clear, lineWidth: 3)
                }

            SelectionRadioButton(isSelected: isSelected, action: onToggle)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityLabel(isSelected ? "Selected alarm" : "Select alarm")
        .accessibilityValue(alarm.label.isEmpty ? "Alarm" : alarm.label)
    }
}

private struct SelectionRadioButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(isSelected ? AppTheme.accent : AppTheme.cardSurface)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(isSelected ? AppTheme.accent : AppTheme.cardBorder, lineWidth: 1.5)

                    if isSelected {
                        Circle()
                            .fill(.white)
                            .frame(width: 10, height: 10)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Remove from deletion" : "Add to deletion")
    }
}

private struct AlarmHourSectionView: View {
    let section: AlarmHourSection
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onEdit: (AlarmItem) -> Void
    let onDelete: (AlarmItem) -> Void
    let isEditing: Bool
    let selectedAlarmIDs: Set<UUID>
    let onToggleSelection: (AlarmItem) -> Void

    var body: some View {
        Section {
            if isExpanded {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16, alignment: .top),
                        GridItem(.flexible(), spacing: 16, alignment: .top)
                    ],
                    spacing: 16
                ) {
                    ForEach(section.alarms) { alarm in
                        ZStack(alignment: .topTrailing) {
                            AlarmRowView(alarm: alarm)

                            if isEditing {
                                Image(systemName: selectedAlarmIDs.contains(alarm.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(selectedAlarmIDs.contains(alarm.id) ? AppTheme.accent : AppTheme.textSecondary.opacity(0.55))
                                    .padding(16)
                            }
                        }
                        .id(alarm.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditing {
                                onToggleSelection(alarm)
                            } else {
                                onEdit(alarm)
                            }
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
        } header: {
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
            return "All active"
        }
        if armed == 0 {
            return "All inactive"
        }
        return "\(armed) active · \(section.alarms.count - armed) inactive"
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

private struct EmptyFavoritesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.accent)

            Text("No favorite alarms yet.")
                .font(.title3.weight(.black))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Tap the star on an alarm to keep it here.")
                .font(.body)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .floatingCard()
    }
}

private extension DateFormatter {
    static let alarmDashboardTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    static let alarmDashboardDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d 'at' h:mm a"
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
