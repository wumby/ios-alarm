import Foundation
import SwiftUI
import UserNotifications

import ActivityKit

#if canImport(AlarmKit)
import AlarmKit
#endif

@MainActor
final class AlarmSchedulingService: ObservableObject {
    static let shared = AlarmSchedulingService()

    @Published var authorizationMessage: String?

    private init() {
        observeAlarmKitUpdates()
    }

    func requestAuthorization() async {
        // Permissions: AlarmKit has its own authorization prompt on iOS 26+. The
        // fallback path asks for notification permission for older OS versions or
        // AlarmKit scheduling failures.
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            do {
                let state = try await AlarmManager.shared.requestAuthorization()
                authorizationMessage = state == .authorized ? nil : "Alarm permission is not enabled."
                return
            } catch {
                authorizationMessage = "AlarmKit permission failed: \(error.localizedDescription)"
            }
        }
        #endif

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            authorizationMessage = granted ? nil : "Notification permission is not enabled."
        } catch {
            authorizationMessage = "Notification permission failed: \(error.localizedDescription)"
        }
    }

    func schedule(alarm: AlarmItem) async {
        guard alarm.isEnabled else {
            cancel(alarm: alarm)
            return
        }

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            do {
                try await scheduleWithAlarmKit(alarm)
                return
            } catch {
                authorizationMessage = "AlarmKit scheduling failed. Using notifications instead."
            }
        }
        #endif

        await scheduleFallbackNotification(alarm)
    }

    func cancel(alarm: AlarmItem) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
        #endif

        let identifiers = notificationIdentifiers(for: alarm)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func dismiss(alarm: AlarmItem) {
        // Alarm dismissal: this is intentionally called only after TriviaAlarmDismissalView
        // receives a correct answer. Wrong answers replace the question and never reach here.
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.stop(id: alarm.id)
        }
        #endif

        AlarmRuntimeStore.shared.clear()
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func scheduleWithAlarmKit(_ alarm: AlarmItem) async throws {
        // AlarmKit scheduling: system alarms are scheduled here for reliability.
        // The secondary button is backed by OpenTriviaIntent, which opens the app
        // and presents the configured challenge for this alarm. The generic label
        // leaves room for future challenge types beyond trivia.
        let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.repeatDays.isEmpty
            ? .never
            : .weekly(alarm.repeatDays.sorted { $0.rawValue < $1.rawValue }.map(\.alarmKitWeekday))
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: recurrence))

        let title = LocalizedStringResource(stringLiteral: alarm.label.isEmpty ? "Alarm: Trivia" : alarm.label)
        let challengeButton = AlarmButton(text: "CLICK TO STOP", textColor: .white, systemImageName: "sparkles")
        let stopButton = AlarmButton(text: "Stop", textColor: .white, systemImageName: "xmark.circle.fill")
        let alert: AlarmPresentation.Alert
        if !alarm.triviaEnabled {
            alert = AlarmPresentation.Alert(title: title, stopButton: stopButton)
        } else if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: title,
                secondaryButton: challengeButton,
                secondaryButtonBehavior: .custom
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: stopButton,
                secondaryButton: challengeButton,
                secondaryButtonBehavior: .custom
            )
        }
        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: TriviaAlarmMetadata(appAlarmID: alarm.id.uuidString),
            tintColor: .orange
        )
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            secondaryIntent: OpenTriviaIntent(alarmID: alarm.id),
            sound: alarm.sound.fileName.map { ActivityKit.AlertConfiguration.AlertSound.named($0) } ?? .default
        )

        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: configuration)
    }

    private func observeAlarmKitUpdates() {
        guard #available(iOS 26.0, *) else { return }

        Task { @MainActor in
            for await alarms in AlarmManager.shared.alarmUpdates {
                if let alerting = alarms.first(where: { $0.state == .alerting }) {
                    AlarmRuntimeStore.shared.present(alarmID: alerting.id)
                }
            }
        }
    }
    #else
    private func observeAlarmKitUpdates() {}
    #endif

    private func scheduleFallbackNotification(_ alarm: AlarmItem) async {
        cancel(alarm: alarm)

        let days = alarm.repeatDays.sorted { $0.rawValue < $1.rawValue }
        if days.isEmpty {
            await addNotification(alarm: alarm, weekday: nil)
        } else {
            for day in days {
                await addNotification(alarm: alarm, weekday: day.rawValue)
            }
        }
    }

    private func addNotification(alarm: AlarmItem, weekday: Int?) async {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm: Trivia" : alarm.label
        content.body = alarm.triviaEnabled ? "Answer a trivia question to dismiss." : "Your alarm is going off."
        content.sound = alarm.sound.fileName.map { UNNotificationSound(named: UNNotificationSoundName(rawValue: $0)) } ?? .default
        content.userInfo = [
            "alarmID": alarm.id.uuidString,
            "triviaEnabled": alarm.triviaEnabled
        ]

        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        if let weekday {
            components.weekday = weekday
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: weekday != nil)
        let identifier = weekday.map { "\(alarm.id.uuidString)-\($0)" } ?? alarm.id.uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            authorizationMessage = "Notification scheduling failed: \(error.localizedDescription)"
        }
    }

    private func notificationIdentifiers(for alarm: AlarmItem) -> [String] {
        [alarm.id.uuidString] + RepeatDay.allCases.map { "\(alarm.id.uuidString)-\($0.rawValue)" }
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct TriviaAlarmMetadata: AlarmMetadata {
    let appAlarmID: String
}

@available(iOS 26.0, *)
private extension RepeatDay {
    var alarmKitWeekday: Locale.Weekday {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }
}
#endif
