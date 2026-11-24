import Foundation
import os.log

/// The helper's `SleepControlling`: `pmset`, checked against the kernel, plus the
/// marker file that lets a later launch undo a crash.
///
/// `pmset` can print an error and still exit 0, so a change only counts once the
/// root domain's `SleepDisabled` flag shows it. The system calls are injected so
/// this is unit-tested; `OpenCaffeineHelper` passes the real ones.
final class PMSetSleepControl: SleepControlling {
    typealias Runner = ([String]) -> Bool

    private let marker: URL
    private let checks: Int
    private let run: Runner
    private let readSleepDisabled: () -> Bool?
    private let lidShouldSleep: () -> Bool
    private let pause: (TimeInterval) -> Void
    private let log = Logger(subsystem: "com.opencaffeine.helper", category: "helper")

    /// - Parameters:
    ///   - checks: How many times to read the kernel's flag before giving up.
    ///   - run: Runs `/usr/bin/pmset` with these arguments; `true` on exit status 0.
    init(
        marker: URL,
        checks: Int,
        run: @escaping Runner,
        readSleepDisabled: @escaping () -> Bool?,
        lidShouldSleep: @escaping () -> Bool,
        pause: @escaping (TimeInterval) -> Void
    ) {
        self.marker = marker
        self.checks = checks
        self.run = run
        self.readSleepDisabled = readSleepDisabled
        self.lidShouldSleep = lidShouldSleep
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
        for check in 1...checks {
            if readSleepDisabled() == disabled {
                log.notice("System sleep \(disabled ? "disabled" : "restored", privacy: .public)")
                return true
            }
            if check < checks { pause(0.1) }
        }
        log.error("pmset exited 0 but the kernel still says SleepDisabled != \(disabled, privacy: .public)")
        return false
    }

    func sleepIfLidIsClosed() {
        guard lidShouldSleep() else { return }
        log.notice("Lid is closed; putting the Mac to sleep")
        _ = run(["sleepnow"])
    }
}
