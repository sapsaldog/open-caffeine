import Foundation
@testable import OpenCaffeine

final class MockSystemSleeper: SystemSleeping {
    private(set) var sleepCount = 0
    var error: Error?

    func sleepNow() throws {
        sleepCount += 1
        if let error { throw error }
    }
}
