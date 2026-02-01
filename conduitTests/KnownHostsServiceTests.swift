//
//  KnownHostsServiceTests.swift
//  conduitTests
//

@testable import conduit
import CryptoKit
import Foundation
import Testing

struct KnownHostsServiceTests {
    private static let suiteName = "KnownHostsServiceTests"

    private func makeService() -> KnownHostsService {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            fatalError("Failed to create UserDefaults for test suite")
        }
        defaults.removePersistentDomain(forName: Self.suiteName)
        return KnownHostsService(defaults: defaults)
    }

    // MARK: - Host Verification

    @Test func verifyNewHostReturnsPendingKey() {
        let service = makeService()

        let result = service.verifyHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "aa:bb:cc:dd"
        )

        #expect(result != nil)
        #expect(result?.isKeyChange == false)
        #expect(result?.hostname == "example.com")
    }

    @Test func verifyKnownHostWithMatchingKeyReturnsNil() {
        let service = makeService()

        // Trust the host first
        service.trustHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "aa:bb:cc:dd"
        )

        // Verify with same fingerprint
        let result = service.verifyHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "aa:bb:cc:dd"
        )

        #expect(result == nil) // nil means verification passed
    }

    @Test func verifyKnownHostWithChangedKeyReturnsPendingKey() {
        let service = makeService()

        // Trust the host first
        service.trustHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "aa:bb:cc:dd"
        )

        // Verify with different fingerprint
        let result = service.verifyHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "ee:ff:00:11"
        )

        #expect(result != nil)
        #expect(result?.isKeyChange == true)
        #expect(result?.existingHost?.fingerprint == "aa:bb:cc:dd")
    }

    // MARK: - Trust Host

    @Test func trustHostKey() {
        let service = makeService()

        service.trustHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "aa:bb:cc:dd"
        )

        #expect(service.hasKnownHost(hostname: "example.com", port: 22) == true)
    }

    @Test func getKnownHost() {
        let service = makeService()

        service.trustHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "aa:bb:cc:dd"
        )

        let host = service.getKnownHost(hostname: "example.com", port: 22)

        #expect(host != nil)
        #expect(host?.fingerprint == "aa:bb:cc:dd")
        #expect(host?.keyType == "ssh-ed25519")
    }

    // MARK: - Remove Host

    @Test func removeKnownHost() {
        let service = makeService()

        service.trustHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "aa:bb:cc:dd"
        )

        service.removeKnownHost(hostname: "example.com", port: 22)

        #expect(service.hasKnownHost(hostname: "example.com", port: 22) == false)
    }

    @Test func removeAllKnownHosts() {
        let service = makeService()

        service.trustHostKey(hostname: "s1.example.com", port: 22, keyType: "ssh-ed25519", fingerprint: "aa")
        service.trustHostKey(hostname: "s2.example.com", port: 22, keyType: "ssh-ed25519", fingerprint: "bb")

        #expect(service.count == 2)

        service.removeAllKnownHosts()

        #expect(service.isEmpty)
    }

    // MARK: - Persistence

    @Test func persistsAcrossInstances() throws {
        let suiteName = "KnownHostsPersistenceTest"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let service1 = KnownHostsService(defaults: defaults)
        service1.trustHostKey(
            hostname: "example.com",
            port: 22,
            keyType: "ssh-ed25519",
            fingerprint: "aa:bb:cc:dd"
        )

        let service2 = KnownHostsService(defaults: defaults)
        #expect(service2.hasKnownHost(hostname: "example.com", port: 22) == true)
    }

    // MARK: - Port Differentiation

    @Test func differentPortsAreDifferentHosts() {
        let service = makeService()

        service.trustHostKey(hostname: "example.com", port: 22, keyType: "ssh-ed25519", fingerprint: "aa")
        service.trustHostKey(hostname: "example.com", port: 2222, keyType: "ssh-ed25519", fingerprint: "bb")

        #expect(service.count == 2)

        let host22 = service.getKnownHost(hostname: "example.com", port: 22)
        let host2222 = service.getKnownHost(hostname: "example.com", port: 2222)

        #expect(host22?.fingerprint == "aa")
        #expect(host2222?.fingerprint == "bb")
    }

    // MARK: - Fingerprint Calculation

    @Test func calculateFingerprintFormat() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let fingerprint = KnownHostsService.calculateFingerprint(from: data)

        // SHA256 produces 32 bytes = 32 hex pairs separated by colons
        let parts = fingerprint.split(separator: ":")
        #expect(parts.count == 32)

        // Each part should be 2 hex characters
        for part in parts {
            #expect(part.count == 2)
            let allHex = part.allSatisfy(\.isHexDigit)
            #expect(allHex)
        }
    }

    @Test func calculateFingerprintConsistent() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

        let fingerprint1 = KnownHostsService.calculateFingerprint(from: data)
        let fingerprint2 = KnownHostsService.calculateFingerprint(from: data)

        #expect(fingerprint1 == fingerprint2)
    }

    @Test func calculateFingerprintDifferentForDifferentData() {
        let data1 = Data([0x01, 0x02, 0x03])
        let data2 = Data([0x01, 0x02, 0x04])

        let fingerprint1 = KnownHostsService.calculateFingerprint(from: data1)
        let fingerprint2 = KnownHostsService.calculateFingerprint(from: data2)

        #expect(fingerprint1 != fingerprint2)
    }

    @Test func calculateFingerprintMatchesSHA256() {
        let data = Data("test public key data".utf8)
        let fingerprint = KnownHostsService.calculateFingerprint(from: data)

        // Calculate expected fingerprint manually
        let hash = SHA256.hash(data: data)
        let expected = hash.map { String(format: "%02x", $0) }.joined(separator: ":")

        #expect(fingerprint == expected)
    }

    @Test func calculateFingerprintEmptyData() {
        let data = Data()
        let fingerprint = KnownHostsService.calculateFingerprint(from: data)

        // Should still produce valid SHA256 hash (of empty input)
        let parts = fingerprint.split(separator: ":")
        #expect(parts.count == 32)
    }
}
