import Foundation
import os.log

/// Seam over "turn every display off now" so `DisplayOffAction` is unit-testable.
/// The live implementation lives in `SystemAdapters`.
protocol DisplaySleeping {
    func sleepDisplayNow() throws
}

/// "Display Off": blanks the screens right away while the Mac keeps working.
///
/// A dark screen with no session could let the Mac fall asleep and stop the
/// user's work, so when idle it starts a session first and leaves the screen on
/// if that fails. The display sleeps after a short `delay` so the hand that just
/// clicked doesn't nudge the mouse and wake it straight back up — unless the
/// session ended in the meantime, since then nothing would keep the Mac awake.
struct DisplayOffAction {
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void

    private let session: CaffeineSession
    private let display: DisplaySleeping
    private let delay: TimeInterval
    private let schedule: Scheduler
    private let log = Logger(subsystem: "com.opencaffeine", category: "display")

    init(
        session: CaffeineSession,
        display: DisplaySleeping,
        delay: TimeInterval = 1,
        schedule: @escaping Scheduler = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.session = session
        self.display = display
        self.delay = delay
        self.schedule = schedule
    }

    /// - Parameter duration: Session length to start with when none is running;
    ///   a running session is left exactly as it is.
    func perform(startingWith duration: CaffeineDuration) {
        if !session.state.isActive {
            do {
                try session.start(duration)
            } catch {
                log.error("No session, so leaving the display on: \(String(describing: error), privacy: .public)")
                return
            }
        }
        schedule(delay) { [session, display, log] in
            guard session.state.isActive else {
                log.notice("Session ended before the display went dark; leaving it on")
                return
            }
            do {
                try display.sleepDisplayNow()
            } catch {
                log.error("Display sleep failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
