//
//  SSHKey.swift
//  conduit
//

import Foundation

struct SSHKey: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var name: String
    var keyType: KeyType
    var fingerprint: String
    var publicKeyData: Data
    var requiresPassphrase: Bool
    var createdAt: Date

    enum KeyType: String, Codable, CaseIterable {
        case ed25519
        case rsa
        case ecdsaP256
        case ecdsaP384
        case ecdsaP521

        var displayName: String {
            switch self {
            case .ed25519: "Ed25519"
            case .rsa: "RSA"
            case .ecdsaP256: "ECDSA P-256"
            case .ecdsaP384: "ECDSA P-384"
            case .ecdsaP521: "ECDSA P-521"
            }
        }

        var sshName: String {
            switch self {
            case .ed25519: "ssh-ed25519"
            case .rsa: "ssh-rsa"
            case .ecdsaP256: "ecdsa-sha2-nistp256"
            case .ecdsaP384: "ecdsa-sha2-nistp384"
            case .ecdsaP521: "ecdsa-sha2-nistp521"
            }
        }
    }
}

extension SSHKey {
    /// Formatted public key string for copying to servers
    var publicKeyString: String {
        "\(keyType.sshName) \(publicKeyData.base64EncodedString())"
    }

    /// Short fingerprint for display (first 8 colon-separated segments)
    var shortFingerprint: String {
        let parts = fingerprint.split(separator: ":")
        if parts.count > 8 {
            return parts.prefix(8).joined(separator: ":") + "..."
        }
        return fingerprint
    }
}

extension SSHKey {
    static let example = SSHKey(
        name: "My Key",
        keyType: .ed25519,
        fingerprint: "SHA256:abcdef1234567890abcdef1234567890abcdef12",
        publicKeyData: Data(),
        requiresPassphrase: false,
        createdAt: Date()
    )
}
