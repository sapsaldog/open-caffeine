# Open Caffeine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menubar app called **Open Caffeine** that prevents the Mac from sleeping for a user-selected duration, with full feature parity to the original app minus marketing menu items.

**Architecture:** Hybrid SwiftUI + AppKit. `AppDelegate` owns an `NSStatusItem`; a central `CaffeineSession` service holds the single source of truth (`@Published var state`) and wraps `IOPMAssertion`. SwiftUI `Settings` scene provides the Preferences window. Other services (`HotKeyService`, `BatteryMonitor`, `LoginItemManager`, `ScreenSaverLauncher`) plug in around the session.

**Tech Stack:** Swift 5.10, macOS 13+, AppKit (`NSStatusItem`) + SwiftUI (Settings), IOKit (`IOPMAssertion`, `IOPSNotification`), ServiceManagement (`SMAppService`), [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) via SPM, XcodeGen (`project.yml`-driven Xcode project), SwiftLint (Build Phase, 500-line file cap), XCTest.

**Spec:** [`docs/superpowers/specs/2026-05-28-open-caffeine-design.md`](../specs/2026-05-28-open-caffeine-design.md)

---

## Prerequisites

Before Task 1, the engineer must install:

```bash
brew install xcodegen swiftlint
```

Xcode 15+ must be installed. `xcodebuild -version` should print Xcode 15.x or 16.x.

All commands below assume the repo root is the current directory:
`cd /Users/sapsaldog/workspace/caffeine`

---

## Task 1: Project scaffolding (XcodeGen + SwiftLint + .gitignore)

**Files:**
- Create: `project.yml`
- Create: `.swiftlint.yml`
- Create: `.gitignore`
- Create: `OpenCaffeine/App/OpenCaffeineApp.swift`
- Create: `OpenCaffeine/App/AppDelegate.swift`
- Create: `OpenCaffeineTests/PlaceholderTest.swift`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
# Xcode
build/
DerivedData/
*.xcuserstate
*.xcuserdatad/
xcuserdata/
OpenCaffeine.xcodeproj/
*.xcworkspace/

# SPM
.swiftpm/
.build/
Package.resolved

# macOS
.DS_Store
```

- [ ] **Step 2: Create `.swiftlint.yml`**

```yaml
included:
  - OpenCaffeine
  - OpenCaffeineTests

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

- [ ] **Step 3: Create `project.yml` for XcodeGen**

```yaml
name: OpenCaffeine
options:
  bundleIdPrefix: com.opencaffeine
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.10"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    PRODUCT_NAME: "Open Caffeine"
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Manual
    DEVELOPMENT_TEAM: ""
    ENABLE_HARDENED_RUNTIME: NO

packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: 2.0.0

targets:
  OpenCaffeine:
    type: application
    platform: macOS
    sources:
      - path: OpenCaffeine
    info:
      path: OpenCaffeine/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: "Open Caffeine"
        CFBundleDisplayName: "Open Caffeine"
        NSHumanReadableCopyright: ""
    dependencies:
      - package: KeyboardShortcuts
    preBuildScripts:
      - name: SwiftLint
        script: |
          if which swiftlint > /dev/null; then
            swiftlint
          else
            echo "warning: SwiftLint not installed (brew install swiftlint)"
          fi
        basedOnDependencyAnalysis: false

  OpenCaffeineTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: OpenCaffeineTests
    dependencies:
      - target: OpenCaffeine

schemes:
  OpenCaffeine:
    build:
      targets:
        OpenCaffeine: all
        OpenCaffeineTests: [test]
    test:
      targets:
        - OpenCaffeineTests
    run:
      config: Debug
    archive:
      config: Release
```

- [ ] **Step 4: Create minimal `OpenCaffeineApp.swift`**

`OpenCaffeine/App/OpenCaffeineApp.swift`:
```swift
import SwiftUI

@main
struct OpenCaffeineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("Preferences coming soon")
                .frame(width: 480, height: 320)
        }
    }
}
```

- [ ] **Step 5: Create minimal `AppDelegate.swift`**

`OpenCaffeine/App/AppDelegate.swift`:
```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bootstrapping will be added in later tasks.
    }
}
```

- [ ] **Step 6: Create placeholder test so the test target compiles**

`OpenCaffeineTests/PlaceholderTest.swift`:
```swift
import XCTest

final class PlaceholderTest: XCTestCase {
    func testTrue() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 7: Generate the Xcode project**

Run: `xcodegen generate`
Expected output: `Generated project successfully` and `OpenCaffeine.xcodeproj` appears.

- [ ] **Step 8: Verify it builds**

Run: `xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet`
Expected: exit code 0, no errors.

- [ ] **Step 9: Verify tests run**

Run: `xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test -quiet`
Expected: `Test Suite 'PlaceholderTest' passed`.

- [ ] **Step 10: Commit**

```bash
git add project.yml .swiftlint.yml .gitignore OpenCaffeine OpenCaffeineTests
git commit -m "chore: scaffold Xcode project with XcodeGen + SwiftLint"
```

---

## Task 2: Menubar icon appears

**Files:**
- Create: `OpenCaffeine/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `OpenCaffeine/Resources/Assets.xcassets/Contents.json`
- Create: `OpenCaffeine/Resources/Assets.xcassets/MenuBarIcon.imageset/Contents.json`
- Create: `OpenCaffeine/Resources/Assets.xcassets/MenuBarIcon.imageset/coffee.pdf` *(placeholder; see Step 2)*
- Modify: `OpenCaffeine/App/AppDelegate.swift`
- Modify: `project.yml` (add Resources to sources — already covered by `path: OpenCaffeine`)

- [ ] **Step 1: Create the assets catalog skeleton**

`OpenCaffeine/Resources/Assets.xcassets/Contents.json`:
```json
{
  "info": { "version": 1, "author": "xcode" }
}
```

`OpenCaffeine/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images": [],
  "info": { "version": 1, "author": "xcode" }
}
```

`OpenCaffeine/Resources/Assets.xcassets/MenuBarIcon.imageset/Contents.json`:
```json
{
  "images": [
    {
      "filename": "coffee.pdf",
      "idiom": "mac"
    }
  ],
  "info": { "version": 1, "author": "xcode" },
  "properties": { "template-rendering-intent": "template" }
}
```

- [ ] **Step 2: Drop in a placeholder template PDF**

For now, generate a 1-line SF Symbol-style placeholder using Preview or by running:
```bash
python3 - <<'PY'
import subprocess
svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 22 22">
<text x="11" y="16" text-anchor="middle" font-size="16" font-family="Helvetica">☕</text>
</svg>'''
open("/tmp/coffee.svg","w").write(svg)
subprocess.run(["rsvg-convert","-f","pdf","-o","OpenCaffeine/Resources/Assets.xcassets/MenuBarIcon.imageset/coffee.pdf","/tmp/coffee.svg"], check=False)
PY
```

If `rsvg-convert` isn't installed, fall back: open Preview → File → New from Clipboard with any 22×22 black PNG → Export As PDF → save to `OpenCaffeine/Resources/Assets.xcassets/MenuBarIcon.imageset/coffee.pdf`. Final coffee artwork is replaced in a later task; this is just a working placeholder.

- [ ] **Step 3: Update `AppDelegate.swift` to create a status item**

