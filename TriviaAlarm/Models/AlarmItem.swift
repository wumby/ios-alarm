import Foundation
import SwiftData

@Model
final class AlarmItem {
    @Attribute(.unique) var id: UUID
    var timeMinutes: Int
    var label: String
    var repeatDaysRaw: String
    var isEnabled: Bool
    var categoryIDsRaw: String
    var difficultyRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        timeMinutes: Int = AlarmItem.minutes(from: Date()),
        label: String = "Alarm",
        repeatDays: Set<RepeatDay> = [],
        isEnabled: Bool = true,
        categoryIDs: Set<String> = Set(TriviaCategory.defaultEnabled.map(\.id)),
        difficulty: TriviaDifficulty = .mixed,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.timeMinutes = timeMinutes
        self.label = label
        self.repeatDaysRaw = repeatDays.map { String($0.rawValue) }.sorted().joined(separator: ",")
        self.isEnabled = isEnabled
        self.categoryIDsRaw = categoryIDs.sorted().joined(separator: ",")
        self.difficultyRaw = difficulty.rawValue
        self.createdAt = createdAt
    }

    var hour: Int { timeMinutes / 60 }
    var minute: Int { timeMinutes % 60 }

    var timeDate: Date {
        get {
            Calendar.current.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: Date()
            ) ?? Date()
        }
        set {
            timeMinutes = Self.minutes(from: newValue)
        }
    }

    var repeatDays: Set<RepeatDay> {
        get {
            Set(repeatDaysRaw.split(separator: ",").compactMap { RepeatDay(rawValue: Int($0) ?? -1) })
        }
        set {
            repeatDaysRaw = newValue.map { String($0.rawValue) }.sorted().joined(separator: ",")
        }
    }

    var categoryIDs: Set<String> {
        get {
            let ids = categoryIDsRaw.split(separator: ",").map(String.init)
            return ids.isEmpty ? Set(TriviaCategory.defaultEnabled.map(\.id)) : Set(ids)
        }
        set {
            categoryIDsRaw = newValue.sorted().joined(separator: ",")
        }
    }

    var difficulty: TriviaDifficulty {
        get { TriviaDifficulty(rawValue: difficultyRaw) ?? .mixed }
        set { difficultyRaw = newValue.rawValue }
    }

    static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 7) * 60 + (components.minute ?? 0)
    }
}

