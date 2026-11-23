import Foundation
@testable import OpenCaffeine

final class MockDisplaySleeper: DisplaySleeping {
    private(set) var sleepCount = 0
    var error: Error?
    var onSleep: (() -> Void)?

    func sleepDisplayNow() throws {
        sleepCount += 1
        onSleep?()
        if let error { throw error }
    }
}
