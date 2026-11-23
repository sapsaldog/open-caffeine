import Foundation
@testable import OpenCaffeine

final class MockSleepDisabler: SleepDisabling {
    /// Every value asked for, in order.
    private(set) var requests: [Bool] = []
    /// Whether macOS accepts the change (immediate replies).
    var accepts = true
    /// Holds replies until `reply(_:)`, like a slow XPC round trip.
    var defersReplies = false
    /// Runs after each request is recorded.
    var onRequest: (() -> Void)?
    private var pending: [(Bool) -> Void] = []

    var pendingReplies: Int { pending.count }

    func setSleepDisabled(_ disabled: Bool, completion: @escaping (Bool) -> Void) {
        requests.append(disabled)
        onRequest?()
        if defersReplies {
            pending.append(completion)
        } else {
            completion(accepts)
        }
    }

    /// Delivers the oldest held reply.
    func reply(_ accepted: Bool) {
        pending.removeFirst()(accepted)
    }
}
