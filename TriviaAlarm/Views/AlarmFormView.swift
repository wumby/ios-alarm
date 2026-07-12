import AVFoundation
import SwiftData
import SwiftUI

enum AlarmFormMode {
    case create
    case edit(AlarmItem)
}

struct AlarmFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var scheduler: AlarmSchedulingService
    let mode: AlarmFormMode
    let onSaved: ((AlarmItem) -> Void)?
    @State private var state: AlarmFormState
    @State private var previewPlayer: AVAudioPlayer?

    init(mode: AlarmFormMode, onSaved: ((AlarmItem) -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create:
            var form = AlarmFormState()
            let userDefaults = UserDefaults.standard
            form.label = userDefaults.string(forKey: "defaultAlarmLabel") ?? ""
            form.isTriviaEnabled = userDefaults.object(forKey: "defaultTriviaEnabled") as? Bool ?? true
            form.categoryIDs = Set(userDefaults.string(forKey: "defaultTriviaCategoryIDs")?.split(separator: ",").map(String.init) ?? TriviaCategory.defaultEnabled.map(\.id))
            form.difficulty = TriviaDifficulty(rawValue: userDefaults.string(forKey: "defaultTriviaDifficulty") ?? TriviaDifficulty.mixed.rawValue) ?? .mixed
            form.sound = AlarmSoundChoice(rawValue: userDefaults.string(forKey: "defaultAlarmSound") ?? "default") ?? .systemDefault
            form.repeatDays = Self.defaultRepeatDays(from: userDefaults.string(forKey: "defaultAlarmRepeatMode") ?? DefaultRepeatMode.once.rawValue)
            _state = State(initialValue: form)
        case .edit(let alarm):
            _state = State(initialValue: AlarmFormState(alarm: alarm))
        }
    }

    private static func defaultRepeatDays(from mode: String) -> Set<RepeatDay> {
        switch DefaultRepeatMode(rawValue: mode) ?? .once {
        case .once: []
        case .everyDay: Set(RepeatDay.allCases)
        case .weekdays: Set([.monday, .tuesday, .wednesday, .thursday, .friday])
        case .custom:
            Set(UserDefaults.standard.string(forKey: "defaultAlarmRepeatDays")?.split(separator: ",").compactMap { RepeatDay(rawValue: Int($0) ?? -1) } ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.sunriseBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Time")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.textPrimary)

                            DatePicker("", selection: $state.time, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(AppTheme.textPrimary)
                                .tint(AppTheme.accent)
                                .environment(\.colorScheme, .light)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .padding(18)
                        .floatingCard()

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Details")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.textPrimary)

                            TextField("Label", text: $state.label)
                                .textInputAutocapitalization(.words)
                                .padding(14)
                                .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )

                            if case .edit = mode {
                                Toggle("Enabled", isOn: $state.isEnabled)
                                    .tint(AppTheme.accent)
                            }

                        }
                        .padding(18)
                        .floatingCard()

                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 14) {
                            Text("Repeat")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.textPrimary)

                            RepeatMenu(selection: repeatModeBinding)

                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .floatingCard()

                            VStack(alignment: .leading, spacing: 14) {
                                Text("Sound")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(AppTheme.textPrimary)

                                SoundMenu(selection: $state.sound)

                                Button(action: previewSound) {
                                    Label("Test sound", systemImage: "play.circle.fill")
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accent)
                                .disabled(state.sound.fileName == nil)
                                .accessibilityHint(state.sound.fileName == nil ? "The system default sound cannot be previewed here." : "Plays the selected alarm sound.")

                                if state.sound.fileName == nil {
                                    Text("The system default sound cannot be previewed here.")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .floatingCard()
                        }

                        if !state.repeatDays.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Days")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.textPrimary)

                                DayPicker(selectedDays: $state.repeatDays)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .floatingCard()
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Trivia")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.textPrimary)

                            TriviaToggle(isOn: $state.isTriviaEnabled)

                            DifficultyMenu(selection: $state.difficulty, isEnabled: $state.isTriviaEnabled)

                            VStack(spacing: 0) {
                                ForEach(TriviaCategory.allCases) { category in
                                    Toggle(category.title, isOn: categoryBinding(category))
                                        .tint(AppTheme.accent)
                                        .padding(.vertical, 14)
                                        .disabled(!state.isTriviaEnabled)

                                    if category != TriviaCategory.allCases.last {
                                        Divider().opacity(0.35)
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .floatingCard()

                    }
                    .padding(24)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(state.isTriviaEnabled && state.categoryIDs.isEmpty)
                }
            }
        }
        .presentationBackground(.clear)
        .preferredColorScheme(.light)
        .onDisappear {
            previewPlayer?.stop()
            previewPlayer = nil
        }
    }

    private var title: String {
        switch mode {
        case .create: "New Alarm"
        case .edit: "Edit Alarm"
        }
    }

    private func categoryBinding(_ category: TriviaCategory) -> Binding<Bool> {
        Binding(
            get: { state.categoryIDs.contains(category.id) },
            set: { isSelected in
                if isSelected {
                    state.categoryIDs.insert(category.id)
                } else {
                    state.categoryIDs.remove(category.id)
                }
            }
        )
    }

    private var repeatModeBinding: Binding<RepeatMode> {
        Binding(
            get: {
                let days = state.repeatDays
                if days.isEmpty { return .once }
                if days == Set(RepeatDay.allCases) { return .everyDay }
                if days == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) { return .weekdays }
                return .custom
            },
            set: { mode in
                switch mode {
                case .once:
                    state.repeatDays = []
                case .everyDay:
                    state.repeatDays = Set(RepeatDay.allCases)
                case .weekdays:
                    state.repeatDays = Set([.monday, .tuesday, .wednesday, .thursday, .friday])
                case .custom:
                    if state.repeatDays.isEmpty {
                        state.repeatDays = Set(RepeatDay.allCases)
                    }
                }
            }
        )
    }

    private func save() {
        let alarm: AlarmItem
        switch mode {
        case .create:
            alarm = AlarmItem()
            state.apply(to: alarm)
            modelContext.insert(alarm)
        case .edit(let existing):
            alarm = existing
            state.apply(to: existing)
        }

        try? modelContext.save()
        onSaved?(alarm)
        Task {
            await scheduler.schedule(alarm: alarm)
        }
        dismiss()
    }

    private func previewSound() {
        guard let fileName = state.sound.fileName,
              let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".aiff", with: ""), withExtension: "aiff") else {
            return
        }

        previewPlayer?.stop()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            previewPlayer = player
        } catch {
            previewPlayer = nil
        }
    }
}

