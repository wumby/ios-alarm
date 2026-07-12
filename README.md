# Sunrise: Alarm

A SwiftUI MVP for an alarm app that requires a correct multiple-choice trivia answer before the in-app alarm dismissal flow completes.

## Project Structure

- `TriviaAlarm/App`: app entry point and notification delegate setup.
- `TriviaAlarm/Models`: SwiftData alarm model, repeat days, trivia categories, difficulty, and question models.
- `TriviaAlarm/Services`: AlarmKit scheduling, local-notification fallback, runtime alarm presentation state, AppIntent routing, and bundled JSON trivia loading.
- `TriviaAlarm/Resources`: asset catalog and offline `trivia_*.json` question files.
- `TriviaAlarm/ViewModels`: form state used by create/edit flows.
- `TriviaAlarm/Views`: alarm list, create/edit form, settings, and full-screen trivia dismissal UI.

## Build

Open `TriviaAlarm.xcodeproj` in Xcode 26.2 or newer, or run:

```sh
xcodebuild -project TriviaAlarm.xcodeproj -scheme "Trivia Alarm" -destination 'generic/platform=iOS Simulator' build
```

## iOS Alarm Limitations

- This MVP uses AlarmKit for scheduled alarms on iOS 26+ for better alarm reliability, with local notifications as a fallback.
- The AlarmKit secondary button is backed by `OpenTriviaIntent`, which opens the app and presents the full-screen trivia gate for the active alarm.
- The app does not configure snooze/countdown behavior. Hardware buttons and any lock-screen silence/stop behavior remain controlled by iOS; AlarmKit does not expose a volume-button override in the current SDK.
- `NSAlarmKitUsageDescription` is included in `Info.plist`; notification fallback permission text is included too.
- A third-party iOS app cannot remove every Apple-controlled Lock Screen stop/dismiss path or force a custom SwiftUI trivia screen over the Lock Screen. The reliable system alarm and the trivia-only dismissal requirement conflict at the OS level; this app makes the Trivia path work, but Apple may still show a system Stop control.
- For production, add any Apple-required AlarmKit capability/entitlement in Xcode if your developer account and target OS require it, then test on a physical device. Simulator behavior for alarm delivery and lock-screen presentation can differ from device behavior.
