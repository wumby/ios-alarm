import AppIntents
import Foundation

@available(iOS 17.0, *)
struct OpenTriviaIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open Challenge"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {
        alarmID = ""
    }

    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else {
            return .result()
        }

        AlarmRuntimeStore.savePending(alarmID: id)

        await MainActor.run {
            AlarmRuntimeStore.shared.present(alarmID: id)
        }

        return .result()
    }
}
