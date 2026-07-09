import SwiftData
import SwiftUI

@main
struct TriviaAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        migrateDefaultTriviaCategories()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AlarmItem.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }

    private func migrateDefaultTriviaCategories() {
        let defaults = UserDefaults.standard
        let migrationKey = "didMigrateAllTriviaCategoriesDefault"

        guard !defaults.bool(forKey: migrationKey) else { return }

        defaults.set(TriviaCategory.defaultEnabled.map(\.id).joined(separator: ","), forKey: "defaultTriviaCategoryIDs")
        defaults.set(true, forKey: migrationKey)
    }
}
