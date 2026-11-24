import Foundation
import os.log

/// The helper's `SleepControlling`: `pmset`, checked against the kernel, plus the
/// marker file that lets a later launch undo a crash.
///
/// `pmset` can print an error and still exit 0, and powerd saves the setting and
/// applies it to the kernel separately, so a change only counts once both the saved
/// setting (`pmset -g`) and the root domain's `SleepDisabled` flag show it. The
/// system calls are injected so this is unit-tested; `OpenCaffeineHelper` passes
/// the real ones.
final class PMSetSleepControl: SleepControlling {
    typealias Runner = ([String]) -> Bool

    private let marker: URL
    private let maxWait: TimeInterval
    private let run: Runner
    private let readSleepDisabled: () -> Bool?
    private let readSavedSleepDisabled: () -> Bool?
    private let lidShouldSleep: () -> Bool
    private let now: () -> Date
    private let pause: (TimeInterval) -> Void
    private let log = Logger(subsystem: "com.opencaffeine.helper", category: "helper")

    /// - Parameters:
    ///   - maxWait: How long to keep reading back after `pmset` returns before giving
    ///     up. It bounds the whole wait however slow the reads are, so the helper
    ///     can tell launchd how long a change may take.
    ///   - run: Runs `/usr/bin/pmset` with these arguments; `true` on exit status 0.
    init(
        marker: URL,
        maxWait: TimeInterval,
        run: @escaping Runner,
        readSleepDisabled: @escaping () -> Bool?,
        readSavedSleepDisabled: @escaping () -> Bool?,
        lidShouldSleep: @escaping () -> Bool,
        now: @escaping () -> Date,
        pause: @escaping (TimeInterval) -> Void
    ) {
        self.marker = marker
        self.maxWait = maxWait
        self.run = run
        self.readSleepDisabled = readSleepDisabled
        self.readSavedSleepDisabled = readSavedSleepDisabled
        self.lidShouldSleep = lidShouldSleep
        self.now = now
        self.pause = pause
    }

    var hasMarker: Bool { FileManager.default.fileExists(atPath: marker.path) }

    func writeMarker() -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: marker.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data().write(to: marker, options: .atomic)
            return true
        } catch {
            log.error("Could not write the recovery marker: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    func removeMarker() {
        guard hasMarker else { return }
        do {
            try FileManager.default.removeItem(at: marker)
        } catch {
            log.error("Could not remove the recovery marker: \(String(describing: error), privacy: .public)")
        }
    }

    func setSleepDisabled(_ disabled: Bool) -> Bool {
        guard run(["-a", "disablesleep", disabled ? "1" : "0"]) else { return false }
        let deadline = now().addingTimeInterval(maxWait)
        while true {
            if readSleepDisabled() == disabled, readSavedSleepDisabled() == disabled {
                log.notice("System sleep \(disabled ? "disabled" : "restored", privacy: .public)")
                return true
            }
            guard now() < deadline else { break }
            pause(0.1)
        }
        log.error("pmset exited 0 but SleepDisabled never settled at \(disabled, privacy: .public)")
        return false
    }

    /// The saved `SleepDisabled` from `pmset -g` output, which lists it only once it
    /// has been set. `nil` when there is no output to go by.
    static func savedSleepDisabled(fromPMSetOutput output: String?) -> Bool? {
        guard let output, !output.isEmpty else { return nil }
        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if fields.first == "SleepDisabled" { return fields.dropFirst().first == "1" }
        }
        return false
    }

    func sleepIfLidIsClosed() {
        guard lidShouldSleep() else { return }
        log.notice("Lid is closed; putting the Mac to sleep")
        _ = run(["sleepnow"])
    }
}
