//
//  SettingsTests.swift
//  conduitTests
//

@testable import conduit
import Foundation
import SwiftUI
import Testing

@MainActor
struct SettingsTests {
    private static let suiteName = "SettingsTests"

    private func makeSettings() -> Settings {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            fatalError("Failed to create UserDefaults for test suite")
        }
        defaults.removePersistentDomain(forName: Self.suiteName)
        return Settings(defaults: defaults)
    }

    // MARK: - Default Values

    @Test func defaultAutoLockTimeout() {
        let settings = makeSettings()
        #expect(settings.autoLockTimeout == 300) // 5 minutes
    }

    @Test func defaultAccessoryBarMode() {
        let settings = makeSettings()
        #expect(settings.accessoryBarMode == .collapsed)
    }

    @Test func defaultAppTheme() {
        let settings = makeSettings()
        #expect(settings.appTheme == .system)
    }

    // MARK: - Persistence

    @Test func autoLockTimeoutPersists() throws {
        let defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)

        let settings1 = Settings(defaults: defaults)
        settings1.autoLockTimeout = 600

        let settings2 = Settings(defaults: defaults)
        #expect(settings2.autoLockTimeout == 600)
    }

    @Test func accessoryBarModePersists() throws {
        let defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)

        let settings1 = Settings(defaults: defaults)
        settings1.accessoryBarMode = .expanded

        let settings2 = Settings(defaults: defaults)
        #expect(settings2.accessoryBarMode == .expanded)
    }

    @Test func appThemePersists() throws {
        let defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)

        let settings1 = Settings(defaults: defaults)
        settings1.appTheme = .dark

        let settings2 = Settings(defaults: defaults)
        #expect(settings2.appTheme == .dark)
    }

    // MARK: - Lock State

    @Test func isLockedInitially() {
        let settings = makeSettings()
        #expect(settings.isLocked() == true)
    }

    @Test func recordUnlockUnlocksSettings() {
        let settings = makeSettings()
        settings.recordUnlock()
        #expect(settings.isLocked() == false)
    }

    @Test func resetUnlockLocksSettings() {
        let settings = makeSettings()
        settings.recordUnlock()
        #expect(settings.isLocked() == false)

        settings.resetUnlock()
        #expect(settings.isLocked() == true)
    }

    // MARK: - AccessoryBarMode

    @Test func accessoryBarModeDisplayNames() {
        #expect(AccessoryBarMode.hidden.displayName == "Hidden")
        #expect(AccessoryBarMode.collapsed.displayName == "Collapsing")
        #expect(AccessoryBarMode.expanded.displayName == "Always visible")
    }

    @Test func accessoryBarModeAllCases() {
        #expect(AccessoryBarMode.allCases.count == 3)
    }

    // MARK: - AppTheme

    @Test func appThemeDisplayNames() {
        #expect(AppTheme.system.displayName == "System")
        #expect(AppTheme.light.displayName == "Light")
        #expect(AppTheme.dark.displayName == "Dark")
    }

    @Test func appThemeColorScheme() {
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
        // .system depends on device state, so we just check it returns something
        #expect(AppTheme.system.colorScheme != nil)
    }

    @Test func appThemeAllCases() {
        #expect(AppTheme.allCases.count == 3)
    }
}
