import Foundation
@testable import OpenCaffein

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
