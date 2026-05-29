#!/usr/bin/env python3
"""100% line-coverage gate for Open Caffein's own logic files.

Reads `xcrun xccov view --report --json` output on stdin and fails (exit 1) if any
non-excluded source file under OpenCaffein/ is below 100% line coverage.

EXCLUDE holds UI / AppKit / system-shell files whose decision logic has been
extracted into separately-tested types. Keep the list tight and justified — every
entry is code we consciously chose not to unit-test. New source files are NOT
exempt by default: add tests, or extract the logic and list the shell here.
See README "Coverage" for the rationale.
"""
import json
import os
import sys

EXCLUDE = {
    # @main entry + composition root: lifecycle wiring, no extractable logic left.
    "OpenCaffein/App/OpenCaffeinApp.swift",
    "OpenCaffein/App/AppDelegate.swift",
    # AppKit menu-bar orchestration: NSStatusItem, NSPopover, Combine observers.
    "OpenCaffein/MenuBar/MenuBarController.swift",
    # SwiftUI Liquid Glass popover body: declarative view, logic in models.
    "OpenCaffein/MenuBar/MenuPanelView.swift",
    # Borderless transparent panel host (NSPanel + click monitor) for the popover.
    "OpenCaffein/MenuBar/MenuPanelController.swift",
    # Coffee glyph Canvas views + ImageRenderer template + picker (view shell).
    "OpenCaffein/MenuBar/CoffeeGlyph.swift",
    # NSAlert modal presenter: runModal() blocks the test runner.
    "OpenCaffein/MenuBar/CustomDurationPrompt.swift",
    # Standard AppKit "About" panel presentation.
    "OpenCaffein/Resources/AboutPanel.swift",
    # Declarative design tokens (fonts, radii) — no logic.
    "OpenCaffein/Resources/Theme.swift",
    # SwiftUI view bodies: declarative; logic lives in *Actions / *Formatter / *Model.
    "OpenCaffein/Settings/PreferencesScene.swift",
    "OpenCaffein/Settings/GeneralSettingsView.swift",
    "OpenCaffein/Settings/DurationSettingsView.swift",
    "OpenCaffein/Settings/SettingsComponents.swift",
    "OpenCaffein/Settings/HotKeyRecorderRow.swift",
    "OpenCaffein/Settings/PreferencesWindowController.swift",
    # Thin OS-API shims: IOKit / SMAppService / KeyboardShortcuts / NSWorkspace.
    "OpenCaffein/Services/SystemAdapters.swift",
    "OpenCaffein/Services/SystemBatteryProvider.swift",
    "OpenCaffein/Services/ScreenSaverLauncher.swift",
}


def main():
    repo = os.environ.get("REPO", os.getcwd())
    src_prefix = os.path.join(repo, "OpenCaffein") + os.sep
    report = json.load(sys.stdin)

    failures = []
    excluded_seen = set()
    checked = 0
    for target in report.get("targets", []):
        for entry in target.get("files", []):
            path = entry["path"]
            if not path.startswith(src_prefix):
                continue  # third-party SPM sources, test target, etc.
            rel = os.path.relpath(path, repo)
            if rel in EXCLUDE:
                excluded_seen.add(rel)
                continue
            checked += 1
            covered, total = entry["coveredLines"], entry["executableLines"]
            if covered != total:
                failures.append((rel, covered, total))

    print(f"Coverage gate: {checked} logic file(s) checked, {len(excluded_seen)} excluded.")

    stale = EXCLUDE - excluded_seen
    if stale:
        print("\n⚠️  EXCLUDE entries that matched no file (rename/remove them):")
        for rel in sorted(stale):
            print(f"      {rel}")

    if failures:
        print("\n❌ Below 100% line coverage:")
        for rel, covered, total in sorted(failures):
            pct = (covered / total * 100) if total else 100.0
            print(f"      {rel}: {pct:.1f}% ({covered}/{total})")
        print("\nAdd tests to reach 100%, or — if this is genuinely UI/system glue —")
        print("extract its logic into a tested type and add the shell to EXCLUDE.")
        sys.exit(1)

    print("✅ All logic files at 100% line coverage.")


if __name__ == "__main__":
    main()
