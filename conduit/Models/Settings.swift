import Foundation
import SwiftUI
import UIKit

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

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            // Read system interface style from window scene (unaffected by app overrides)
            let style = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                .screen.traitCollection.userInterfaceStyle ?? .light
            return style == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@MainActor
@Observable
final class Settings {
    private enum Keys {
        static let autoLockTimeout = "security.autoLockTimeout"
        static let lastUnlock = "security.lastUnlock"
        static let accessoryBarMode = "terminal.accessoryBarMode"
        static let appTheme = "appearance.theme"
    }

    private let defaults: UserDefaults

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
            defaults.set(accessoryBarMode.rawValue, forKey: Keys.accessoryBarMode)
        }
    }

    /// Controls the app's color scheme (light, dark, or system).
    var appTheme: AppTheme {
        didSet {
            defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
        }
    }

    private var lastUnlockDate: Date? {
        didSet {
            if let lastUnlockDate {
                defaults.set(lastUnlockDate, forKey: Keys.lastUnlock)
            } else {
                defaults.removeObject(forKey: Keys.lastUnlock)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedTimeout = defaults.object(forKey: Keys.autoLockTimeout) as? TimeInterval
        autoLockTimeout = storedTimeout ?? 300 // 5 minutes default

        lastUnlockDate = defaults.object(forKey: Keys.lastUnlock) as? Date

        if let storedMode = defaults.string(forKey: Keys.accessoryBarMode),
           let mode = AccessoryBarMode(rawValue: storedMode)
        {
            accessoryBarMode = mode
        } else {
            accessoryBarMode = .collapsed // Default
        }

        if let storedTheme = defaults.string(forKey: Keys.appTheme),
           let theme = AppTheme(rawValue: storedTheme)
        {
            appTheme = theme
        } else {
            appTheme = .system // Default
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
        defaults.set(autoLockTimeout, forKey: Keys.autoLockTimeout)
        if isLocked() {
            resetUnlock()
        }
    }
}