private enum RepeatMode: String, CaseIterable, Identifiable {
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

private struct RepeatMenu: View {
    @Binding var selection: RepeatMode

    var body: some View {
        Menu {
            ForEach(RepeatMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Label(mode.title, systemImage: selection == mode ? "checkmark" : "")
                }
            }
        } label: {
            ThemedMenuLabel(title: "Repeat", value: selection.title, systemName: "arrow.clockwise", compact: true)
        }
        .accessibilityLabel("Repeat")
        .accessibilityValue(selection.title)
    }
}

private struct SoundMenu: View {
    @Binding var selection: AlarmSoundChoice

    var body: some View {
        Menu {
            ForEach(AlarmSoundChoice.allCases) { sound in
                Button {
                    selection = sound
                } label: {
                    Label(sound.title, systemImage: selection == sound ? "checkmark" : "")
                }
            }
        } label: {
            ThemedMenuLabel(title: "Sound", value: selection.title, systemName: "speaker.wave.2.fill", compact: true)
        }
        .accessibilityLabel("Sound")
        .accessibilityValue(selection.title)
    }
}

private struct ThemedMenuLabel: View {
    let title: String
    let value: String
    let systemName: String
    var compact: Bool = false

    var body: some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Text(value)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            } else {
                HStack {
                    Label(title, systemImage: systemName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Text(value)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 0)
        .frame(minHeight: 46)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
    }
}

private struct TriviaToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accent.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(isOn ? "Trivia challenge on" : "Trivia challenge off")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(isOn ? "Answer a question to dismiss" : "Dismiss without a question")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isOn ? AppTheme.accent : AppTheme.textSecondary.opacity(0.45))
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [AppTheme.skyBlue.opacity(0.28), AppTheme.peach.opacity(0.30)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trivia")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct DifficultyMenu: View {
    @Binding var selection: TriviaDifficulty
    @Binding var isEnabled: Bool

    var body: some View {
        Menu {
            ForEach(TriviaDifficulty.allCases) { difficulty in
                Button {
                    selection = difficulty
                } label: {
                    Label(difficulty.rawValue, systemImage: selection == difficulty ? "checkmark" : "")
                }
            }
        } label: {
            HStack {
                Label("Difficulty", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Text(selection.rawValue)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)

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
        .disabled(!isEnabled)
        .accessibilityLabel("Difficulty")
        .accessibilityValue(selection.rawValue)
    }
}
