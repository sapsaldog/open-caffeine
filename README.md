# Open Caffeine

A personal macOS menubar utility that keeps the Mac awake for a chosen duration.
Apple Silicon, macOS 26 (Tahoe)+ — native Liquid Glass UI. No code signing — local builds only.

<p align="center">
  <a href="https://www.producthunt.com/products/open-caffeine?utm_source=badge-featured&amp;utm_medium=badge&amp;utm_campaign=badge-open-caffeine" target="_blank">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1160317&amp;theme=dark" />
      <img src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1160317&amp;theme=light" alt="Open Caffeine - Keep your Mac awake | Product Hunt" width="250" height="54" />
    </picture>
  </a>
</p>

<p align="center"><strong>🏆 Ranked #10 Product of the Day on Product Hunt</strong></p>

## Build

Prerequisites:

```bash
brew install xcodegen swiftlint
```

Generate and build:

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Release build
```

The app bundle is in `~/Library/Developer/Xcode/DerivedData/OpenCaffeine-*/Build/Products/Release/Open Caffeine.app`.

## Releasing updates (Sparkle)

Auto-updates use [Sparkle](https://sparkle-project.org). `SUFeedURL` points at
`appcast.xml` in this repo (served via `raw.githubusercontent.com`), and updates
are EdDSA-signed with the private key in your login keychain (public key is in
`Info.plist` as `SUPublicEDKey`).

To cut a release:

1. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Run `Scripts/release.sh` — builds Release, zips, EdDSA-signs, and regenerates `appcast.xml`.
3. Create a GitHub release tagged `v<version>` and upload `dist/Open-Caffeine-<version>.zip`.
4. Commit & push `appcast.xml`.

The **Updates** preferences tab ("Check Now" + automatic checks) drives the real
Sparkle updater against that feed.

## Run tests

```bash
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test
```

## Coverage

Every **logic** file must keep **100% line coverage**. The gate runs the suite with
coverage and fails if any non-excluded file under `OpenCaffeine/` drops below 100%:

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
- [ ] Forever + "Keep the screen on" ON (default) → screen stays on past the display-sleep timer.
- [ ] "Keep the screen on" OFF → display may sleep, but the Mac stays awake.
- [ ] Toggling "Keep the screen on" during an active session takes effect immediately.
- [ ] Hotkey toggles caffeine on/off.
- [ ] Start-at-login toggle survives reboot.
- [ ] Show-in-dock toggle takes effect immediately.
- [ ] Battery threshold triggers stop (use `pmset` if hard to drain).
- [ ] `pmset -g assertions` shows `PreventUserIdleDisplaySleep` while active (or `…SystemSleep` when "Keep the screen on" is off).
- [ ] About menu shows custom Open Caffeine panel.
- [ ] Screensaver launches from menu.
- [ ] Custom duration prompt accepts minutes input.
- [ ] Switching Appearance in Preferences changes the menubar icon immediately.

## Project layout

```
OpenCaffeine/
  App/                 # @main, AppDelegate (bootstrap)
  MenuBar/             # NSStatusItem controller, menu builder, countdown formatter, custom-duration prompt
  Services/            # SleepAssertion, CaffeineSession, HotKeyService, BatteryMonitor, LoginItemManager, ScreenSaverLauncher
  Settings/            # SwiftUI Preferences scene + tabs
  Models/              # CaffeineDuration, SessionState, MenuBarIconStyle
  Resources/           # Assets.xcassets, About panel
OpenCaffeineTests/      # XCTest suites + Mocks/
docs/superpowers/      # Spec + plan that drove this build
project.yml            # XcodeGen project definition (single source of truth — .xcodeproj is regenerated, not committed)
.swiftlint.yml         # Lint config (file_length 500 hard cap)
```

## Architecture

See [`docs/superpowers/specs/2026-05-28-open-caffeine-design.md`](docs/superpowers/specs/2026-05-28-open-caffeine-design.md).

## License

[MIT](LICENSE) © Open Caffeine contributors.
