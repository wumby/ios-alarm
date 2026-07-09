# Alarm: Trivia Agent Context

This is a native iOS SwiftUI project, not a Next.js project.

## Project Identity

- User-facing app brand: `Alarm: Trivia`
- Xcode project: `TriviaAlarm.xcodeproj`
- Current Xcode scheme/target: `Trivia Alarm`
- Product/display name: `Alarm: Trivia`
- Bundle identifier currently uses the sample value `com.example.TriviaAlarm`; change this before production.

## Build And Verification

Use this build command after code changes:

```sh
xcodebuild -project TriviaAlarm.xcodeproj -scheme "Trivia Alarm" -destination 'generic/platform=iOS Simulator' build
```

Do not run npm/Next.js commands for this repo unless the project is later converted or a web app is added.

## Current Product Direction

- The app should feel visually distinct from Apple Clock: minimal, modern, and challenge-focused rather than a clone of the iOS alarm list.
- The main screen is a dashboard with custom alarm tiles, a next challenge panel, and a streak panel.
- New alarm time picker should open at the current time.
- All trivia categories should be enabled by default for new installs and new alarms.
- Settings should still let the user configure default trivia categories for future alarms.
- Existing alarms keep their own selected categories when Settings changes.
- Current streak is shown in the app with recent completion days.
- When the user loses the streak, old completion-day history can be pruned/deleted.

## Important iOS / AlarmKit Constraints

- Prefer AlarmKit for scheduling when available because it is more reliable than normal local notifications.
- Keep the local notification fallback for older iOS versions or AlarmKit failures.
- AlarmKit/system alarm UI is controlled by iOS. The app cannot fully remove Apple-controlled Lock Screen Stop/slide-to-stop behavior.
- Hardware buttons and any lock-screen silence/stop behavior are controlled by iOS; the current SDK does not expose a volume-button override.
- The app does not configure snooze/countdown behavior.
- The AlarmKit secondary button is backed by `OpenTriviaIntent`, which opens the app and presents the full-screen trivia gate.
- A third-party app cannot force a custom SwiftUI trivia screen directly over the Lock Screen. The app enforces trivia once the app is opened/foregrounded.
- `NSAlarmKitUsageDescription` and notification fallback usage text live in `TriviaAlarm/SupportingFiles/Info.plist`.
- Test AlarmKit behavior on a physical device before production; simulator behavior can differ.

## Project Structure

- `TriviaAlarm/App`
  - `TriviaAlarmApp.swift`: app entry point, SwiftData container setup, one-time default-category migration.
  - `AppDelegate.swift`: notification delegate setup for local-notification fallback.
- `TriviaAlarm/Models`
  - `AlarmItem.swift`: SwiftData alarm model and stored alarm properties.
  - `RepeatDay.swift`: repeat-day model.
  - `TriviaModels.swift`: trivia categories, difficulty, and `TriviaQuestion`.
- `TriviaAlarm/Services`
  - `AlarmSchedulingService.swift`: AlarmKit scheduling, local notification fallback, cancellation, dismissal, and comments around permissions/scheduling behavior.
  - `OpenTriviaIntent.swift`: AppIntent/LiveActivityIntent used by AlarmKit custom action to open trivia.
  - `AlarmRuntimeStore.swift`: pending/presented alarm state so the app can show the full-screen trivia view.
  - `NotificationDelegate.swift`: local notification routing to the same runtime alarm flow.
  - `TriviaService.swift`: bundled JSON trivia loader and filtering by category/difficulty.
  - `StreakStore.swift`: local streak history in `UserDefaults`, including pruning old answers after streak loss.
- `TriviaAlarm/ViewModels`
  - `AlarmFormState.swift`: create/edit form state and mapping to/from `AlarmItem`.
- `TriviaAlarm/Views`
  - `ContentView.swift`: main dashboard, streak panel, next challenge panel, and alarm list.
  - `RootView.swift`: root presentation layer for pending alarm dismissal.
  - `AlarmFormView.swift`: create/edit alarm form.
  - `SettingsView.swift`: default trivia categories.
  - `TriviaAlarmDismissalView.swift`: full-screen trivia gate; wrong answers immediately load another question, correct answer dismisses the alarm and records streak completion.
  - `Views/Components/AlarmRowView.swift`: custom alarm tile.
  - `Views/Components/DayPicker.swift`: repeat day picker.
- `TriviaAlarm/Resources`
  - Asset catalog.
  - Bundled `trivia_*.json` question files generated from local seed questions and Wikidata imports.
- `TriviaAlarm/SupportingFiles`
  - `Info.plist`.
- `Scripts`
  - `generate_wikidata_trivia.py`: developer-only script that queries Wikidata and writes static offline JSON question files. This script may use network at content-generation time; the app itself must remain offline.

## Persistence

- Alarms are persisted locally with SwiftData via `AlarmItem`.
- Default trivia category settings are stored in `UserDefaults` under `defaultTriviaCategoryIDs`.
- Streak completion days are stored in `UserDefaults` by `StreakStore`.
- Pending alarm presentation state is stored in `UserDefaults` by `AlarmRuntimeStore`.
- Seen trivia question IDs are stored in `UserDefaults` by `TriviaService` so displayed questions do not repeat until the relevant question pool is exhausted.
- Trivia questions are not currently persisted in SwiftData; they are bundled offline JSON files in `TriviaAlarm/Resources`.

## Trivia Question Bank

- Current question storage: bundled `trivia_*.json` files in `TriviaAlarm/Resources`.
- Current count after the first Wikidata import: about 4,212 questions.
- Categories: General, Science, History, Geography, Entertainment, Sports.
- Difficulties: Mixed, Easy, Medium, Hard. Mixed means no difficulty filter.
- If the filtered category/difficulty set is empty, `TriviaService` falls back to another available local question.
- `TriviaService` scans bundled resources for JSON files whose names start with `trivia_`, skips malformed files, ignores duplicate IDs, and validates answer count/correct index/category/difficulty before adding questions to memory.
- `TriviaService` marks questions as seen when shown. It avoids seen questions for the active category/difficulty filter, then resets that filtered pool only after it is exhausted.
- Current per-file counts are approximately: General 1003, Science 526, History 397, Geography 621, Sports 1289, Entertainment 376.

## Implementation Notes

- Use SwiftUI patterns already in the project.
- Keep models, views, view models, services, and persistence separated.
- Use `apply_patch` for manual code edits.
- Do not revert unrelated user changes.
- Keep AlarmKit comments where permission, scheduling, system action, and dismissal behavior are handled.
- Preserve the AlarmKit-first plus notification-fallback design unless the user explicitly asks to move away from it.
