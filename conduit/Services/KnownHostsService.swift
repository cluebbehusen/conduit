//
//  KnownHostsService.swift
//  conduit
//

import CryptoKit
import Foundation

final class KnownHostsService {
    static let shared = KnownHostsService()

    private let storageKey = "com.conduit.knownHosts"
    private let defaults: UserDefaults
    private var knownHosts: [String: KnownHost] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadKnownHosts()
    }

    // MARK: - Public API

    /// Check if we have a stored fingerprint for this host
    func hasKnownHost(hostname: String, port: Int) -> Bool {
        let key = "\(hostname):\(port)"
        return knownHosts[key] != nil
    }

    /// Get the known host entry if it exists
    func getKnownHost(hostname: String, port: Int) -> KnownHost? {
        let key = "\(hostname):\(port)"
        return knownHosts[key]
    }

    /// Verify a host key against known hosts
    /// Returns nil if verification passes, or a PendingHostKey if user verification is needed
    func verifyHostKey(
        hostname: String,
        port: Int,
        keyType: String,
        fingerprint: String
    ) -> PendingHostKey? {
        let key = "\(hostname):\(port)"

        if let existingHost = knownHosts[key] {
            if existingHost.fingerprint == fingerprint {
                // Key matches - update last seen and allow
                var updatedHost = existingHost
                updatedHost.lastSeen = Date()
                knownHosts[key] = updatedHost
                saveKnownHosts()
                return nil
            } else {
                // Key changed - this is suspicious!
                return PendingHostKey(
                    hostname: hostname,
                    port: port,
                    keyType: keyType,
                    fingerprint: fingerprint,
                    existingHost: existingHost
                )
            }
        } else {
            // New host - needs user verification (TOFU)
            return PendingHostKey(
                hostname: hostname,
                port: port,
                keyType: keyType,
                fingerprint: fingerprint,
                existingHost: nil
            )
        }
    }

    /// Trust a new host key (called after user approves)
    func trustHostKey(hostname: String, port: Int, keyType: String, fingerprint: String) {
        let host = KnownHost(
            hostname: hostname,
            port: port,
            keyType: keyType,
            fingerprint: fingerprint
        )
        knownHosts[host.hostKey] = host
        saveKnownHosts()
    }

    /// Remove a specific known host
    func removeKnownHost(hostname: String, port: Int) {
        let key = "\(hostname):\(port)"
        knownHosts.removeValue(forKey: key)
        saveKnownHosts()
    }

    /// Remove all known hosts
    func removeAllKnownHosts() {
        knownHosts.removeAll()
        saveKnownHosts()
    }

    /// Get count of known hosts
    var count: Int {
        knownHosts.count
    }

    /// Check if there are no known hosts
    var isEmpty: Bool {
        knownHosts.isEmpty
    }

    // MARK: - Fingerprint Calculation

    /// Calculate SHA256 fingerprint from raw public key data
    nonisolated static func calculateFingerprint(from publicKeyData: Data) -> String {
        let hash = SHA256.hash(data: publicKeyData)
        return hash.map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    // MARK: - Persistence

    private func loadKnownHosts() {
        guard let data = defaults.data(forKey: storageKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            let hosts = try decoder.decode([KnownHost].self, from: data)
            knownHosts = Dictionary(uniqueKeysWithValues: hosts.map { ($0.hostKey, $0) })
        } catch {
            // If decoding fails, start fresh
            knownHosts = [:]
        }
    }

    private func saveKnownHosts() {
        do {
            let encoder = JSONEncoder()
            let hosts = Array(knownHosts.values)
            let data = try encoder.encode(hosts)
            defaults.set(data, forKey: storageKey)
        } catch {
            // Silently fail - not critical
        }
    }
}
