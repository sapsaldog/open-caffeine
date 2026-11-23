import Foundation
@testable import OpenCaffeine

final class MockSleepDisabler: SleepDisabling {
    /// Every value asked for, in order.
    private(set) var requests: [Bool] = []
    /// Whether macOS accepts the change.
    var accepts = true

    func setSleepDisabled(_ disabled: Bool, completion: @escaping (Bool) -> Void) {
        requests.append(disabled)
        completion(accepts)
    }
}
