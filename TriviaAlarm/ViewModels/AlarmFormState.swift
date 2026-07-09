import Foundation

struct AlarmFormState {
    var time: Date = Date()
    var label: String = "Wake up"
    var repeatDays: Set<RepeatDay> = []
    var isEnabled: Bool = true
    var categoryIDs: Set<String> = Set(TriviaCategory.defaultEnabled.map(\.id))
    var difficulty: TriviaDifficulty = .mixed

    init() {}

    init(alarm: AlarmItem) {
        time = alarm.timeDate
        label = alarm.label
        repeatDays = alarm.repeatDays
        isEnabled = alarm.isEnabled
        categoryIDs = alarm.categoryIDs
        difficulty = alarm.difficulty
    }

    func apply(to alarm: AlarmItem) {
        alarm.timeDate = time
        alarm.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        alarm.repeatDays = repeatDays
        alarm.isEnabled = isEnabled
        alarm.categoryIDs = categoryIDs
        alarm.difficulty = difficulty
    }
}
