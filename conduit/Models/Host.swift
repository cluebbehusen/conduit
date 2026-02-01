//
//  Host.swift
//  conduit
//

import Foundation

struct Host: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var name: String
    var hostname: String
    var port: Int = 22
    var username: String
    var authMethod: AuthMethod = .password
    var keyID: UUID?
    var isFavorite: Bool = false
    var lastConnected: Date?

    var hasStoredCredential: Bool {
        switch authMethod {
        case .password:
            KeychainService.shared.hasPassword(for: id)
        case .key:
            keyID != nil
        }
    }

    enum AuthMethod: String, Codable, CaseIterable {
        case password
        case key

        var displayName: String {
            switch self {
            case .password: "Password"
            case .key: "SSH Key"
            }
        }
    }
}

extension Host {
    static let example = Host(
        name: "Mac Mini",
        hostname: "192.168.1.100",
        username: "user"
    )

    private static let lastConnectedFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// Formatted string for last connected time
    var lastConnectedFormatted: String? {
        guard let lastConnected else { return nil }

        let secondsAgo = Date().timeIntervalSince(lastConnected)

        // Show "just now" for very recent connections (within 60 seconds)
        if secondsAgo < 60 {
            return "just now"
        }

        return Self.lastConnectedFormatter.localizedString(for: lastConnected, relativeTo: Date())
    }
}