Replace contents of `OpenCaffeine/App/AppDelegate.swift`:
```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(named: "MenuBarIcon")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "Open Caffeine"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        for menuItem in menu.items {
            menuItem.target = self
        }
        item.menu = menu
        statusItem = item
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 4: Regenerate the project**

Run: `xcodegen generate`
Expected: `Generated project successfully`.

- [ ] **Step 5: Build and run**

Run: `xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet`
Expected: exit 0.

Run: `open ./build/Debug/Open\ Caffeine.app` *(if build output is elsewhere, use `xcodebuild ... -showBuildSettings | grep TARGET_BUILD_DIR` to locate)*
Expected: a coffee icon appears in the menubar. Clicking it shows a menu with "Quit". Quit terminates the app.

- [ ] **Step 6: Commit**

```bash
git add OpenCaffeine .swiftlint.yml project.yml
git commit -m "feat: show menubar icon with Quit menu"
```

---

## Task 3: `Duration` model (TDD)

**Files:**
- Create: `OpenCaffeine/Models/Duration.swift`
- Create: `OpenCaffeineTests/DurationTests.swift`

- [ ] **Step 1: Write the failing tests**

`OpenCaffeineTests/DurationTests.swift`:
```swift
@testable import OpenCaffeine
import XCTest

final class DurationTests: XCTestCase {
    func testForeverHasNoTimeInterval() {
        XCTAssertNil(CaffeineDuration.forever.timeInterval)
    }

    func testMinutesConvertsToSeconds() {
        XCTAssertEqual(CaffeineDuration.minutes(30).timeInterval, 1800)
        XCTAssertEqual(CaffeineDuration.minutes(5).timeInterval, 300)
    }

    func testHoursConvertsToSeconds() {
        XCTAssertEqual(CaffeineDuration.hours(2).timeInterval, 7200)
    }

    func testCustomSecondsPassThrough() {
        XCTAssertEqual(CaffeineDuration.custom(seconds: 90).timeInterval, 90)
    }

    func testPresetsHaveStableDisplayNames() {
        XCTAssertEqual(CaffeineDuration.minutes(5).displayName, "5 min")
        XCTAssertEqual(CaffeineDuration.minutes(45).displayName, "45 min")
        XCTAssertEqual(CaffeineDuration.hours(1).displayName, "1 hour")
        XCTAssertEqual(CaffeineDuration.hours(12).displayName, "12 hours")
        XCTAssertEqual(CaffeineDuration.forever.displayName, "Forever")
    }

