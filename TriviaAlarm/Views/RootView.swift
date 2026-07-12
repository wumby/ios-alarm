import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var runtime = AlarmRuntimeStore.shared
    @Query(sort: \AlarmItem.timeMinutes) private var alarms: [AlarmItem]
    @StateObject private var scheduler = AlarmSchedulingService.shared

    var body: some View {
        ContentView()
            .environmentObject(scheduler)
            .environmentObject(runtime)
            .task {
                await scheduler.requestAuthorization()
                if #available(iOS 26.0, *) {
                    await scheduler.synchronize(alarmItems: alarms)
                }
                runtime.presentPendingAlarmIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    runtime.presentPendingAlarmIfNeeded()
                }
            }
            .fullScreenCover(isPresented: activeAlarmBinding) {
                if let alarm = activeAlarm {
                    TriviaAlarmDismissalView(alarm: alarm)
                        .environmentObject(scheduler)
                } else {
                    EmptyView()
                }
            }
    }

    private var activeAlarm: AlarmItem? {
        guard let id = runtime.activeAlarmID else { return nil }
        return alarms.first { $0.id == id }
    }

    private var activeAlarmBinding: Binding<Bool> {
        Binding(
            get: { runtime.activeAlarmID != nil && activeAlarm?.triviaEnabled == true },
            set: { isPresented in
                if !isPresented {
                    runtime.clear()
                }
            }
        )
    }
}
