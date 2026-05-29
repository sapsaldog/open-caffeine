# Open Caffein — Design Spec

**Date:** 2026-05-28
**Status:** Approved (pending user review of this document)
**Author:** Brainstormed with Claude

## Overview

**Open Caffein** is a macOS menubar utility that prevents the Mac from
sleeping for a user-selected duration. It is a clean-room rewrite inspired by
an existing caffeine-style menubar utility that no longer ships Apple Silicon
builds suitable for the author's machine.

The original product's name must not appear anywhere in source, UI, or
documentation — the project uses "Caffeine" / "Open Caffein" / generic terms
like "Session" instead.

## Goals & Non-Goals

**Goals**
- Feature parity with the original app's core functionality.
- Native Apple Silicon, modern macOS (13+).
- Personal, local-only build — no code signing, no notarization, no App
  Store distribution.
- Maintainable: every source file under 500 lines, enforced by SwiftLint.

**Non-Goals**
- Marketing-driven menu items (Contact Support, Newsletter, Rate Us, More
  Tools) — explicitly removed.
- Intel support.
- Mac App Store distribution.
- Multi-user / multi-session coordination.

## Scope (Feature List)

Included:
- Menubar icon with click-to-open menu.
- Preset durations: 5 / 10 / 15 / 30 / 45 min, 1 / 2 / 4 / 6 / 12 hours,
  Forever, Custom.
- Countdown display next to the menubar icon (toggleable).
- Multiple icon styles (Coffee Type 1/2/3 + dark/light aware).
- Start screensaver menu item.
- Preferences window with:
  - Appearance (icon style picker)
  - Global hotkey recorder (toggles caffeine on/off)
  - Start at login
  - Show icon in dock
  - Show instruction message on first launch
  - Show countdown
  - Keep the screen on (prevent display sleep; default on)
  - Default duration
  - Allow sleep if battery below threshold
- About panel (version + credits).
- Quit menu item.

Excluded:
- Contact Support / Subscribe to Newsletter / Rate Us / More Tools menus.

## Technology Stack

- **Language/UI:** Swift + SwiftUI (Preferences) + AppKit (`NSStatusItem`).
- **Min OS:** macOS 13 (Ventura).
- **Architecture:** Apple Silicon native (arm64).
- **Dependencies:**
  - [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) (>= 2.0) via SPM — global hotkey recorder + handler.
- **System frameworks:** IOKit (PM assertions + power sources),
  ServiceManagement (`SMAppService` for login item), os.log.
- **Build:** Xcode project (`.xcodeproj`), local builds only.
- **Lint:** SwiftLint via Build Phase Run Script.

## Architecture

Single-process menubar app with one central state holder
(`CaffeineSession`) and a small set of single-purpose services.

```
┌──────────────────────────────────────────────────────┐
│  AppDelegate (NSApplicationDelegate)                 │
│  • lifecycle, NSStatusItem 소유                       │
└──────┬──────────────────────────────────┬────────────┘
       │                                  │
       ▼                                  ▼
┌──────────────────┐              ┌────────────────────┐
│ MenuBarController│              │ PreferencesScene   │
│ • 메뉴 빌드        │              │ (SwiftUI Settings) │
│ • 아이콘/타이머 갱신 │              │ • 환경설정 UI       │
└──┬───────────────┘              └───┬────────────────┘
   │                                  │
   ▼                                  ▼
┌──────────────────────────────────────────────────┐
│  Services                                        │
│  CaffeineSession, SleepAssertion, HotKeyService, │
│  BatteryMonitor, AppSettings, ScreenSaverLauncher│
└──────────────────────────────────────────────────┘
```

**Dependency direction:** AppDelegate → MenuBarController / Preferences →
Services. Services are mostly independent; only `CaffeineSession` knows
about `SleepAssertion`, and only `BatteryMonitor` calls into
`CaffeineSession`.

**Single source of truth:** `CaffeineSession` exposes one
`@Published var state: SessionState`. The menubar UI and any other observer
subscribes to this.

## Components & File Layout

Estimated line counts in parentheses. All under the 500-line hard cap;
splits planned at ~400 lines.