    func testStandardPresetsListMatchesMenu() {
        let names = CaffeineDuration.standardPresets.map(\.displayName)
        XCTAssertEqual(names, [
            "Forever", "5 min", "10 min", "15 min", "30 min", "45 min",
            "1 hour", "2 hours", "4 hours", "6 hours", "12 hours"
        ])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test -quiet 2>&1 | tail -20`
Expected: compilation error — `CaffeineDuration` not found.

- [ ] **Step 3: Implement `CaffeineDuration`**

`OpenCaffeine/Models/Duration.swift`:
```swift
import Foundation

enum CaffeineDuration: Equatable, Hashable {
    case forever
    case minutes(Int)
    case hours(Int)
    case custom(seconds: TimeInterval)

    var timeInterval: TimeInterval? {
        switch self {
        case .forever: return nil
        case .minutes(let m): return TimeInterval(m) * 60
        case .hours(let h): return TimeInterval(h) * 3600
        case .custom(let s): return s
        }
    }

    var displayName: String {
        switch self {
        case .forever: return "Forever"
        case .minutes(let m): return "\(m) min"
        case .hours(1): return "1 hour"
        case .hours(let h): return "\(h) hours"
        case .custom(let s):
            let minutes = Int(s / 60)
            return "Custom (\(minutes) min)"
        }
    }

    static let standardPresets: [CaffeineDuration] = [
        .forever,
        .minutes(5), .minutes(10), .minutes(15), .minutes(30), .minutes(45),
        .hours(1), .hours(2), .hours(4), .hours(6), .hours(12)
    ]
}
```

- [ ] **Step 4: Regenerate, then run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test -quiet
```
Expected: all `DurationTests` pass.

- [ ] **Step 5: Commit**

```bash
git add OpenCaffeine/Models OpenCaffeineTests/DurationTests.swift
git commit -m "feat: add CaffeineDuration model with presets"
```

---

## Task 4: `SessionState` model

**Files:**
- Create: `OpenCaffeine/Models/SessionState.swift`

- [ ] **Step 1: Define the enum**

`OpenCaffeine/Models/SessionState.swift`:
```swift
import Foundation

enum SessionState: Equatable {
    case idle
    case active(duration: CaffeineDuration, startedAt: Date)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    /// Remaining seconds, or `nil` for Forever sessions.
    /// Returns `0` once a finite session has elapsed.
    func remaining(now: Date = Date()) -> TimeInterval? {
        guard case .active(let duration, let startedAt) = self else { return nil }
        guard let total = duration.timeInterval else { return nil }
        let elapsed = now.timeIntervalSince(startedAt)
        return max(0, total - elapsed)
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add OpenCaffeine/Models/SessionState.swift
git commit -m "feat: add SessionState with wall-clock remaining()"
```

---

## Task 5: `SleepAssertionProviding` protocol + real implementation

**Files:**
- Create: `OpenCaffeine/Services/SleepAssertion.swift`

- [ ] **Step 1: Create protocol + real impl**

`OpenCaffeine/Services/SleepAssertion.swift`:
```swift
import Foundation
import IOKit.pwr_mgt
import os.log

protocol SleepAssertionProviding: AnyObject {
    var isActive: Bool { get }
    func acquire() throws
    func release()
}

enum SleepAssertionError: Error {
    case ioReturnFailure(IOReturn)
}

final class SleepAssertion: SleepAssertionProviding {
    private let log = Logger(subsystem: "com.opencaffeine", category: "assertion")
    private let reason: String
    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    private(set) var isActive = false

    init(reason: String = "Open Caffeine keeping system awake") {
        self.reason = reason
    }

    deinit { release() }

    func acquire() throws {
        if isActive { release() }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            log.error("IOPMAssertionCreateWithName failed: \(result, format: .hex)")
            throw SleepAssertionError.ioReturnFailure(result)
        }
        assertionID = id
        isActive = true
        log.notice("Acquired sleep assertion \(id)")
    }

    func release() {
        guard isActive else { return }
        let result = IOPMAssertionRelease(assertionID)
        if result != kIOReturnSuccess {
            log.error("IOPMAssertionRelease failed: \(result, format: .hex)")
        }
        assertionID = 0
        isActive = false
        log.notice("Released sleep assertion")
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add OpenCaffeine/Services/SleepAssertion.swift
git commit -m "feat: add SleepAssertion wrapping IOPMAssertion"
```

---

## Task 6: `CaffeineSession` with TDD (mock assertion)

**Files:**
- Create: `OpenCaffeine/Services/CaffeineSession.swift`
- Create: `OpenCaffeineTests/CaffeineSessionTests.swift`
- Create: `OpenCaffeineTests/Mocks/MockSleepAssertion.swift`

- [ ] **Step 1: Write the mock**

`OpenCaffeineTests/Mocks/MockSleepAssertion.swift`:
```swift
@testable import OpenCaffeine
import Foundation

final class MockSleepAssertion: SleepAssertionProviding {
    private(set) var acquireCount = 0
    private(set) var releaseCount = 0
    var isActive = false
    var acquireError: Error?

    func acquire() throws {
        if let acquireError { throw acquireError }
        if isActive { releaseCount += 1 }
        acquireCount += 1
        isActive = true
    }

    func release() {
        guard isActive else { return }
        releaseCount += 1
        isActive = false
    }
}
```

- [ ] **Step 2: Write the failing tests**

`OpenCaffeineTests/CaffeineSessionTests.swift`:
```swift
@testable import OpenCaffeine
import Combine
import XCTest

final class CaffeineSessionTests: XCTestCase {
    private var assertion: MockSleepAssertion!
    private var session: CaffeineSession!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        assertion = MockSleepAssertion()
        session = CaffeineSession(assertion: assertion)
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testStartsIdle() {
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(assertion.acquireCount, 0)
    }

    func testStartAcquiresAssertion() throws {
        try session.start(.minutes(30))
        XCTAssertTrue(session.state.isActive)
        XCTAssertEqual(assertion.acquireCount, 1)
    }

    func testStopReleasesAssertion() throws {
        try session.start(.minutes(30))
        session.stop()
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(assertion.releaseCount, 1)
    }

    func testDuplicateStartReleasesPriorAssertion() throws {
        try session.start(.minutes(10))
        try session.start(.minutes(20))
        XCTAssertEqual(assertion.acquireCount, 2)
        XCTAssertEqual(assertion.releaseCount, 1)
    }

    func testAcquireFailureLeavesSessionIdle() {
        assertion.acquireError = NSError(domain: "test", code: 1)
        XCTAssertThrowsError(try session.start(.minutes(5)))
        XCTAssertEqual(session.state, .idle)
    }

    func testForeverHasNilRemaining() throws {
        try session.start(.forever)
        XCTAssertNil(session.state.remaining())
    }

    func testFiniteRemainingDecreases() throws {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 1000))
        session = CaffeineSession(assertion: assertion, clock: clock.now)
        try session.start(.minutes(5))
        clock.now = Date(timeIntervalSince1970: 1060) // +60s
        XCTAssertEqual(session.state.remaining(now: clock.now()), 240)
    }

    func testStatePublishedOnStart() throws {
        let exp = expectation(description: "state change")
        session.$state
            .dropFirst()
            .sink { state in
                if state.isActive { exp.fulfill() }
            }
            .store(in: &cancellables)
        try session.start(.minutes(5))
        wait(for: [exp], timeout: 1.0)
    }
}

/// Test helper: mutable clock you can advance by hand.
final class MutableClock {
    var now: Date
    init(now: Date) { self.now = now }
    func now() -> Date { now }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test -quiet 2>&1 | tail -30
```
Expected: compile errors — `CaffeineSession` not defined.

- [ ] **Step 4: Implement `CaffeineSession`**

`OpenCaffeine/Services/CaffeineSession.swift`:
```swift
import Combine
import Foundation
import os.log

final class CaffeineSession: ObservableObject {
    @Published private(set) var state: SessionState = .idle

    private let assertion: SleepAssertionProviding
    private let clock: () -> Date
    private let log = Logger(subsystem: "com.opencaffeine", category: "session")
    private var expiryTimer: Timer?

    enum StopReason {
        case userRequested
        case expired
        case lowBattery
    }

    init(assertion: SleepAssertionProviding, clock: @escaping () -> Date = Date.init) {
        self.assertion = assertion
        self.clock = clock
    }

    deinit { stop(reason: .userRequested) }

    func start(_ duration: CaffeineDuration) throws {
        try assertion.acquire()
        let newState = SessionState.active(duration: duration, startedAt: clock())
        state = newState
        scheduleExpiry(for: duration)
        log.notice("Session started: \(duration.displayName, privacy: .public)")
    }

    func stop(reason: StopReason = .userRequested) {
        guard state.isActive else { return }
        expiryTimer?.invalidate()
        expiryTimer = nil
        assertion.release()
        state = .idle
        log.notice("Session stopped: \(String(describing: reason), privacy: .public)")
    }

    private func scheduleExpiry(for duration: CaffeineDuration) {
        expiryTimer?.invalidate()
        expiryTimer = nil
        guard let interval = duration.timeInterval else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.stop(reason: .expired)
        }
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }
}
```

- [ ] **Step 5: Regenerate, then run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test -quiet
```
Expected: all `CaffeineSessionTests` pass.

- [ ] **Step 6: Commit**

```bash
git add OpenCaffeine/Services/CaffeineSession.swift OpenCaffeineTests
git commit -m "feat: add CaffeineSession with TDD coverage"
```

---

## Task 7: `CountdownFormatter` (TDD)

**Files:**
- Create: `OpenCaffeine/MenuBar/CountdownFormatter.swift`
- Create: `OpenCaffeineTests/CountdownFormatterTests.swift`

- [ ] **Step 1: Write the failing tests**

`OpenCaffeineTests/CountdownFormatterTests.swift`:
```swift
@testable import OpenCaffeine
import XCTest

final class CountdownFormatterTests: XCTestCase {
    func testZeroFormatsAsMinSec() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 0), "0:00")
    }

    func testUnderOneHourUsesMinSec() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 59), "0:59")
        XCTAssertEqual(CountdownFormatter.string(remaining: 90), "1:30")
        XCTAssertEqual(CountdownFormatter.string(remaining: 3599), "59:59")
    }

    func testAtOrAboveOneHourUsesHourMinSec() {
        XCTAssertEqual(CountdownFormatter.string(remaining: 3600), "1:00:00")
        XCTAssertEqual(CountdownFormatter.string(remaining: 3661), "1:01:01")
        XCTAssertEqual(CountdownFormatter.string(remaining: 43200), "12:00:00")
    }

    func testNilReturnsInfinity() {
        XCTAssertEqual(CountdownFormatter.string(remaining: nil), "∞")
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test -quiet 2>&1 | tail -10
```
Expected: `CountdownFormatter` not defined.

- [ ] **Step 3: Implement**

`OpenCaffeine/MenuBar/CountdownFormatter.swift`:
```swift
import Foundation

enum CountdownFormatter {
    static func string(remaining: TimeInterval?) -> String {
        guard let remaining else { return "∞" }
        let total = Int(remaining.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test -quiet
```
Expected: all `CountdownFormatterTests` pass.

- [ ] **Step 5: Commit**

```bash
git add OpenCaffeine/MenuBar OpenCaffeineTests/CountdownFormatterTests.swift
git commit -m "feat: add CountdownFormatter with TDD coverage"
```

---

## Task 8: `AppSettings` with `@AppStorage`

**Files:**
- Create: `OpenCaffeine/Settings/AppSettings.swift`
- Create: `OpenCaffeine/Models/MenuBarIconStyle.swift`

- [ ] **Step 1: Add the icon style enum**

`OpenCaffeine/Models/MenuBarIconStyle.swift`:
```swift
import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case coffeeType1
    case coffeeType2
    case coffeeType3

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coffeeType1: return "Coffee Type 1"
        case .coffeeType2: return "Coffee Type 2"
        case .coffeeType3: return "Coffee Type 3"
        }
    }

    /// Asset name for the idle state. Active state appends "Active".
    var idleAssetName: String {
        switch self {
        case .coffeeType1: return "MenuBarIcon"
        case .coffeeType2: return "MenuBarIcon2"
        case .coffeeType3: return "MenuBarIcon3"
        }
    }

    var activeAssetName: String { idleAssetName + "Active" }
}
```

- [ ] **Step 2: Add the settings store**

`OpenCaffeine/Settings/AppSettings.swift`:
```swift
import Combine
import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let iconStyle = "iconStyle"
        static let startAtLogin = "startAtLogin"
        static let showIconInDock = "showIconInDock"
        static let showInstructionMessage = "showInstructionMessage"
        static let showCountdown = "showCountdown"
        static let defaultDurationSeconds = "defaultDurationSeconds"
        static let sleepBelowBatteryPercent = "sleepBelowBatteryPercent"
        static let didShowInstructionMessage = "didShowInstructionMessage"
    }

    @AppStorage(Key.iconStyle) var iconStyleRaw: String = MenuBarIconStyle.coffeeType1.rawValue
    @AppStorage(Key.startAtLogin) var startAtLogin: Bool = false
    @AppStorage(Key.showIconInDock) var showIconInDock: Bool = false
    @AppStorage(Key.showInstructionMessage) var showInstructionMessage: Bool = false
    @AppStorage(Key.showCountdown) var showCountdown: Bool = true
    /// `-1` means Forever. Other values are seconds.
    @AppStorage(Key.defaultDurationSeconds) var defaultDurationSeconds: Int = -1
    /// `0` means disabled (no automatic stop on low battery).
    @AppStorage(Key.sleepBelowBatteryPercent) var sleepBelowBatteryPercent: Int = 0
    @AppStorage(Key.didShowInstructionMessage) var didShowInstructionMessage: Bool = false

    var iconStyle: MenuBarIconStyle {
        get { MenuBarIconStyle(rawValue: iconStyleRaw) ?? .coffeeType1 }
        set { iconStyleRaw = newValue.rawValue }
    }

    var defaultDuration: CaffeineDuration {
        get {
            if defaultDurationSeconds < 0 { return .forever }
            return .custom(seconds: TimeInterval(defaultDurationSeconds))
        }
        set {
            defaultDurationSeconds = newValue.timeInterval.map { Int($0) } ?? -1
        }
    }
}
```

- [ ] **Step 3: Build to confirm it compiles**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add OpenCaffeine/Settings OpenCaffeine/Models/MenuBarIconStyle.swift
git commit -m "feat: add AppSettings store and MenuBarIconStyle"
```

