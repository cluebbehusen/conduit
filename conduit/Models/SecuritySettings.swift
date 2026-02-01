import Foundation

enum AccessoryBarMode: String, CaseIterable {
    case hidden
    case collapsed
    case expanded

    var displayName: String {
        switch self {
        case .hidden: "Hidden"
        case .collapsed: "Collapsing"
        case .expanded: "Always visible"
        }
    }
}

@MainActor
@Observable
final class SecuritySettings {
    private enum Keys {
        static let autoLockTimeout = "security.autoLockTimeout"
        static let lastUnlock = "security.lastUnlock"
        static let accessoryBarMode = "terminal.accessoryBarMode"
    }

    /// Time in seconds before requiring another biometric unlock.
    var autoLockTimeout: TimeInterval {
        didSet {
            save()
            KeychainService.shared.invalidateCachedContext()
        }
    }

    /// Controls how the terminal accessory bar is displayed.
    var accessoryBarMode: AccessoryBarMode {
        didSet {
            UserDefaults.standard.set(accessoryBarMode.rawValue, forKey: Keys.accessoryBarMode)
        }
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

        if let storedMode = UserDefaults.standard.string(forKey: Keys.accessoryBarMode),
           let mode = AccessoryBarMode(rawValue: storedMode)
        {
            accessoryBarMode = mode
        } else {
            accessoryBarMode = .collapsed // Default
        }
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
