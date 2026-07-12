import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultAlarmLabel") private var defaultAlarmLabel = ""
    @AppStorage("defaultAlarmRepeatMode") private var defaultAlarmRepeatMode = DefaultRepeatMode.once.rawValue
    @AppStorage("defaultAlarmRepeatDays") private var defaultAlarmRepeatDays = ""
    @AppStorage("defaultTriviaEnabled") private var defaultTriviaEnabled = true
    @AppStorage("defaultTriviaCategoryIDs") private var defaultCategoryIDs = TriviaCategory.defaultEnabled.map(\.id).joined(separator: ",")
    @AppStorage("defaultAlarmSound") private var defaultAlarmSound = AlarmSoundChoice.systemDefault.rawValue
    @AppStorage("defaultTriviaDifficulty") private var defaultTriviaDifficulty = TriviaDifficulty.mixed.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.sunriseBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("New Alarm Defaults")
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Alarm")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.textPrimary)

                            TextField("Label", text: $defaultAlarmLabel)
                                .textInputAutocapitalization(.words)
                                .padding(14)
                                .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                }

                            DefaultMenu(
                                title: "Repeat",
                                value: DefaultRepeatMode(rawValue: defaultAlarmRepeatMode)?.title ?? DefaultRepeatMode.once.title,
                                systemName: "arrow.clockwise",
                                options: DefaultRepeatMode.allCases.map(\.rawValue),
                                displayValues: DefaultRepeatMode.allCases.map(\.title),
                                selection: $defaultAlarmRepeatMode
                            )

                            if defaultAlarmRepeatMode == DefaultRepeatMode.custom.rawValue {
                                DayPicker(selectedDays: repeatDaysBinding)
                                    .padding(.horizontal, 4)
                            }

                        }
                        .padding(18)
                        .floatingCard()

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Trivia")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.textPrimary)

                            Toggle("Trivia challenge on", isOn: $defaultTriviaEnabled)
                                .tint(AppTheme.accent)

                            DefaultMenu(
                                title: "Difficulty",
                                value: defaultTriviaDifficulty,
                                systemName: "gauge.with.dots.needle.67percent",
                                options: TriviaDifficulty.allCases.map(\.rawValue),
                                selection: $defaultTriviaDifficulty
                            )

                            Text("Categories")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.textSecondary)

                            VStack(spacing: 0) {
                                ForEach(TriviaCategory.allCases) { category in
                                    Toggle(category.title, isOn: binding(for: category))
                                        .tint(AppTheme.accent)
                                        .padding(.vertical, 10)
                                        .disabled(!defaultTriviaEnabled)

                                    if category != TriviaCategory.allCases.last {
                                        Divider().opacity(0.35)
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .floatingCard()

                        VStack(alignment: .leading, spacing: 0) {
                            DefaultMenu(
                                title: "Sound",
                                value: AlarmSoundChoice(rawValue: defaultAlarmSound)?.title ?? AlarmSoundChoice.systemDefault.title,
                                systemName: "speaker.wave.2.fill",
                                options: AlarmSoundChoice.allCases.map(\.rawValue),
                                displayValues: AlarmSoundChoice.allCases.map(\.title),
                                selection: $defaultAlarmSound
                            )
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                        }
                        .floatingCard()

                        Text("These defaults apply only to new alarms. Existing alarms keep their own settings.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 4)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationBackground(.clear)
        .preferredColorScheme(.light)
    }

    private var selectedIDs: Set<String> {
        get {
            let ids = defaultCategoryIDs.split(separator: ",").map(String.init)
            return ids.isEmpty ? Set(TriviaCategory.defaultEnabled.map(\.id)) : Set(ids)
        }
        nonmutating set {
            defaultCategoryIDs = newValue.sorted().joined(separator: ",")
        }
    }

    private var repeatDaysBinding: Binding<Set<RepeatDay>> {
        Binding(
            get: {
                Set(defaultAlarmRepeatDays.split(separator: ",").compactMap { RepeatDay(rawValue: Int($0) ?? -1) })
            },
            set: { days in
                defaultAlarmRepeatDays = days.map { String($0.rawValue) }.sorted().joined(separator: ",")
            }
        )
    }

    private func binding(for category: TriviaCategory) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(category.id) },
            set: { isSelected in
                var ids = selectedIDs
                if isSelected {
                    ids.insert(category.id)
                } else {
                    ids.remove(category.id)
                }
                if !ids.isEmpty {
                    selectedIDs = ids
                }
            }
        )
    }
}

enum DefaultRepeatMode: String, CaseIterable, Identifiable {
    case once
    case everyDay
    case weekdays
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .once: "Once"
        case .everyDay: "Every day"
        case .weekdays: "Weekdays"
        case .custom: "Custom"
        }
    }
}

private struct DefaultMenu: View {
    let title: String
    let value: String
    let systemName: String
    let options: [String]
    var displayValues: [String] = []
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                Button {
                    selection = option
                } label: {
                    Label(displayValues.indices.contains(index) ? displayValues[index] : option,
                          systemImage: selection == option ? "checkmark" : "")
                }
            }
        } label: {
            HStack {
                Label(title, systemImage: systemName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer(minLength: 8)

                Text(displayValues.firstIndex(of: value).map { displayValues[$0] } ?? value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