---

## Task 9: `MenuBuilder` + `MenuBarController`

**Files:**
- Create: `OpenCaffeine/MenuBar/MenuBuilder.swift`
- Create: `OpenCaffeine/MenuBar/MenuBarController.swift`
- Modify: `OpenCaffeine/App/AppDelegate.swift`

- [ ] **Step 1: Implement `MenuBuilder`**

`OpenCaffeine/MenuBar/MenuBuilder.swift`:
```swift
import AppKit

@MainActor
final class MenuBuilder {
    weak var target: AnyObject?
    var startAction: Selector?
    var screensaverAction: Selector?
    var preferencesAction: Selector?
    var aboutAction: Selector?
    var quitAction: Selector?

    func build(currentDuration: CaffeineDuration?) -> NSMenu {
        let menu = NSMenu()

        let startItem = NSMenuItem(title: "Start Caffeine for", action: nil, keyEquivalent: "")
        startItem.submenu = makeDurationSubmenu(current: currentDuration)
        menu.addItem(startItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem(title: "Start Screensaver", action: screensaverAction))
        menu.addItem(makeItem(title: "Preferences…", action: preferencesAction, key: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem(title: "About Open Caffeine", action: aboutAction))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem(title: "Quit", action: quitAction, key: "q"))
        return menu
    }

    private func makeDurationSubmenu(current: CaffeineDuration?) -> NSMenu {
        let submenu = NSMenu()
        for preset in CaffeineDuration.standardPresets {
            let item = NSMenuItem(title: preset.displayName, action: startAction, keyEquivalent: "")
            item.representedObject = preset
            item.target = target
            if let current, current == preset { item.state = .on }
            submenu.addItem(item)
        }
        submenu.addItem(NSMenuItem.separator())
        let custom = NSMenuItem(title: "Custom…", action: startAction, keyEquivalent: "")
        custom.representedObject = "custom"
        custom.target = target
        submenu.addItem(custom)
        return submenu
    }

    private func makeItem(title: String, action: Selector?, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }
}
```

- [ ] **Step 2: Implement `MenuBarController`**

`OpenCaffeine/MenuBar/MenuBarController.swift`:
```swift
import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let session: CaffeineSession
    private let settings: AppSettings
    private let statusItem: NSStatusItem
    private let builder = MenuBuilder()
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTimer: Timer?

    var onPreferences: (() -> Void)?
    var onAbout: (() -> Void)?
    var onStartScreensaver: (() -> Void)?
    var onCustomDurationRequested: (() -> Void)?

    init(session: CaffeineSession, settings: AppSettings) {
        self.session = session
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureBuilder()
        refreshMenu()
        observeSession()
        refreshIcon()
    }

    private func configureBuilder() {
        builder.target = self
        builder.startAction = #selector(handleStart(_:))
        builder.screensaverAction = #selector(handleScreensaver)
        builder.preferencesAction = #selector(handlePreferences)
        builder.aboutAction = #selector(handleAbout)
        builder.quitAction = #selector(handleQuit)
    }

    private func observeSession() {
        session.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshIcon()
                self?.refreshMenu()
                self?.scheduleTickIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func scheduleTickIfNeeded() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard session.state.isActive,
              session.state.remaining() != nil,
              settings.showCountdown else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshIcon() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let style = settings.iconStyle
        let assetName = session.state.isActive ? style.activeAssetName : style.idleAssetName
        let image = NSImage(named: assetName) ?? NSImage(named: style.idleAssetName)
        image?.isTemplate = true
        button.image = image
        if session.state.isActive, settings.showCountdown {
            button.title = " " + CountdownFormatter.string(remaining: session.state.remaining())
        } else {
            button.title = ""
        }
    }

    private func refreshMenu() {
        let current: CaffeineDuration?
        if case .active(let duration, _) = session.state { current = duration } else { current = nil }
        statusItem.menu = builder.build(currentDuration: current)
    }

    @objc private func handleStart(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? CaffeineDuration {
            try? session.start(preset)
            return
        }
        if sender.representedObject as? String == "custom" {
            onCustomDurationRequested?()
        }
    }

    @objc private func handleScreensaver() { onStartScreensaver?() }
    @objc private func handlePreferences() { onPreferences?() }
    @objc private func handleAbout() { onAbout?() }
    @objc private func handleQuit() { NSApp.terminate(nil) }
}
```

- [ ] **Step 3: Wire it up in `AppDelegate`**

Replace `OpenCaffeine/App/AppDelegate.swift`:
```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let assertion = SleepAssertion()
    private(set) lazy var session = CaffeineSession(assertion: assertion)
    private let settings = AppSettings.shared
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MenuBarController(session: session, settings: settings)
        controller.onPreferences = { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
        controller.onAbout = { NSApp.orderFrontStandardAboutPanel(nil) }
        controller.onStartScreensaver = { /* wired in a later task */ }
        controller.onCustomDurationRequested = { /* wired in a later task */ }
        menuBar = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stop()
    }
}
```

