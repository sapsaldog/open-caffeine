import IOKit.pwr_mgt
@testable import OpenCaffein
import XCTest

final class SleepAssertionTests: XCTestCase {
    func testAcquireSuccessActivates() throws {
        let api = FakePowerAssertionAPI()
        let assertion = SleepAssertion(reason: "test", api: api)
        XCTAssertFalse(assertion.isActive)
        try assertion.acquire()
        XCTAssertTrue(assertion.isActive)
        XCTAssertEqual(api.createCount, 1)
    }

    func testAcquireFailureThrowsAndStaysInactive() {
        let api = FakePowerAssertionAPI()
        api.createResult = kIOReturnError
        let assertion = SleepAssertion(api: api)
        XCTAssertThrowsError(try assertion.acquire()) { error in
            guard case SleepAssertionError.ioReturnFailure = error else {
                return XCTFail("expected ioReturnFailure, got \(error)")
            }
        }
        XCTAssertFalse(assertion.isActive)
    }

    func testAcquireWhileActiveReleasesPrior() throws {
        let api = FakePowerAssertionAPI()
        let assertion = SleepAssertion(api: api)
        try assertion.acquire()
        try assertion.acquire()
        XCTAssertEqual(api.releaseCount, 1)
        XCTAssertTrue(assertion.isActive)
    }

    func testReleaseDeactivates() throws {
        let api = FakePowerAssertionAPI()
        let assertion = SleepAssertion(api: api)
        try assertion.acquire()
        assertion.release()
        XCTAssertFalse(assertion.isActive)
        XCTAssertEqual(api.releaseCount, 1)
    }

    func testReleaseWhenInactiveIsNoOp() {
        let api = FakePowerAssertionAPI()
        SleepAssertion(api: api).release()
        XCTAssertEqual(api.releaseCount, 0)
    }

    func testReleaseCompletesEvenWhenIOKitReportsFailure() throws {
        let api = FakePowerAssertionAPI()
        api.releaseResult = kIOReturnError
        let assertion = SleepAssertion(api: api)
        try assertion.acquire()
        assertion.release()
        XCTAssertFalse(assertion.isActive)
    }

    func testDeinitReleasesActiveAssertion() throws {
        let api = FakePowerAssertionAPI()
        do {
            let assertion = SleepAssertion(api: api)
            try assertion.acquire()
        }
        XCTAssertEqual(api.releaseCount, 1)
    }
}

final class FakePowerAssertionAPI: PowerAssertionAPI {
    var createResult: IOReturn = kIOReturnSuccess
    var releaseResult: IOReturn = kIOReturnSuccess
    var assignedID: IOPMAssertionID = 7
    private(set) var createCount = 0
    private(set) var releaseCount = 0

    func create(reason: String, id: inout IOPMAssertionID) -> IOReturn {
        createCount += 1
        id = assignedID
        return createResult
    }

    func release(id: IOPMAssertionID) -> IOReturn {
        releaseCount += 1
        return releaseResult
    }
}
