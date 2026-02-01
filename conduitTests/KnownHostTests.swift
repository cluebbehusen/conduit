//
//  KnownHostTests.swift
//  conduitTests
//

@testable import conduit
import Foundation
import Testing

@MainActor
struct KnownHostTests {
    // MARK: - Codable Round-Trip

    @Test func codableRoundTrip() throws {
        let host = KnownHost(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "aa:bb:cc:dd:ee:ff"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(host)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(KnownHost.self, from: data)

        #expect(decoded.hostKey == host.hostKey)
        #expect(decoded.keyType == host.keyType)
        #expect(decoded.fingerprint == host.fingerprint)
    }

    // MARK: - hostKey Construction

    @Test func hostKeyFormat() {
        let host = KnownHost(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "test"
        )

        #expect(host.hostKey == "example.com:22")
    }

    @Test func hostKeyWithNonStandardPort() {
        let host = KnownHost(
            hostname: "server.local",
            port: 2222,
            keyType: "ssh-rsa",
            fingerprint: "test"
        )

        #expect(host.hostKey == "server.local:2222")
    }

    @Test func idEqualsHostKey() {
        let host = KnownHost(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "test"
        )

        #expect(host.id == host.hostKey)
    }

    // MARK: - Date Initialization

    @Test func datesSetOnInit() {
        let before = Date()
        let host = KnownHost(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "test"
        )
        let after = Date()

        #expect(host.firstSeen >= before)
        #expect(host.firstSeen <= after)
        #expect(host.lastSeen >= before)
        #expect(host.lastSeen <= after)
    }
}

// MARK: - PendingHostKey Tests

struct PendingHostKeyTests {
    @Test func isKeyChangeWhenExistingHost() {
        let existingHost = KnownHost(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "old-fingerprint"
        )

        let pending = PendingHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "new-fingerprint",
            existingHost: existingHost
        )

        #expect(pending.isKeyChange == true)
    }

    @Test func isKeyChangeWhenNewHost() {
        let pending = PendingHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "fingerprint",
            existingHost: nil
        )

        #expect(pending.isKeyChange == false)
    }

    @Test func hostKeyFormat() {
        let pending = PendingHostKey(
            hostname: "server.example.com",
            port: 2222,
            keyType: "ssh-rsa",
            fingerprint: "test",
            existingHost: nil
        )

        #expect(pending.hostKey == "server.example.com:2222")
    }
}
