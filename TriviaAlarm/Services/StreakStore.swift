import Foundation

@MainActor
final class StreakStore: ObservableObject {
    static let shared = StreakStore()

    private static let completionDaysKey = "triviaAlarmCompletionDays"
    private let calendar = Calendar.current
    private let formatter: DateFormatter

    @Published private(set) var completionDays: Set<String>
    @Published private(set) var currentStreak: Int = 0

    private init() {
        formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        completionDays = Set(UserDefaults.standard.stringArray(forKey: Self.completionDaysKey) ?? [])
        pruneToActiveStreak()
    }

    func recordCompletion(on date: Date = Date()) {
        completionDays.insert(dayKey(for: date))
        pruneToActiveStreak()
    }

    func refresh() {
        pruneToActiveStreak()
    }

    func isCompleted(_ date: Date) -> Bool {
        completionDays.contains(dayKey(for: date))
    }

    func recentDays(count: Int = 7) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: -(count - 1 - offset), to: today)
        }
    }

    private func pruneToActiveStreak() {
        guard let anchor = activeAnchorDate() else {
            completionDays.removeAll()
            currentStreak = 0
            persist()
            return
        }

        var kept: Set<String> = []
        var cursor = anchor

        while completionDays.contains(dayKey(for: cursor)) {
            kept.insert(dayKey(for: cursor))
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        completionDays = kept
        currentStreak = kept.count
        persist()
    }

    private func activeAnchorDate() -> Date? {
        let today = calendar.startOfDay(for: Date())
        if completionDays.contains(dayKey(for: today)) {
            return today
        }

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return nil
        }

        return completionDays.contains(dayKey(for: yesterday)) ? yesterday : nil
    }

    private func dayKey(for date: Date) -> String {
        formatter.string(from: calendar.startOfDay(for: date))
    }

    private func persist() {
        UserDefaults.standard.set(completionDays.sorted(), forKey: Self.completionDaysKey)
    }
}