```
OpenCaffein/
├── OpenCaffein.xcodeproj/
├── OpenCaffein/
│   ├── App/
│   │   ├── OpenCaffeinApp.swift           (~40)  @main, Settings scene 등록
│   │   └── AppDelegate.swift              (~80)  lifecycle, NSStatusItem, bootstrap
│   │
│   ├── MenuBar/
│   │   ├── MenuBarController.swift        (~180) NSStatusItem 관리, 아이콘 갱신
│   │   ├── MenuBuilder.swift              (~150) NSMenu 구성 (Start for ▶, Screensaver, Prefs, About, Quit)
│   │   └── CountdownFormatter.swift       (~40)  "1:23:45" 포맷팅
│   │
│   ├── Services/
│   │   ├── CaffeineSession.swift          (~200) 중앙 조율, 상태 머신, 타이머
│   │   ├── SleepAssertion.swift           (~120) IOPMAssertionCreateWithName 래퍼
│   │   ├── HotKeyService.swift            (~80)  KeyboardShortcuts 래퍼
│   │   ├── BatteryMonitor.swift           (~150) IOPSNotification, 임계값 체크
│   │   ├── ScreenSaverLauncher.swift      (~50)  ScreenSaverEngine 실행
│   │   └── LoginItemManager.swift         (~80)  SMAppService.mainApp 등록
│   │
│   ├── Settings/
│   │   ├── AppSettings.swift              (~120) @AppStorage 키, 타입 정의
│   │   ├── PreferencesScene.swift         (~60)  Settings 컨테이너
│   │   ├── GeneralSettingsView.swift      (~180) Appearance, hotkey, login, dock
│   │   ├── DurationSettingsView.swift     (~120) Countdown, default duration, battery
│   │   └── HotKeyRecorderRow.swift        (~60)  KeyboardShortcuts.Recorder 래핑
│   │
│   ├── Models/
│   │   ├── Duration.swift                 (~70)  enum: .forever, .minutes(Int), .custom
│   │   ├── MenuBarIconStyle.swift         (~50)  enum: coffeeType1/2/3 + asset 이름
│   │   └── SessionState.swift             (~40)  enum: idle, active(remaining: TimeInterval?)
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets/               아이콘 (Coffee Type 1~3, 다크/라이트)
│   │   └── About.swift                    (~60)  간단한 SwiftUI About 패널
│   │
│   └── Info.plist                                LSUIElement=true (Dock 숨김 토글)
│
├── OpenCaffeinTests/
│   ├── CaffeineSessionTests.swift         (~200)
│   ├── DurationTests.swift                (~80)
│   ├── BatteryMonitorTests.swift          (~120)
│   └── CountdownFormatterTests.swift      (~50)
│
├── .swiftlint.yml
└── README.md
```

### `.swiftlint.yml`

```yaml
included:
  - OpenCaffein
  - OpenCaffeinTests

file_length:
  warning: 400
  error: 500

type_body_length:
  warning: 250
  error: 400

function_body_length:
  warning: 40
  error: 80

line_length:
  warning: 120
  error: 160
  ignores_urls: true

cyclomatic_complexity:
  warning: 10
  error: 15

opt_in_rules:
  - empty_count
  - force_unwrapping
  - explicit_init
  - first_where
  - last_where
  - sorted_imports
  - redundant_type_annotation

disabled_rules:
  - trailing_comma
```

SwiftLint runs as a **Build Phase Run Script** (`brew install swiftlint`
prerequisite). Build fails on rule errors.

## Data Flow & Key Scenarios

### Scenario A — Start Caffeine for 30 min

```
User clicks menu item
  → MenuBuilder.handleStart(.minutes(30))
  → CaffeineSession.start(.minutes(30))
      ├─► SleepAssertion.acquire()
      │     └─► IOPMAssertionCreateWithName(
      │            kIOPMAssertPreventUserIdleDisplaySleep (default, screen on)
      │            / …PreventUserIdleSystemSleep when "Keep the screen on" off, ...)
      ├─► Timer.scheduledTimer(every: 1s) → tick
      └─► state = .active(remaining: 1800)
                   │
                   ▼
        MenuBarController (Combine sink)
              ├─► swap icon to "active" variant
              └─► statusItem.button.title = "29:59"  (if countdown on)
```

Expiry: timer detects `remaining == 0` → `CaffeineSession.stop()` →
`SleepAssertion.release()` → state `.idle` → icon reverts.

### Scenario B — Battery drops below threshold

```
IOPSNotificationCreateRunLoopSource fires
  → BatteryMonitor.handlePowerSourceChange()
      ├─► read current %
      └─► if percent < settings.sleepBelowBatteryPercent
           AND session.state == .active
              → CaffeineSession.stop(reason: .lowBattery)
                    ├─► SleepAssertion.release()
                    └─► NSUserNotification: "Sleep allowed: battery below X%"
```

### Scenario C — Global hotkey toggle

```
User presses ⌘⌥C (user-configured)
  → KeyboardShortcuts.onKeyDown(.toggleCaffeine)
  → HotKeyService.toggle()
      → if state == .idle: CaffeineSession.start(settings.defaultDuration)
        else:              CaffeineSession.stop(reason: .userToggled)
```

### State machine — `CaffeineSession`

```
       ┌──────────┐
       │   idle   │◄─────────┐
       └────┬─────┘          │
            │ start(duration)│ stop()/expired/lowBattery
            ▼                │
       ┌──────────┐          │
       │  active  │──────────┘
       │ remaining│
       └──────────┘
```

