import Foundation

@MainActor
@Observable
final class SecuritySettings {
    private enum Keys {
        static let autoLockTimeout = "security.autoLockTimeout"
        static let lastUnlock = "security.lastUnlock"
    }

    /// Time in seconds before requiring another biometric unlock.
    var autoLockTimeout: TimeInterval {
        didSet { save() }
    }

    private var lastUnlockDate: Date? {
        didSet {
            if let lastUnlockDate {
                UserDefaults.standard.set(lastUnlockDate, forKey: Keys.lastUnlock)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastUnlock)
            }
        }
    }

    init() {
        let storedTimeout = UserDefaults.standard.object(forKey: Keys.autoLockTimeout) as? TimeInterval
        autoLockTimeout = storedTimeout ?? 300 // 5 minutes default

        lastUnlockDate = UserDefaults.standard.object(forKey: Keys.lastUnlock) as? Date
    }

    func recordUnlock() {
        lastUnlockDate = Date()
    }

    func isLocked() -> Bool {
        guard let lastUnlockDate else { return true }
        return Date().timeIntervalSince(lastUnlockDate) >= autoLockTimeout
    }

    func resetUnlock() {
        lastUnlockDate = nil
    }

    private func save() {
        UserDefaults.standard.set(autoLockTimeout, forKey: Keys.autoLockTimeout)
        if isLocked() {
            resetUnlock()
        }
    }
}
