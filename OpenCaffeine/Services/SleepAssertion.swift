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
    private var assertionIDs: [IOPMAssertionID] = []
    var isActive: Bool { !assertionIDs.isEmpty }

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
        var acquired: [IOPMAssertionID] = []
        for type in kind().ioKitAssertionTypes {
            var newID: IOPMAssertionID = 0
            let result = api.create(type: type, reason: reason, id: &newID)
            guard result == kIOReturnSuccess else {
                log.error("IOPMAssertionCreateWithName(\(type, privacy: .public)) failed: \(result, format: .decimal)")
                releaseAll(acquired)  // don't leak the half of the pair that succeeded
                throw SleepAssertionError.ioReturnFailure(result)
            }
            acquired.append(newID)
        }
        assertionIDs = acquired
        log.notice("Acquired sleep assertions \(String(describing: acquired), privacy: .public)")
    }

    func release() {
        guard isActive else { return }
        releaseAll(assertionIDs)
        assertionIDs = []
        log.notice("Released sleep assertions")
    }

    private func releaseAll(_ ids: [IOPMAssertionID]) {
        for id in ids {
            let result = api.release(id: id)
            if result != kIOReturnSuccess {
                log.error("IOPMAssertionRelease failed: \(result, format: .decimal)")
            }
        }
    }
}
