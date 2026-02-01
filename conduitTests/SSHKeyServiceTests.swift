//
//  SSHKeyServiceTests.swift
//  conduitTests
//

@testable import conduit
import Foundation
import Testing

struct SSHKeyServiceTests {
    let service = SSHKeyService.shared

    // MARK: - Key Type Detection

    @Test func detectKeyTypeEd25519() throws {
        let content = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        ssh-ed25519 test content
        -----END OPENSSH PRIVATE KEY-----
        """

        let keyType = try service.detectKeyType(from: content)
        #expect(keyType == .ed25519)
    }

    @Test func detectKeyTypeRSA() throws {
        let content = """
        -----BEGIN RSA PRIVATE KEY-----
        test content
        -----END RSA PRIVATE KEY-----
        """

        let keyType = try service.detectKeyType(from: content)
        #expect(keyType == .rsa)
    }

    @Test func detectKeyTypeRSAFromSSHMarker() throws {
        let content = "ssh-rsa AAAA..."

        let keyType = try service.detectKeyType(from: content)
        #expect(keyType == .rsa)
    }

    @Test func detectKeyTypeECDSAP256() throws {
        let content = "ecdsa-sha2-nistp256 AAAA..."

        let keyType = try service.detectKeyType(from: content)
        #expect(keyType == .ecdsaP256)
    }

    @Test func detectKeyTypeECDSAP384() throws {
        let content = "ecdsa-sha2-nistp384 AAAA..."

        let keyType = try service.detectKeyType(from: content)
        #expect(keyType == .ecdsaP384)
    }

    @Test func detectKeyTypeECDSAP521() throws {
        let content = "ecdsa-sha2-nistp521 AAAA..."

        let keyType = try service.detectKeyType(from: content)
        #expect(keyType == .ecdsaP521)
    }

    @Test func detectKeyTypeUnsupported() {
        let content = "some unknown key format"

        #expect(throws: SSHKeyService.KeyServiceError.self) {
            try service.detectKeyType(from: content)
        }
    }

    // MARK: - Passphrase Detection

    @Test func keyRequiresPassphraseLegacyPEM() {
        let content = """
        -----BEGIN RSA PRIVATE KEY-----
        Proc-Type: 4,ENCRYPTED
        DEK-Info: AES-128-CBC,1234567890ABCDEF

        encrypted content here
        -----END RSA PRIVATE KEY-----
        """

        #expect(service.keyRequiresPassphrase(content) == true)
    }

    @Test func keyRequiresPassphraseLegacyUnencrypted() {
        let content = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIBOgIBAAJBALRiMLAA...
        -----END RSA PRIVATE KEY-----
        """

        #expect(service.keyRequiresPassphrase(content) == false)
    }

    // MARK: - Key Generation

    @Test func generateEd25519KeyProducesValidOutput() {
        let generated = service.generateEd25519Key()

        // Check private key format
        #expect(generated.privateKeyPEM.contains("-----BEGIN OPENSSH PRIVATE KEY-----"))
        #expect(generated.privateKeyPEM.contains("-----END OPENSSH PRIVATE KEY-----"))

        // Check public key format
        #expect(generated.publicKeyString.hasPrefix("ssh-ed25519 "))

        // Check fingerprint format (32 hex pairs separated by colons)
        let fingerprintParts = generated.fingerprint.split(separator: ":")
        #expect(fingerprintParts.count == 32)

        // Check public key data is not empty
        #expect(!generated.publicKeyData.isEmpty)
    }

    @Test func generateEd25519KeyProducesUniqueKeys() {
        let key1 = service.generateEd25519Key()
        let key2 = service.generateEd25519Key()

        #expect(key1.fingerprint != key2.fingerprint)
        #expect(key1.publicKeyData != key2.publicKeyData)
        #expect(key1.privateKeyPEM != key2.privateKeyPEM)
    }

    @Test func generatedKeyCanBeParsedBack() throws {
        let generated = service.generateEd25519Key()

        // Parse the generated key
        let parsed = try service.parsePrivateKey(from: generated.privateKeyPEM, passphrase: nil)

        #expect(parsed.keyType == .ed25519)
        #expect(parsed.fingerprint == generated.fingerprint)
        #expect(parsed.publicKeyData == generated.publicKeyData)
    }

    @Test func generatedKeyDoesNotRequirePassphrase() {
        let generated = service.generateEd25519Key()

        #expect(service.keyRequiresPassphrase(generated.privateKeyPEM) == false)
    }
}
