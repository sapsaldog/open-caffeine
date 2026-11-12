# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
  battery slider, and the menu-bar icon choices are labeled too.

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

[Unreleased]: https://github.com/sapsaldog/open-caffeine/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/sapsaldog/open-caffeine/releases/tag/v1.0.0
