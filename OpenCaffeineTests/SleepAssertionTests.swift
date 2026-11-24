import IOKit.pwr_mgt
@testable import OpenCaffeine
import XCTest

final class SleepAssertionTests: XCTestCase {
    private let display = kIOPMAssertPreventUserIdleDisplaySleep
    private let system = kIOPMAssertPreventUserIdleSystemSleep

    func testAcquireSuccessActivates() throws {
        let api = FakePowerAssertionAPI()
        let assertion = SleepAssertion(reason: "test", api: api)
        XCTAssertFalse(assertion.isActive)
        try assertion.acquire()
        XCTAssertTrue(assertion.isActive)
    }

    /// The display assertion only blocks idle system sleep while it keeps the
    /// display lit, so a session that keeps the display on holds both.
    func testAcquireHoldsDisplayAndSystemAssertionsByDefault() throws {
        let api = FakePowerAssertionAPI()
        try SleepAssertion(api: api).acquire()
        XCTAssertEqual(api.createdTypes, [display, system])
    }

    func testAcquireUsesSystemOnlyKindWhenRequested() throws {
        let api = FakePowerAssertionAPI()
        try SleepAssertion(kind: { .systemOnly }, api: api).acquire()
        XCTAssertEqual(api.createdTypes, [system])
    }

    func testAcquireFailureThrowsAndStaysInactive() {
        let api = FakePowerAssertionAPI()
        api.failingCreateCall = 1
        let assertion = SleepAssertion(api: api)
        XCTAssertThrowsError(try assertion.acquire()) { error in
            guard case SleepAssertionError.ioReturnFailure = error else {
                return XCTFail("expected ioReturnFailure, got \(error)")
            }
        }
        XCTAssertFalse(assertion.isActive)
    }

    /// A half-acquired pair must not leak: the assertion already created would
    /// keep the Mac awake with nothing left to release it.
    func testPartialAcquireFailureReleasesWhatItCreated() {
        let api = FakePowerAssertionAPI()
        api.failingCreateCall = 2
        let assertion = SleepAssertion(api: api)
        XCTAssertThrowsError(try assertion.acquire())
        XCTAssertFalse(assertion.isActive)
        XCTAssertEqual(api.releasedIDs, [1])
    }

    func testAcquireWhileActiveReleasesPrior() throws {
        let api = FakePowerAssertionAPI()
        let assertion = SleepAssertion(api: api)
        try assertion.acquire()
        try assertion.acquire()
        XCTAssertEqual(api.releasedIDs, [1, 2])
        XCTAssertTrue(assertion.isActive)
    }

    func testReacquireSwitchesToTheCurrentKind() throws {
        let api = FakePowerAssertionAPI()
        var kind = SleepAssertionKind.displayAndSystem
        let assertion = SleepAssertion(kind: { kind }, api: api)
        try assertion.acquire()
        kind = .systemOnly
        try assertion.acquire()
        XCTAssertEqual(api.releasedIDs, [1, 2])
        XCTAssertEqual(api.createdTypes, [display, system, system])
    }

    func testReleaseReleasesEveryAssertion() throws {
        let api = FakePowerAssertionAPI()
        let assertion = SleepAssertion(api: api)
        try assertion.acquire()
        assertion.release()
        XCTAssertFalse(assertion.isActive)
        XCTAssertEqual(api.releasedIDs, [1, 2])
    }

    func testReleaseWhenInactiveIsNoOp() {
        let api = FakePowerAssertionAPI()
        SleepAssertion(api: api).release()
        XCTAssertEqual(api.releasedIDs, [])
    }

    func testReleaseCompletesEvenWhenIOKitReportsFailure() throws {
        let api = FakePowerAssertionAPI()
        api.releaseResult = kIOReturnError
        let assertion = SleepAssertion(api: api)
        try assertion.acquire()
        assertion.release()
        XCTAssertFalse(assertion.isActive)
        XCTAssertEqual(api.releasedIDs, [1, 2])
    }

    func testDeinitReleasesActiveAssertions() throws {
        let api = FakePowerAssertionAPI()
        do {
            let assertion = SleepAssertion(api: api)
            try assertion.acquire()
        }
        XCTAssertEqual(api.releasedIDs, [1, 2])
    }
}

/// Stands in for IOKit: hands out IDs 1, 2, 3… and records every call.
final class FakePowerAssertionAPI: PowerAssertionAPI {
    /// Makes the n-th `create` call (1-based) fail; `nil` means every call succeeds.
    var failingCreateCall: Int?
    var releaseResult: IOReturn = kIOReturnSuccess
    private(set) var createdTypes: [String] = []
    private(set) var releasedIDs: [IOPMAssertionID] = []
    private var nextID: IOPMAssertionID = 1

    func create(type: String, reason: String, id: inout IOPMAssertionID) -> IOReturn {
        createdTypes.append(type)
        if createdTypes.count == failingCreateCall { return kIOReturnError }
        id = nextID
        nextID += 1
        return kIOReturnSuccess
    }

    func release(id: IOPMAssertionID) -> IOReturn {
        releasedIDs.append(id)
        return releaseResult
    }
}
