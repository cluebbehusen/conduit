//
//  SSHKeyTests.swift
//  conduitTests
//

@testable import conduit
import Foundation
import Testing

@MainActor
struct SSHKeyTests {
    // MARK: - Codable Round-Trip

    @Test func codableRoundTrip() throws {
        let key = SSHKey(
            name: "My Key",
            keyType: .ed25519,
            fingerprint: "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99",
            publicKeyData: Data([0x01, 0x02, 0x03, 0x04]),
            requiresPassphrase: true,
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(key)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SSHKey.self, from: data)

        #expect(decoded.name == key.name)
        #expect(decoded.keyType == key.keyType)
        #expect(decoded.fingerprint == key.fingerprint)
        #expect(decoded.publicKeyData == key.publicKeyData)
        #expect(decoded.requiresPassphrase == key.requiresPassphrase)
        #expect(decoded.createdAt == key.createdAt)
    }

    @Test func allKeyTypesCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for keyType in SSHKey.KeyType.allCases {
            let data = try encoder.encode(keyType)
            let decoded = try decoder.decode(SSHKey.KeyType.self, from: data)
            #expect(decoded == keyType)
        }
    }

    // MARK: - KeyType Properties

    @Test func keyTypeDisplayNames() {
        #expect(SSHKey.KeyType.ed25519.displayName == "Ed25519")
        #expect(SSHKey.KeyType.rsa.displayName == "RSA")
        #expect(SSHKey.KeyType.ecdsaP256.displayName == "ECDSA P-256")
        #expect(SSHKey.KeyType.ecdsaP384.displayName == "ECDSA P-384")
        #expect(SSHKey.KeyType.ecdsaP521.displayName == "ECDSA P-521")
    }

    @Test func keyTypeSSHNames() {
        #expect(SSHKey.KeyType.ed25519.sshName == "ssh-ed25519")
        #expect(SSHKey.KeyType.rsa.sshName == "ssh-rsa")
        #expect(SSHKey.KeyType.ecdsaP256.sshName == "ecdsa-sha2-nistp256")
        #expect(SSHKey.KeyType.ecdsaP384.sshName == "ecdsa-sha2-nistp384")
        #expect(SSHKey.KeyType.ecdsaP521.sshName == "ecdsa-sha2-nistp521")
    }

    // MARK: - publicKeyString

    @Test func publicKeyStringFormat() {
        let publicKeyData = Data([0x01, 0x02, 0x03, 0x04])
        let key = SSHKey(
            name: "Test",
            keyType: .ed25519,
            fingerprint: "test",
            publicKeyData: publicKeyData,
            requiresPassphrase: false,
            createdAt: Date()
        )

        let expected = "ssh-ed25519 \(publicKeyData.base64EncodedString())"
        #expect(key.publicKeyString == expected)
    }

    @Test func publicKeyStringForRSA() {
        let publicKeyData = Data([0xAA, 0xBB, 0xCC])
        let key = SSHKey(
            name: "Test",
            keyType: .rsa,
            fingerprint: "test",
            publicKeyData: publicKeyData,
            requiresPassphrase: false,
            createdAt: Date()
        )

        #expect(key.publicKeyString.hasPrefix("ssh-rsa "))
        #expect(key.publicKeyString.contains(publicKeyData.base64EncodedString()))
    }

    // MARK: - shortFingerprint

    @Test func shortFingerprintTruncatesLong() {
        let longFingerprint = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99"
        let key = SSHKey(
            name: "Test",
            keyType: .ed25519,
            fingerprint: longFingerprint,
            publicKeyData: Data(),
            requiresPassphrase: false,
            createdAt: Date()
        )

        #expect(key.shortFingerprint == "aa:bb:cc:dd:ee:ff:00:11...")
    }

    @Test func shortFingerprintKeepsShort() {
        let shortFingerprint = "aa:bb:cc:dd"
        let key = SSHKey(
            name: "Test",
            keyType: .ed25519,
            fingerprint: shortFingerprint,
            publicKeyData: Data(),
            requiresPassphrase: false,
            createdAt: Date()
        )

        #expect(key.shortFingerprint == shortFingerprint)
    }

    @Test func shortFingerprintExactlyEight() {
        let exactFingerprint = "aa:bb:cc:dd:ee:ff:00:11"
        let key = SSHKey(
            name: "Test",
            keyType: .ed25519,
            fingerprint: exactFingerprint,
            publicKeyData: Data(),
            requiresPassphrase: false,
            createdAt: Date()
        )

        #expect(key.shortFingerprint == exactFingerprint)
    }
}
