import Foundation
@testable import OpenCaffeine

final class MockSystemSleeper: SystemSleeping {
    private(set) var sleepCount = 0
    var error: Error?
    var onSleep: (() -> Void)?

    func sleepNow() throws {
        sleepCount += 1
        onSleep?()
        if let error { throw error }
    }
}