- [ ] **Step 4: Build & launch**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```
Then launch from `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/Open Caffeine.app`.

Expected: clicking the menubar icon shows `Start Caffeine for ▶`, `Start Screensaver`, `Preferences…`, `About Open Caffeine`, `Quit`. Hovering `Start Caffeine for` shows preset durations. Clicking "5 min" makes the icon switch to active (placeholder asset for now) and the countdown appears next to the icon. After 5 minutes it auto-stops. Quit terminates.

- [ ] **Step 5: Commit**

```bash
git add OpenCaffeine/App OpenCaffeine/MenuBar
git commit -m "feat: wire menubar menu to CaffeineSession"
```

---

## Task 10: `PreferencesScene` + `GeneralSettingsView`

**Files:**
- Create: `OpenCaffeine/Settings/PreferencesScene.swift`
- Create: `OpenCaffeine/Settings/GeneralSettingsView.swift`
- Modify: `OpenCaffeine/App/OpenCaffeineApp.swift`

- [ ] **Step 1: Implement `PreferencesScene`**

`OpenCaffeine/Settings/PreferencesScene.swift`:
```swift
import SwiftUI

struct PreferencesScene: View {
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 520, height: 360)
    }
}
```

- [ ] **Step 2: Implement `GeneralSettingsView` (Appearance + toggles)**

`OpenCaffeine/Settings/GeneralSettingsView.swift`:
```swift
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle("Start at login", isOn: $settings.startAtLogin)
                Toggle("Show icon in dock", isOn: $settings.showIconInDock)
                Toggle("Show instruction message when Open Caffeine opens",
                       isOn: $settings.showInstructionMessage)
            }
        }
        .padding(20)
        .formStyle(.grouped)
    }

    private var appearanceBinding: Binding<MenuBarIconStyle> {
        Binding(
            get: { settings.iconStyle },
            set: { settings.iconStyle = $0 }
        )
    }
}
```

- [ ] **Step 3: Mount the new scene**

Replace `OpenCaffeine/App/OpenCaffeineApp.swift`:
```swift
import SwiftUI

@main
struct OpenCaffeineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesScene()
        }
    }
}
```

- [ ] **Step 4: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

Launch the app, click menubar → Preferences. Expected: window opens showing the General tab with appearance picker and three toggles. The appearance picker shows three coffee-type options.

- [ ] **Step 5: Commit**

```bash
git add OpenCaffeine/App/OpenCaffeineApp.swift OpenCaffeine/Settings
git commit -m "feat: add Preferences window with General tab"
```

---

## Task 11: `LoginItemManager` (Start at login)

**Files:**
- Create: `OpenCaffeine/Services/LoginItemManager.swift`
- Modify: `OpenCaffeine/Settings/GeneralSettingsView.swift`
- Modify: `OpenCaffeine/App/AppDelegate.swift`

- [ ] **Step 1: Implement the manager**

`OpenCaffeine/Services/LoginItemManager.swift`:
```swift
import Foundation
import ServiceManagement
import os.log

@MainActor
final class LoginItemManager {
    private let log = Logger(subsystem: "com.opencaffeine", category: "loginitem")
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var isEnabled: Bool { service.status == .enabled }

    func sync(enabled: Bool) {
        do {
            if enabled, service.status != .enabled {
                try service.register()
                log.notice("Registered as login item")
            } else if !enabled, service.status == .enabled {
                try service.unregister()
                log.notice("Unregistered login item")
            }
        } catch {
            log.error("Login item update failed: \(String(describing: error), privacy: .public)")
        }
    }
}
```

- [ ] **Step 2: Sync on toggle from `GeneralSettingsView`**

In `OpenCaffeine/Settings/GeneralSettingsView.swift`, replace the `Toggle("Start at login"...)` line and add a manager:

```swift
struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    let loginItem: LoginItemManager

    var body: some View {
        Form {
            // … Appearance section unchanged …

            Section {
                Toggle("Start at login", isOn: startAtLoginBinding)
                Toggle("Show icon in dock", isOn: $settings.showIconInDock)
                Toggle("Show instruction message when Open Caffeine opens",
                       isOn: $settings.showInstructionMessage)
            }
        }
        .padding(20)
        .formStyle(.grouped)
    }

    private var appearanceBinding: Binding<MenuBarIconStyle> {
        Binding(
            get: { settings.iconStyle },
            set: { settings.iconStyle = $0 }
        )
    }

    private var startAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.startAtLogin },
            set: { newValue in
                settings.startAtLogin = newValue
                loginItem.sync(enabled: newValue)
            }
        )
    }
}
```

And update `PreferencesScene` to inject the manager:
```swift
struct PreferencesScene: View {
    @StateObject private var settings = AppSettings.shared
    private let loginItem = LoginItemManager()

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings, loginItem: loginItem)
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 520, height: 360)
    }
}
```

- [ ] **Step 3: Reconcile state on launch**

In `AppDelegate.applicationDidFinishLaunching`, after creating the controller, add:
```swift
let loginItem = LoginItemManager()
loginItem.sync(enabled: settings.startAtLogin)
```

- [ ] **Step 4: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

Manually: open Preferences → toggle "Start at login" on → run `osascript -e 'tell application "System Events" to get the name of every login item'` (or check System Settings → General → Login Items). Expected: "Open Caffeine" appears. Toggle off, re-check.

- [ ] **Step 5: Commit**

```bash
git add OpenCaffeine/Services/LoginItemManager.swift OpenCaffeine/Settings OpenCaffeine/App/AppDelegate.swift
git commit -m "feat: wire Start at login via SMAppService"
```

---

## Task 12: Show icon in dock (LSUIElement runtime toggle)

**Files:**
- Modify: `OpenCaffeine/App/AppDelegate.swift`
- Modify: `OpenCaffeine/Settings/GeneralSettingsView.swift`

- [ ] **Step 1: Add an activation helper to `AppDelegate`**

Add a method on `AppDelegate`:
```swift
func applyDockVisibility(_ visible: Bool) {
    let policy: NSApplication.ActivationPolicy = visible ? .regular : .accessory
    NSApp.setActivationPolicy(policy)
}
```

Call it once during launch after the menubar is set up:
```swift
applyDockVisibility(settings.showIconInDock)
```

- [ ] **Step 2: Drive it from the toggle**

In `GeneralSettingsView`, change the dock toggle to use a binding that applies the policy. First, give the view a reference to a callback:

```swift
struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    let loginItem: LoginItemManager
    let onDockVisibilityChange: (Bool) -> Void
    // ...
    private var showInDockBinding: Binding<Bool> {
        Binding(
            get: { settings.showIconInDock },
            set: { newValue in
                settings.showIconInDock = newValue
                onDockVisibilityChange(newValue)
            }
        )
    }
}
```

Replace `Toggle("Show icon in dock", isOn: $settings.showIconInDock)` with `Toggle("Show icon in dock", isOn: showInDockBinding)`.

In `PreferencesScene`, pass it in:
```swift
struct PreferencesScene: View {
    @StateObject private var settings = AppSettings.shared
    private let loginItem = LoginItemManager()
    let onDockVisibilityChange: (Bool) -> Void

