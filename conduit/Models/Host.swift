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
    var isFavorite: Bool = false
    var lastConnected: Date?

    var hasStoredCredential: Bool {
        KeychainService.shared.hasPassword(for: id)
    }

    enum AuthMethod: String, Codable, CaseIterable {
        case password
        case key
    }
}

extension Host {
    static let example = Host(
        name: "Mac Mini",
        hostname: "192.168.1.100",
        username: "user"
    )

    /// Formatted string for last connected time
    var lastConnectedFormatted: String? {
        guard let lastConnected else { return nil }

        let secondsAgo = Date().timeIntervalSince(lastConnected)

        // Show "just now" for very recent connections (within 60 seconds)
        if secondsAgo < 60 {
            return "just now"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastConnected, relativeTo: Date())
    }
}
