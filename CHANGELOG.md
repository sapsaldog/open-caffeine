# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-11-25

### Added
- "Display Off" button in the menu-bar panel. It turns the displays off right
  away while the Mac keeps running, and starts a session first if none is
  running (if the session ends in the meantime, the screen stays on).
- "Stay awake with lid closed" switch on MacBooks: while a session runs, closing
  the lid no longer puts the Mac to sleep. It needs a one-time approval of a small
  helper in System Settings, turns the built-in display off when the lid closes,
  and lets the Mac sleep below 20% battery or when it gets hot. Sleep comes back
  when the session ends or Open Caffeine quits or crashes (retried until it
  works, and restored after a helper crash too), and if that happens while the
  lid is closed, the Mac goes to sleep right away.

### Changed
- The panel's screen saver button is now a half-width "Screensaver" button next
  to "Display Off", so the panel keeps its height.
- With "Keep the screen on", Open Caffeine now also blocks system sleep
  directly, so the Mac stays awake even after the display is turned off by
  hand (Display Off, a hot corner, or a keyboard shortcut).
- Releases are signed with Developer ID and notarized by Apple, so macOS opens a
  downloaded copy without System Settings › Privacy & Security › Open Anyway.

### Fixed
- Release builds no longer include code-coverage instrumentation.

## [1.0.3] - 2026-11-12

### Added
- "Hide seconds in countdown" option (off by default) that shows the remaining
  time as hours:minutes in the menu bar and panel.

### Fixed
- The panel countdown no longer briefly shows more than the chosen duration
  right after a session starts.
- Entering a very large custom duration no longer crashes the app. Custom
  durations now take 1 to 10,080 minutes (7 days), and the prompt asks again
  when the value is out of range.
- Turning on "Show countdown" during a session no longer leaves the menu-bar
  countdown frozen.
- VoiceOver now names each settings switch and reads whether it is on or off,
  and the switches can be reached with the keyboard. The pop-up menus, the
  battery slider, the hot-key field, and the menu-bar icon choices are labeled
  too. In the menu-bar panel, the cup reads as a "Stay awake" switch and the
  duration buttons read as "5 min", "Forever", and so on.
- The menu-bar panel no longer runs a once-a-second timer while it is closed,
  so Open Caffeine stays idle in the background instead of waking every second.

## [1.0.0] - 2026-05-28

First public release.

### Added
- Menu-bar utility that keeps the Mac awake for a chosen duration (presets,
  Forever, and a custom duration).
- Countdown next to the menu-bar icon (toggleable).
- Three coffee glyph styles with Light / Dark / Auto appearance.
- Liquid Glass popover and a macOS Tahoe-style Preferences window.
- "Keep the screen on" toggle (prevents display sleep; on by default).
- Global hotkey, start-at-login, show-in-dock, default duration, and a
  battery-threshold auto-stop.
- Start screensaver action.
- Automatic updates via Sparkle, served from an EdDSA-signed appcast.

[Unreleased]: https://github.com/sapsaldog/open-caffeine/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/sapsaldog/open-caffeine/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/sapsaldog/open-caffeine/compare/v1.0.2...v1.0.3
[1.0.0]: https://github.com/sapsaldog/open-caffeine/releases/tag/v1.0.0
