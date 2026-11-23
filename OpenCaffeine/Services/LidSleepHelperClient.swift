import Foundation
import os.log
import ServiceManagement

/// Registers the root helper with launchd and talks to it over XPC. A thin shell
/// over SMAppService and NSXPCConnection (excluded from the coverage gate); the
/// decisions live in `LidSleepController`.
final class LidSleepHelperClient: SleepDisabling {
    enum Registration {
        case approved
        case needsApproval
        case failed
    }

    private let service = SMAppService.daemon(plistName: LidSleepHelper.plistName)
    private let log = Logger(subsystem: "com.opencaffeine", category: "lid")
    /// Kept open while the app runs: the helper restores sleep when it closes.
    private var connection: NSXPCConnection?

    var isApproved: Bool { service.status == .enabled }

    /// Registers the helper on first use and says whether the user still has to
    /// allow it in System Settings.
    func register() -> Registration {
        if service.status == .enabled { return .approved }
        do {
            try service.register()
        } catch {
            // Registering an item that still awaits approval also throws; the status says which.
            log.notice("Helper registration: \(String(describing: error), privacy: .public)")
        }
        switch service.status {
        case .enabled: return .approved
        case .requiresApproval: return .needsApproval
        default:
            log.error("Helper could not be registered (status \(self.service.status.rawValue))")
            return .failed
        }
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func setSleepDisabled(_ disabled: Bool, completion: @escaping (Bool) -> Void) {
        let finish: (Bool) -> Void = { accepted in DispatchQueue.main.async { completion(accepted) } }
        let proxy = openConnection().remoteObjectProxyWithErrorHandler { [log] error in
            log.error("Helper XPC error: \(String(describing: error), privacy: .public)")
            finish(false)
        }
        guard let helper = proxy as? LidSleepHelperProtocol else { return finish(false) }
        helper.setSleepDisabled(disabled, withReply: finish)
    }

    private func openConnection() -> NSXPCConnection {
        if let connection { return connection }
        let connection = NSXPCConnection(machServiceName: LidSleepHelper.label, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: LidSleepHelperProtocol.self)
        if let requirement = LidSleepHelper.requirement(forPeer: LidSleepHelper.label) {
            connection.setCodeSigningRequirement(requirement)
        }
        connection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async { self?.connection = nil }
        }
        connection.resume()
        self.connection = connection
        return connection
    }
}