    var body: some View {
        TabView {
            GeneralSettingsView(
                settings: settings,
                loginItem: loginItem,
                onDockVisibilityChange: onDockVisibilityChange
            )
            .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 520, height: 360)
    }
}
```

In `OpenCaffeineApp.swift`, capture the delegate:
```swift
@main
struct OpenCaffeineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesScene(onDockVisibilityChange: { [appDelegate] visible in
                appDelegate.applyDockVisibility(visible)
            })
        }
    }
}
```

- [ ] **Step 3: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

Toggle "Show icon in dock" on/off — expect the Dock icon to appear/disappear instantly.

- [ ] **Step 4: Commit**

```bash
git add OpenCaffeine/App OpenCaffeine/Settings
git commit -m "feat: toggle dock icon via activation policy"
```

---

## Task 13: Real coffee icons (3 styles, idle + active)

**Files:**
- Create: 6 `.pdf` files under `OpenCaffeine/Resources/Assets.xcassets/`
- Create: 5 new `imageset/Contents.json` files

For each style, you need:
`MenuBarIcon.imageset/`, `MenuBarIconActive.imageset/`, `MenuBarIcon2.imageset/`, `MenuBarIcon2Active.imageset/`, `MenuBarIcon3.imageset/`, `MenuBarIcon3Active.imageset/`.

- [ ] **Step 1: Source artwork**

Pick or draw three 22×22 template-rendering coffee icons (variants: empty cup, half-full, full-with-steam are common). Each style needs an "idle" and an "active" variant. Public-domain options: Apple SF Symbols `cup.and.saucer`, `mug`, `takeoutbag.and.cup.and.straw`. To export an SF Symbol as a template PDF:

```bash
# In SF Symbols.app: select symbol → File → Export Symbol… → choose
# "Custom Symbol Template" (SVG). Then convert to PDF:
rsvg-convert -f pdf -o coffee_type1.pdf coffee_type1.svg
```

Save the six PDFs into the matching `imageset` folders. The "active" variants should be visually distinguishable (e.g., filled vs. outline, or with a small ring).

- [ ] **Step 2: Create `Contents.json` for each new imageset**

For each new `*.imageset/Contents.json` (substitute the filename):
```json
{
  "images": [
    { "filename": "coffee_type1.pdf", "idiom": "mac" }
  ],
  "info": { "version": 1, "author": "xcode" },
  "properties": { "template-rendering-intent": "template" }
}
```

Repeat for `MenuBarIconActive`, `MenuBarIcon2`, `MenuBarIcon2Active`, `MenuBarIcon3`, `MenuBarIcon3Active`.

- [ ] **Step 3: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

Manually: open Preferences → switch Appearance between Coffee Type 1/2/3 → expect the menubar icon to change immediately. Start a session → expect the "Active" variant of the current style.

To make appearance changes flow into `MenuBarController`, ensure `MenuBarController` observes `settings.objectWillChange`. Add this in `MenuBarController.init`, after `observeSession()`:
```swift
settings.objectWillChange
    .receive(on: RunLoop.main)
    .sink { [weak self] _ in self?.refreshIcon() }
    .store(in: &cancellables)
```

- [ ] **Step 4: Commit**

```bash
git add OpenCaffeine/Resources OpenCaffeine/MenuBar/MenuBarController.swift
git commit -m "feat: add coffee icon styles 1-3 with active variants"
```

---

## Task 14: `DurationSettingsView` (default duration + countdown toggle + battery placeholder)

**Files:**
- Create: `OpenCaffeine/Settings/DurationSettingsView.swift`
- Modify: `OpenCaffeine/Settings/PreferencesScene.swift`

- [ ] **Step 1: Implement the view**

`OpenCaffeine/Settings/DurationSettingsView.swift`:
```swift
import SwiftUI

struct DurationSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Show countdown", isOn: $settings.showCountdown)
                Picker("Default duration", selection: defaultDurationBinding) {
                    ForEach(CaffeineDuration.standardPresets, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Battery") {
                BatteryThresholdRow(settings: settings)
            }
        }
        .padding(20)
        .formStyle(.grouped)
    }

    private var defaultDurationBinding: Binding<CaffeineDuration> {
        Binding(
            get: { settings.defaultDuration },
            set: { settings.defaultDuration = $0 }
        )
    }
}

private struct BatteryThresholdRow: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Allow sleep if battery gets below:")
                Spacer()
                Text(settings.sleepBelowBatteryPercent == 0
                     ? "Disabled"
                     : "\(settings.sleepBelowBatteryPercent)%")
                    .foregroundStyle(.secondary)
            }
            Slider(value: percentBinding, in: 0...50, step: 5)
        }
    }

    private var percentBinding: Binding<Double> {
        Binding(
            get: { Double(settings.sleepBelowBatteryPercent) },
            set: { settings.sleepBelowBatteryPercent = Int($0) }
        )
    }
}
```

- [ ] **Step 2: Add the tab in `PreferencesScene`**

```swift
struct PreferencesScene: View {
    @StateObject private var settings = AppSettings.shared
    private let loginItem = LoginItemManager()
    let onDockVisibilityChange: (Bool) -> Void

    var body: some View {
        TabView {
            GeneralSettingsView(
                settings: settings,
                loginItem: loginItem,
                onDockVisibilityChange: onDockVisibilityChange
            )
            .tabItem { Label("General", systemImage: "gear") }

            DurationSettingsView(settings: settings)
                .tabItem { Label("Duration & Battery", systemImage: "clock") }
        }
        .frame(width: 520, height: 360)
    }
}
```

- [ ] **Step 3: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

Open Preferences → second tab "Duration & Battery". Expected: countdown toggle, default duration picker (with all standard presets), battery slider showing "Disabled" at 0.

- [ ] **Step 4: Commit**

```bash
git add OpenCaffeine/Settings
git commit -m "feat: add Duration & Battery preferences tab"
```

---

## Task 15: Custom duration dialog

**Files:**
- Create: `OpenCaffeine/MenuBar/CustomDurationPrompt.swift`
- Modify: `OpenCaffeine/App/AppDelegate.swift`

- [ ] **Step 1: Implement a simple NSAlert-based prompt**

`OpenCaffeine/MenuBar/CustomDurationPrompt.swift`:
```swift
import AppKit

@MainActor
enum CustomDurationPrompt {
    static func ask() -> CaffeineDuration? {
        let alert = NSAlert()
        alert.messageText = "Custom Duration"
        alert.informativeText = "How many minutes should Open Caffeine keep your Mac awake?"
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = "60"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        guard let minutes = Int(input.stringValue), minutes > 0 else { return nil }
        return .minutes(minutes)
    }
}
```

- [ ] **Step 2: Wire it up in `AppDelegate`**

In `applicationDidFinishLaunching`, replace the `onCustomDurationRequested` placeholder:
```swift
controller.onCustomDurationRequested = { [weak self] in
    guard let self else { return }
    if let duration = CustomDurationPrompt.ask() {
        try? self.session.start(duration)
    }
}
```

- [ ] **Step 3: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

Click menubar → Start Caffeine for → Custom… → enter `2` → Start. Expected: session starts for 2 minutes.

- [ ] **Step 4: Commit**

```bash
git add OpenCaffeine/MenuBar/CustomDurationPrompt.swift OpenCaffeine/App/AppDelegate.swift
git commit -m "feat: prompt for custom duration"
```

---

## Task 16: `HotKeyService` with KeyboardShortcuts

**Files:**
- Create: `OpenCaffeine/Services/HotKeyService.swift`
- Modify: `OpenCaffeine/App/AppDelegate.swift`

- [ ] **Step 1: Implement the service**

`OpenCaffeine/Services/HotKeyService.swift`:
```swift
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleCaffeine = Self("toggleCaffeine")
}

