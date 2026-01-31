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
}
