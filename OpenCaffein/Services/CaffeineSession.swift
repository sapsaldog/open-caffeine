import Combine
import Foundation
import os.log

final class CaffeineSession: ObservableObject {
    @Published private(set) var state: SessionState = .idle

    private let assertion: SleepAssertionProviding
    private let clock: () -> Date
    private let log = Logger(subsystem: "com.opencaffein", category: "session")
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
