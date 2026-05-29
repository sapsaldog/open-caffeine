import Foundation
import os.log
import ServiceManagement

/// Seam over `SMAppService` so the enable/disable logic is unit-testable.
/// The live `SMAppService` conformance lives in `SystemAdapters`.
protocol LoginItemControlling {
    var isRegistered: Bool { get }
    func register() throws
    func unregister() throws
}

@MainActor
final class LoginItemManager {
    private let log = Logger(subsystem: "com.opencaffeine", category: "loginitem")
    private let service: LoginItemControlling

    init(service: LoginItemControlling = SMAppService.mainApp) {
        self.service = service
    }

    var isEnabled: Bool { service.isRegistered }

    func sync(enabled: Bool) {
        do {
            if enabled, !service.isRegistered {
                try service.register()
                log.notice("Registered as login item")
            } else if !enabled, service.isRegistered {
                try service.unregister()
                log.notice("Unregistered login item")
            }
        } catch {
            log.error("Login item update failed: \(String(describing: error), privacy: .public)")
        }
    }
}
