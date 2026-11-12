import Foundation

/// The menu panel's "now". It ticks once a second only while the panel is on
/// screen. The panel's SwiftUI view stays alive while hidden, so a timer owned by
/// the view would wake the app every second for as long as it runs.
@MainActor
final class PanelClock: ObservableObject {
    @Published private(set) var now: Date

    private let interval: TimeInterval
    private let currentDate: () -> Date
    private var timer: Timer?

    init(interval: TimeInterval = 1, currentDate: @escaping () -> Date = Date.init) {
        self.interval = interval
        self.currentDate = currentDate
        self.now = currentDate()
    }

    var isRunning: Bool { timer != nil }

    /// Starts ticking. Also refreshes `now` right away, so a panel that was hidden
    /// for a while never opens on a stale countdown.
    func start() {
        tick()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        now = currentDate()
    }
}