@MainActor
final class HotKeyService {
    private let session: CaffeineSession
    private let settings: AppSettings

    init(session: CaffeineSession, settings: AppSettings) {
        self.session = session
        self.settings = settings
        KeyboardShortcuts.onKeyDown(for: .toggleCaffeine) { [weak self] in
            self?.toggle()
        }
    }

    func toggle() {
        if session.state.isActive {
            session.stop()
        } else {
            try? session.start(settings.defaultDuration)
        }
    }
}
```

- [ ] **Step 2: Bootstrap in `AppDelegate`**

In `applicationDidFinishLaunching`, after creating `MenuBarController`:
```swift
let hotKey = HotKeyService(session: session, settings: settings)
self.hotKey = hotKey
```

Add a stored property on `AppDelegate`:
```swift
private var hotKey: HotKeyService?
```

- [ ] **Step 3: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

No hotkey is configured yet; this will be addressed in the next task. Build should succeed.

- [ ] **Step 4: Commit**

```bash
git add OpenCaffeine/Services/HotKeyService.swift OpenCaffeine/App/AppDelegate.swift
git commit -m "feat: add HotKeyService backed by KeyboardShortcuts"
```

---

## Task 17: Hotkey recorder UI in Preferences

**Files:**
- Create: `OpenCaffeine/Settings/HotKeyRecorderRow.swift`
- Modify: `OpenCaffeine/Settings/GeneralSettingsView.swift`

- [ ] **Step 1: Implement the recorder row**

`OpenCaffeine/Settings/HotKeyRecorderRow.swift`:
```swift
import KeyboardShortcuts
import SwiftUI

struct HotKeyRecorderRow: View {
    var body: some View {
        HStack {
            Text("Activate with hot key:")
            Spacer()
            KeyboardShortcuts.Recorder(for: .toggleCaffeine)
        }
    }
}
```

- [ ] **Step 2: Insert into `GeneralSettingsView`**

Add a section above the toggles:
```swift
Section {
    HotKeyRecorderRow()
}
```

- [ ] **Step 3: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

Open Preferences → General → click the recorder field → press `⌘⌥C`. Close Preferences, press `⌘⌥C` from any app. Expected: caffeine session starts. Press again to stop.

- [ ] **Step 4: Commit**

```bash
git add OpenCaffeine/Settings
git commit -m "feat: add hotkey recorder to Preferences"
```

---

## Task 18: `BatteryMonitor` (TDD)

**Files:**
- Create: `OpenCaffeine/Services/BatteryMonitor.swift`
- Create: `OpenCaffeineTests/BatteryMonitorTests.swift`

The monitor is split into two layers so the threshold logic can be tested without IOKit:

1. `BatteryProvider` protocol returning `(hasBattery: Bool, percent: Int)`.
2. `BatteryMonitor` holding a provider and a threshold callback.

- [ ] **Step 1: Write failing tests**

`OpenCaffeineTests/BatteryMonitorTests.swift`:
```swift
@testable import OpenCaffeine
import XCTest

final class BatteryMonitorTests: XCTestCase {
    func testNoCallbackWhenDisabled() {
        let provider = FakeBatteryProvider(hasBattery: true, percent: 5)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 0 }) { fired = true }
        monitor.evaluate()
        XCTAssertFalse(fired)
    }

    func testCallbackFiresBelowThreshold() {
        let provider = FakeBatteryProvider(hasBattery: true, percent: 9)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 10 }) { fired = true }
        monitor.evaluate()
        XCTAssertTrue(fired)
    }

    func testCallbackDoesNotFireAboveThreshold() {
        let provider = FakeBatteryProvider(hasBattery: true, percent: 25)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 10 }) { fired = true }
        monitor.evaluate()
        XCTAssertFalse(fired)
    }

    func testCallbackNeverFiresWithoutBattery() {
        let provider = FakeBatteryProvider(hasBattery: false, percent: 0)
        var fired = false
        let monitor = BatteryMonitor(provider: provider, threshold: { 20 }) { fired = true }
        monitor.evaluate()
        XCTAssertFalse(fired)
    }
}

final class FakeBatteryProvider: BatteryProvider {
    var hasBattery: Bool
    var percent: Int
    init(hasBattery: Bool, percent: Int) {
        self.hasBattery = hasBattery
        self.percent = percent
    }
    func currentBattery() -> (hasBattery: Bool, percent: Int) {
        (hasBattery, percent)
    }
}
```

- [ ] **Step 2: Run, expect failure**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test -quiet 2>&1 | tail -20
```
Expected: `BatteryMonitor` / `BatteryProvider` not defined.

- [ ] **Step 3: Implement**

`OpenCaffeine/Services/BatteryMonitor.swift`:
```swift
import Foundation
import IOKit.ps
import os.log

protocol BatteryProvider {
    func currentBattery() -> (hasBattery: Bool, percent: Int)
}

struct SystemBatteryProvider: BatteryProvider {
    func currentBattery() -> (hasBattery: Bool, percent: Int) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                as? [String: AnyObject] else { continue }
            if let max = desc[kIOPSMaxCapacityKey] as? Int,
               let current = desc[kIOPSCurrentCapacityKey] as? Int,
               max > 0 {
                return (true, Int((Double(current) / Double(max)) * 100))
            }
        }
        return (false, 0)
    }
}

final class BatteryMonitor {
    private let log = Logger(subsystem: "com.opencaffeine", category: "battery")
    private let provider: BatteryProvider
    private let threshold: () -> Int
    private let onLow: () -> Void
    private var runLoopSource: CFRunLoopSource?

    init(
        provider: BatteryProvider = SystemBatteryProvider(),
        threshold: @escaping () -> Int,
        onLow: @escaping () -> Void
    ) {
        self.provider = provider
        self.threshold = threshold
        self.onLow = onLow
    }

    deinit { stopObserving() }

    /// Called synchronously by tests and by the IOPS callback (which already runs on the main runloop).
    func evaluate() {
        let snapshot = provider.currentBattery()
        let limit = threshold()
        guard limit > 0, snapshot.hasBattery, snapshot.percent < limit else { return }
        onLow()
    }

    func startObserving() {
        stopObserving()
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.evaluate()
        }, context).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
    }

    func stopObserving() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        runLoopSource = nil
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test -quiet
```
Expected: `BatteryMonitorTests` all pass.

- [ ] **Step 5: Wire into `AppDelegate`**

In `applicationDidFinishLaunching`, after `HotKeyService` setup:
```swift
let monitor = BatteryMonitor(
    threshold: { [settings] in settings.sleepBelowBatteryPercent },
    onLow: { [weak self] in self?.session.stop(reason: .lowBattery) }
)
monitor.startObserving()
self.batteryMonitor = monitor
```

Add a stored property:
```swift
private var batteryMonitor: BatteryMonitor?
```

- [ ] **Step 6: Commit**

```bash
git add OpenCaffeine/Services/BatteryMonitor.swift OpenCaffeine/App/AppDelegate.swift OpenCaffeineTests
git commit -m "feat: add BatteryMonitor with TDD coverage"
```

---

## Task 19: Battery row reflects "No battery detected"

**Files:**
- Modify: `OpenCaffeine/Settings/DurationSettingsView.swift`

- [ ] **Step 1: Detect battery at row level**

