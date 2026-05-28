# Open Caffein

A personal macOS menubar utility that keeps the Mac awake for a chosen duration.
Apple Silicon, macOS 13+. No code signing — local builds only.

## Build

Prerequisites:

```bash
brew install xcodegen swiftlint
```

Generate and build:

```bash
xcodegen generate
xcodebuild -project OpenCaffein.xcodeproj -scheme OpenCaffein -configuration Release build
```

The app bundle is in `~/Library/Developer/Xcode/DerivedData/OpenCaffein-*/Build/Products/Release/Open Caffein.app`.

## Run tests

```bash
xcodebuild -project OpenCaffein.xcodeproj -scheme OpenCaffein -destination 'platform=macOS' test
```

## Coverage

Every **logic** file must keep **100% line coverage**. The gate runs the suite with
coverage and fails if any non-excluded file under `OpenCaffein/` drops below 100%:

```bash
Scripts/coverage-gate.sh
```

It is enforced on `git push` via a pre-push hook. Enable it once per clone:

```bash
git config core.hooksPath Scripts/hooks
```

Bypass a single push with `git push --no-verify`.

**What's excluded and why.** Only UI/AppKit/system *shells* are exempt — SwiftUI view
bodies, the `@main` entry, `AppDelegate`/`MenuBarController` wiring, `NSAlert`/`NSWindow`
presenters, and thin IOKit/SMAppService/KeyboardShortcuts/NSWorkspace adapters. Their
decision logic has been extracted into separately-tested types (`GeneralSettingsActions`,
`BatteryThresholdFormatter`, `MenuBarIconModel`, `CustomDurationParser`, `AppLaunchLogic`,
`BatterySnapshotParser`, the `*Providing`/`*Controlling` seams). The full, justified list
lives in `Scripts/coverage_check.py` — new source files are **not** exempt by default, so
adding one forces a conscious choice: test it, or extract its logic and list the shell.

## Manual QA Checklist

- [ ] Start for 5 min → countdown begins at 5:00 next to icon.
- [ ] After 5 min, icon reverts and sleep works again.
- [ ] Forever → still awake after 30 min idle.
- [ ] Display Sleep < session timer → display sleeps, system stays awake (expected).
- [ ] Hotkey toggles caffeine on/off.
- [ ] Start-at-login toggle survives reboot.
- [ ] Show-in-dock toggle takes effect immediately.
- [ ] Battery threshold triggers stop (use `pmset` if hard to drain).
- [ ] `pmset -g assertions` shows `PreventUserIdleSystemSleep` while active.
- [ ] About menu shows custom Open Caffein panel.
- [ ] Screensaver launches from menu.
- [ ] Custom duration prompt accepts minutes input.
- [ ] Switching Appearance in Preferences changes the menubar icon immediately.

## Project layout

```
OpenCaffein/
  App/                 # @main, AppDelegate (bootstrap)
  MenuBar/             # NSStatusItem controller, menu builder, countdown formatter, custom-duration prompt
  Services/            # SleepAssertion, CaffeineSession, HotKeyService, BatteryMonitor, LoginItemManager, ScreenSaverLauncher
  Settings/            # SwiftUI Preferences scene + tabs
  Models/              # CaffeineDuration, SessionState, MenuBarIconStyle
  Resources/           # Assets.xcassets, About panel
OpenCaffeinTests/      # XCTest suites + Mocks/
docs/superpowers/      # Spec + plan that drove this build
project.yml            # XcodeGen project definition (single source of truth — .xcodeproj is regenerated, not committed)
.swiftlint.yml         # Lint config (file_length 500 hard cap)
```

## Architecture

See [`docs/superpowers/specs/2026-05-28-open-caffein-design.md`](docs/superpowers/specs/2026-05-28-open-caffein-design.md).

## License

Personal use.
