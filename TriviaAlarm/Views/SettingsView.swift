import SwiftUI

struct SettingsView: View {
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

                        Text("Trivia Categories")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)

                        VStack(spacing: 0) {
                            ForEach(TriviaCategory.allCases) { category in
                                Toggle(category.title, isOn: binding(for: category))
                                    .tint(AppTheme.accent)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 18)

                                if category != TriviaCategory.allCases.last {
                                    Divider().opacity(0.35)
                                }
                            }
                        }
                        .floatingCard()

                        VStack(alignment: .leading, spacing: 0) {
                            DefaultMenu(
                                title: "Difficulty",
                                value: defaultTriviaDifficulty,
                                systemName: "gauge.with.dots.needle.67percent",
                                options: TriviaDifficulty.allCases.map(\.rawValue),
                                selection: $defaultTriviaDifficulty
                            )
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)

                            Divider().opacity(0.35)

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

                        Text("These defaults apply to new alarms. Existing alarms keep their own categories, difficulty, and sound.")
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