Replace `BatteryThresholdRow` body:
```swift
private struct BatteryThresholdRow: View {
    @ObservedObject var settings: AppSettings
    private let provider: BatteryProvider = SystemBatteryProvider()

    var body: some View {
        let snapshot = provider.currentBattery()
        VStack(alignment: .leading) {
            HStack {
                Text("Allow sleep if battery gets below:")
                Spacer()
                Text(label(for: snapshot))
                    .foregroundStyle(.secondary)
            }
            Slider(value: percentBinding, in: 0...50, step: 5)
                .disabled(!snapshot.hasBattery)
            if !snapshot.hasBattery {
                Text("No battery detected").foregroundStyle(.red)
            }
        }
    }

    private func label(for snapshot: (hasBattery: Bool, percent: Int)) -> String {
        if !snapshot.hasBattery { return "—" }
        return settings.sleepBelowBatteryPercent == 0
            ? "Disabled"
            : "\(settings.sleepBelowBatteryPercent)%"
    }

    private var percentBinding: Binding<Double> {
        Binding(
            get: { Double(settings.sleepBelowBatteryPercent) },
            set: { settings.sleepBelowBatteryPercent = Int($0) }
        )
    }
}
```

- [ ] **Step 2: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

On a MacBook, expected: slider enabled, label shows "Disabled" / `XX%`. On a desktop Mac (or after unplugging battery in simulator-like setups), the slider is disabled and "No battery detected" appears in red.

- [ ] **Step 3: Commit**

```bash
git add OpenCaffeine/Settings/DurationSettingsView.swift
git commit -m "feat: disable battery slider when no battery present"
```

---

## Task 20: `ScreenSaverLauncher`

**Files:**
- Create: `OpenCaffeine/Services/ScreenSaverLauncher.swift`
- Modify: `OpenCaffeine/App/AppDelegate.swift`

- [ ] **Step 1: Implement the launcher**

`OpenCaffeine/Services/ScreenSaverLauncher.swift`:
```swift
import AppKit
import os.log

@MainActor
enum ScreenSaverLauncher {
    private static let log = Logger(subsystem: "com.opencaffeine", category: "screensaver")

    static func launch() {
        let url = URL(
            fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"
        )
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                log.error("ScreenSaver launch failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
```

- [ ] **Step 2: Wire into `AppDelegate`**

```swift
controller.onStartScreensaver = { ScreenSaverLauncher.launch() }
```

- [ ] **Step 3: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

Menubar → Start Screensaver. Expected: the system screensaver starts immediately.

- [ ] **Step 4: Commit**

```bash
git add OpenCaffeine/Services/ScreenSaverLauncher.swift OpenCaffeine/App/AppDelegate.swift
git commit -m "feat: launch ScreenSaverEngine from menu"
```

---

## Task 21: About panel + first-launch instruction message

**Files:**
- Create: `OpenCaffeine/Resources/AboutPanel.swift`
- Modify: `OpenCaffeine/App/AppDelegate.swift`

- [ ] **Step 1: Implement a custom About panel**

`OpenCaffeine/Resources/AboutPanel.swift`:
```swift
import AppKit

@MainActor
enum AboutPanel {
    static func show() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let credits = NSAttributedString(
            string: "An open-source tool that helps keep your Mac awake.",
            attributes: [.foregroundColor: NSColor.labelColor]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Open Caffeine",
            .applicationVersion: version,
            .credits: credits
        ])
    }
}
```

- [ ] **Step 2: Wire it up**

In `AppDelegate.applicationDidFinishLaunching`, replace `controller.onAbout` with:
```swift
controller.onAbout = { AboutPanel.show() }
```

- [ ] **Step 3: First-launch instruction message**

Append at the end of `applicationDidFinishLaunching`:
```swift
if settings.showInstructionMessage, !settings.didShowInstructionMessage {
    let alert = NSAlert()
    alert.messageText = "Open Caffeine is running in your menubar"
    alert.informativeText = """
    Click the coffee icon to start a session.
    Set a hotkey in Preferences for one-press toggle.
    """
    alert.addButton(withTitle: "OK")
    alert.runModal()
    settings.didShowInstructionMessage = true
}
```

- [ ] **Step 4: Build & verify**

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build -quiet
```

Toggle "Show instruction message" on, delete the app's defaults (`defaults delete com.opencaffeine.OpenCaffeine didShowInstructionMessage`), relaunch. Expected: instruction alert appears once. About menu shows custom panel.

- [ ] **Step 5: Commit**

```bash
git add OpenCaffeine/Resources/AboutPanel.swift OpenCaffeine/App/AppDelegate.swift
git commit -m "feat: custom About panel and first-launch instructions"
```

---

## Task 22: README + manual QA checklist

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write the README**

`README.md`:
```markdown
# Open Caffeine

A personal macOS menubar utility that keeps the Mac awake for a chosen duration.
Apple Silicon, macOS 13+. No code signing — local builds only.

## Build

```bash
brew install xcodegen swiftlint
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Release build
```

The app bundle is in the Xcode `DerivedData/.../Build/Products/Release/Open Caffeine.app`.

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
- [ ] About menu shows custom Open Caffeine panel.
- [ ] Screensaver launches from menu.
- [ ] Custom duration prompt accepts minutes input.

## Architecture

See [`docs/superpowers/specs/2026-05-28-open-caffeine-design.md`](docs/superpowers/specs/2026-05-28-open-caffeine-design.md).
```

- [ ] **Step 2: Walk through the entire checklist manually.** Fix anything that fails before committing.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with build and QA instructions"
```

---

## Self-Review Notes

**Spec coverage check:**
- Menubar icon — Task 2, real icons in Task 13.
- Preset durations + Custom + Forever — Tasks 3, 9, 15.
- Countdown display — Tasks 7, 9.
- Multiple icon styles + dark/light — Tasks 8, 13.
- Start screensaver — Task 20.
- Preferences: appearance picker (Task 10), hotkey (Task 17), start at login (Task 11), show in dock (Task 12), instruction message (Task 21), show countdown / default duration (Task 14), battery threshold (Tasks 14, 19).
- About panel — Task 21.
- Quit — Task 2 (wired) / Task 9 (kept).
- SwiftLint 500-line cap — Task 1.
- macOS 13+, no signing — Task 1.
- IOPMAssertion — Task 5.
- IOPSNotification battery monitor — Task 18.
- SMAppService login item — Task 11.
- KeyboardShortcuts library — Tasks 16, 17.
- TDD with mock — Tasks 3, 6, 7, 18.
- Manual QA checklist — Task 22.

**Type-consistency check:**
- `CaffeineSession.start(_:)` throws and is awaited via `try` in all call sites — consistent across MenuBarController, HotKeyService, CustomDurationPrompt wiring.
- `CaffeineSession.stop(reason:)` default `.userRequested` — call sites either omit the argument or pass `.lowBattery` / `.expired`.
- `SleepAssertionProviding` protocol matches both `SleepAssertion` and `MockSleepAssertion`.
- `BatteryProvider.currentBattery()` returns `(hasBattery: Bool, percent: Int)` — matched in fake, system impl, DurationSettingsView row.
- `KeyboardShortcuts.Name.toggleCaffeine` defined once in HotKeyService.swift, used in HotKeyRecorderRow.

**Placeholder scan:** None remaining. Every step shows the code or command needed.

---

## Plan complete.

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session with checkpoints for review.

Which approach?
