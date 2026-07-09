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
    @AppStorage("defaultTriviaCategoryIDs") private var defaultCategoryIDs = TriviaCategory.defaultEnabled.map(\.id).joined(separator: ",")

    let mode: AlarmFormMode
    @State private var state: AlarmFormState

    init(mode: AlarmFormMode) {
        self.mode = mode
        switch mode {
        case .create:
            var form = AlarmFormState()
            let defaults = Set(UserDefaults.standard.string(forKey: "defaultTriviaCategoryIDs")?.split(separator: ",").map(String.init) ?? TriviaCategory.defaultEnabled.map(\.id))
            form.categoryIDs = defaults
            _state = State(initialValue: form)
        case .edit(let alarm):
            _state = State(initialValue: AlarmFormState(alarm: alarm))
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

                            Toggle("Enabled", isOn: $state.isEnabled)
                                .tint(AppTheme.accent)

                            DifficultyChips(selection: $state.difficulty)
                        }
                        .padding(18)
                        .floatingCard()

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Repeat")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.textPrimary)

                            DayPicker(selectedDays: $state.repeatDays)
                        }
                        .padding(18)
                        .floatingCard()

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Trivia")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.textPrimary)

                            VStack(spacing: 0) {
                                ForEach(TriviaCategory.allCases) { category in
                                    Toggle(category.title, isOn: categoryBinding(category))
                                        .tint(AppTheme.accent)
                                        .padding(.vertical, 14)

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
                        .disabled(state.categoryIDs.isEmpty)
                }
            }
        }
        .presentationBackground(.clear)
        .preferredColorScheme(.light)
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
        Task {
            await scheduler.schedule(alarm: alarm)
        }
        dismiss()
    }
}

private struct DifficultyChips: View {
    @Binding var selection: TriviaDifficulty

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TriviaDifficulty.allCases) { difficulty in
                Button {
                    selection = difficulty
                } label: {
                    Text(difficulty.rawValue)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .foregroundStyle(selection == difficulty ? .white : AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selection == difficulty ? AppTheme.accent : Color.white.opacity(0.58))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selection == difficulty ? AppTheme.accent.opacity(0.25) : AppTheme.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
