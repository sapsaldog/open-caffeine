import Foundation
import IOKit.pwr_mgt
import os.log

protocol SleepAssertionProviding: AnyObject {
    var isActive: Bool { get }
    func acquire() throws
    func release()
}

enum SleepAssertionError: Error {
    case ioReturnFailure(IOReturn)
}

/// Seam over the two IOKit power-assertion calls so the acquire/release state
/// machine is unit-testable. The live implementation lives in `SystemAdapters`.
protocol PowerAssertionAPI {
    func create(type: String, reason: String, id: inout IOPMAssertionID) -> IOReturn
    func release(id: IOPMAssertionID) -> IOReturn
}

final class SleepAssertion: SleepAssertionProviding {
    private let log = Logger(subsystem: "com.opencaffeine", category: "assertion")
    private let reason: String
    private let kind: () -> SleepAssertionKind
    private let api: PowerAssertionAPI
    private var assertionID = IOPMAssertionID(0)
    private(set) var isActive = false

    init(
        reason: String = "Open Caffeine keeping system awake",
        kind: @escaping () -> SleepAssertionKind = { .displayAndSystem },
        api: PowerAssertionAPI = IOKitPowerAssertionAPI()
    ) {
        self.reason = reason
        self.kind = kind
        self.api = api
    }

    deinit { release() }

    func acquire() throws {
        if isActive { release() }
        var newID: IOPMAssertionID = 0
        let result = api.create(type: kind().ioKitAssertionType, reason: reason, id: &newID)
        guard result == kIOReturnSuccess else {
            log.error("IOPMAssertionCreateWithName failed: \(result, format: .decimal)")
            throw SleepAssertionError.ioReturnFailure(result)
        }
        assertionID = newID
        isActive = true
        log.notice("Acquired sleep assertion \(newID)")
    }

    func release() {
        guard isActive else { return }
        let result = api.release(id: assertionID)
        if result != kIOReturnSuccess {
            log.error("IOPMAssertionRelease failed: \(result, format: .decimal)")
        }
        assertionID = 0
        isActive = false
        log.notice("Released sleep assertion")
    }
}
