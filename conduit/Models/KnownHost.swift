//
//  KnownHost.swift
//  conduit
//

import Foundation

struct KnownHost: Codable, Identifiable {
    var id: String {
        hostKey
    }

    /// Unique key for this host (hostname:port)
    let hostKey: String

    /// SSH key type (e.g., "ssh-ed25519", "ssh-rsa")
    let keyType: String

    /// SHA256 fingerprint of the public key
    let fingerprint: String

    /// When this host was first trusted
    let firstSeen: Date

    /// When we last connected to this host
    var lastSeen: Date

    init(hostname: String, port: Int, keyType: String, fingerprint: String) {
        self.hostKey = "\(hostname):\(port)"
        self.keyType = keyType
        self.fingerprint = fingerprint
        self.firstSeen = Date()
        self.lastSeen = Date()
    }
}

/// Represents a host key that needs verification
struct PendingHostKey {
    let hostname: String
    let port: Int
    let keyType: String
    let fingerprint: String

    /// The existing known host if this is a key change scenario
    let existingHost: KnownHost?

    var isKeyChange: Bool {
        existingHost != nil
    }

    var hostKey: String {
        "\(hostname):\(port)"
    }
}