For `Forever`, `remaining = nil` and no expiry timer — only manual stop or
low-battery exit releases the assertion.

## Error Handling & Edge Cases

| Scenario | Handling |
|---|---|
| `IOPMAssertionCreateWithName` fails | `SleepAssertion.acquire()` throws → session stays `.idle`, `NSAlert` one-shot, IOReturn code logged. |
| `start` while already active | Release existing assertion → restart with new duration. |
| Timer drift across system sleep | Use wall-clock: store `startedAt: Date`, compute `remaining = duration - Date().timeIntervalSince(startedAt)` per tick. |
| Force kill (`SIGKILL`) | Kernel auto-releases IOPMAssertion when process dies — no cleanup needed. |
| Normal quit (Quit menu / `Cmd+Q`) | `applicationWillTerminate` calls `session.stop()` explicitly. |
| Hotkey conflict | KeyboardShortcuts library surfaces it in the Recorder UI; no extra handling. |
| Desktop Mac (no battery) | `BatteryMonitor` detects no source → slider disabled + "No battery detected" shown. |
| Forever mode running unattended | Active icon variant always visible — user visibility is the only safeguard. |
| Manual sleep (`Cmd+Opt+Eject`) | OS forces sleep regardless (PM assertion only blocks idle sleep). Intended. |
| `ScreenSaverEngine` launch fails | Alert + log. |
| `SMAppService` register fails | Toggle reverts + alert. |

### Logging

`os.Logger(subsystem: "com.opencaffein", category: ...)` with categories
`session`, `assertion`, `battery`, `hotkey`. Levels: `.debug` (dev),
`.notice` (state transitions), `.error` (failures).

User-visible notifications are minimized: failures get an alert; normal
operation (expiry, toggle) is silent. The first-launch instruction message
(if enabled) is the only opt-in notification.

## Testing Strategy

### Unit tests (XCTest)

Cover only the services with real logic; UI is verified manually.

| Test file | Coverage |
|---|---|
| `CaffeineSessionTests` | idle → active transition, expiry auto-stop, duplicate `start` releases prior assertion, wall-clock-based remaining (with clock mock), Forever mode (`remaining == nil`). |
| `DurationTests` | enum encode/decode, edge values like `.minutes(0)`. |
| `BatteryMonitorTests` | threshold callback fires when crossed, no-battery path disables, threshold == 0 (disabled) never fires. |
| `CountdownFormatterTests` | `H:MM:SS` for ≥1h, `MM:SS` under 1h. |

**Mocking strategy:** extract `SleepAssertion` behind a protocol so the
session can be tested without touching IOKit.

```swift
protocol SleepAssertionProviding {
    func acquire() throws
    func release()
    var isActive: Bool { get }
}
```

`CaffeineSession` depends only on the protocol; tests inject a fake that
counts acquire/release calls.

### Manual verification checklist (also in README)

- [ ] Start for 5 min → countdown begins at 5:00.
- [ ] After expiry, icon reverts and sleep works.
- [ ] Forever → still awake after 30 min idle.
- [ ] Forever + "Keep the screen on" ON (default) → screen stays on past the display-sleep timer.
- [ ] "Keep the screen on" OFF → display sleeps but system stays awake.
- [ ] Hotkey toggles on/off.
- [ ] Start-at-login toggle survives reboot.
- [ ] Show-in-dock toggle takes effect immediately.
- [ ] Battery threshold triggers release (use `pmset` simulation if hard to drain).
- [ ] `pmset -g assertions` shows `PreventUserIdleDisplaySleep` entry while active (or `…SystemSleep` when "Keep the screen on" is off).

### CI (optional)

GitHub Actions on macOS runner: `xcodebuild test` + `swiftlint --strict`.
For a personal project this is optional and may be deferred.

## Open Questions / Deferred

- **App icon / branding:** placeholder icons during MVP; final coffee-cup
  artwork can be drawn or sourced later.
- **CI:** decision deferred — local lint + tests are enough for personal
  use.
- **Sparkle auto-update:** out of scope (local-only build, manual rebuilds).

## Implementation Phases (rough)

1. Project skeleton: Xcode project, SwiftLint Build Phase, empty
   `AppDelegate` showing a menubar icon.
2. `SleepAssertion` + `CaffeineSession` + unit tests (TDD).
3. `MenuBuilder` with preset durations + Custom dialog.
4. `AppSettings` + `PreferencesScene` (GeneralSettingsView first).
5. Countdown display + `CountdownFormatter`.
6. Icon style picker + asset wiring.
7. `LoginItemManager` (start at login).
8. `HotKeyService` + Recorder UI.
9. `BatteryMonitor` + threshold UI.
10. `ScreenSaverLauncher` + menu entry.
11. About panel + first-launch instruction message.
12. Manual QA pass against checklist.

Each phase ends with green tests and a passing lint run.
