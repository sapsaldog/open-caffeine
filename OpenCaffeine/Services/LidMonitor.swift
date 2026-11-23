import CoreGraphics
import Foundation
import IOKit
import IOKit.pwr_mgt

/// A MacBook's lid: whether there is one, and a callback when it closes. Thin
/// shell over IOKit/CoreGraphics (excluded from the coverage gate); what to do
/// about a closed lid is decided by `LidSleepController`.
final class LidMonitor {
    /// `iokit_family_msg(sub_iokit_powermanagement, 0x100)`; the C macro doesn't import.
    private static let clamshellStateChange: UInt32 = 0xE003_4100

    /// Desktops have no clamshell, so the root domain has no `AppleClamshellState`.
    static var hasLid: Bool { Clamshell.current() != nil }

    static func externalDisplayCount() -> Int {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return 0 }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return 0 }
        return displays.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 }.count
    }

    private let onClose: () -> Void
    private var port: IONotificationPortRef?
    private var notifier: io_object_t = 0

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    deinit { stop() }

    func start() {
        guard port == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(port, .main)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let result = Self.withRootDomain { root in
            IOServiceAddInterestNotification(port, root, kIOGeneralInterest, lidInterestCallback, context, &notifier)
        }
        guard result == KERN_SUCCESS else {
            IONotificationPortDestroy(port)
            return
        }
        self.port = port
    }

    func stop() {
        if notifier != 0 {
            IOObjectRelease(notifier)
            notifier = 0
        }
        if let port {
            IONotificationPortDestroy(port)
            self.port = nil
        }
    }

    fileprivate func handle(message: UInt32, argument: UnsafeMutableRawPointer?) {
        guard message == Self.clamshellStateChange else { return }
        if Int(bitPattern: argument) & Int(kClamshellStateBit) != 0 { onClose() }
    }

    private static func withRootDomain<T>(_ body: (io_service_t) -> T) -> T? {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }
        return body(root)
    }
}

/// Capture-free trampoline so it converts to a C function pointer for IOKit.
private func lidInterestCallback(
    _ context: UnsafeMutableRawPointer?,
    _ service: io_service_t,
    _ message: UInt32,
    _ argument: UnsafeMutableRawPointer?
) {
    guard let context else { return }
    Unmanaged<LidMonitor>.fromOpaque(context).takeUnretainedValue().handle(message: message, argument: argument)
}
