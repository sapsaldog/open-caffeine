import Foundation

/// A scratch `UserDefaults` suite for tests. The test host is the app itself, so
/// `UserDefaults.standard` holds the developer's real Open Caffeine preferences.
/// Tests run serially and share this one suite, wiping it on creation and in
/// `tearDown`, so a run leaves at most one small plist behind.
struct TestDefaults {
    static let suiteName = "com.opencaffeine.OpenCaffeine.tests"
    let defaults: UserDefaults

    init() {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            preconditionFailure("Could not create the test defaults suite \(Self.suiteName)")
        }
        self.defaults = defaults
        remove()
    }

    func remove() {
        defaults.removePersistentDomain(forName: Self.suiteName)
    }
}
