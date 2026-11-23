import Foundation
import Security

/// XPC interface of `OpenCaffeineHelper`, the root daemon behind "Stay awake with
/// lid closed". Kept tiny on purpose: everything here runs as root.
@objc protocol LidSleepHelperProtocol {
    /// Blocks (`true`) or restores (`false`) all system sleep, lid close included,
    /// via `pmset -a disablesleep`. Replies whether macOS accepted it.
    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping (Bool) -> Void)
}

/// Names and trust rules shared by the app and the helper.
enum LidSleepHelper {
    /// launchd label, Mach service name, and the helper's code-signing identifier.
    static let label = "com.opencaffeine.OpenCaffeine.helper"
    /// File name under `Contents/Library/LaunchDaemons` for `SMAppService.daemon(plistName:)`.
    static let plistName = "\(label).plist"
    static let appIdentifier = "com.opencaffeine.OpenCaffeine"

    /// Code-signing requirement for the other side of the connection: the given
    /// identifier, signed by an Apple-issued certificate of this process's team.
    /// `nil` for ad-hoc builds, which have no team to pin trust to.
    static func requirement(forPeer identifier: String) -> String? {
        guard let team = ownTeamIdentifier() else { return nil }
        return "identifier \"\(identifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
    }

    static func ownTeamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let info = info as? [String: Any] else { return nil }
        return info[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
