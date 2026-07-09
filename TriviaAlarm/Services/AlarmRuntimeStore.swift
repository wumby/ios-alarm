import Foundation

@MainActor
final class AlarmRuntimeStore: ObservableObject {
    static let shared = AlarmRuntimeStore()
    nonisolated private static let pendingAlarmIDKey = "pendingTriviaAlarmID"

    @Published var activeAlarmID: UUID?

    private init() {}

    nonisolated static func savePending(alarmID: UUID) {
        UserDefaults.standard.set(alarmID.uuidString, forKey: pendingAlarmIDKey)
    }

    func present(alarmID: UUID) {
        activeAlarmID = alarmID
    }

    func presentPendingAlarmIfNeeded() {
        guard
            let rawValue = UserDefaults.standard.string(forKey: Self.pendingAlarmIDKey),
            let alarmID = UUID(uuidString: rawValue)
        else {
            return
        }

        UserDefaults.standard.removeObject(forKey: Self.pendingAlarmIDKey)
        present(alarmID: alarmID)
    }

    func clear() {
        activeAlarmID = nil
    }
}
