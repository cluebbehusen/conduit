//
//  SSHKeyService.swift
//  conduit
//

import Citadel
import Crypto
import Foundation
import LocalAuthentication
import NIO
import NIOSSH
import Security

final class SSHKeyService {
    enum KeyServiceError: LocalizedError {
        case invalidKeyFormat
        case unsupportedKeyType
        case passphraseRequired
        case incorrectPassphrase
        case keyNotFound
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidKeyFormat:
                return "The key file format is not recognized."
            case .unsupportedKeyType:
                return "This key type is not supported."
            case .passphraseRequired:
                return "This key requires a passphrase."
            case .incorrectPassphrase:
                return "The passphrase is incorrect."
            case .keyNotFound:
                return "No private key found."
            case let .unexpectedStatus(status):
                if let message = SecCopyErrorMessageString(status, nil) as String? {
                    return message
                }
                return "Keychain error (status: \(status))."
            }
        }
    }

    struct ParsedKey {
        let keyType: SSHKey.KeyType
        let publicKeyData: Data
        let fingerprint: String
    }

    static let shared = SSHKeyService()
    private let service = "com.conduit.sshkeys"

    private init() {}

    // MARK: - Key Type Detection

    /// Detect if a key requires a passphrase (is encrypted).
    /// This checks both legacy PEM format and tries parsing to detect OpenSSH encryption.
    func keyRequiresPassphrase(_ content: String) -> Bool {
        // Legacy PEM format encryption marker
        if content.contains("ENCRYPTED") {
            return true
        }

        // For OpenSSH format, try parsing without passphrase to detect encryption
        if content.contains("-----BEGIN OPENSSH PRIVATE KEY-----") {
            do {
                _ = try Curve25519.Signing.PrivateKey(sshEd25519: content, decryptionKey: nil)
                return false // Parsed successfully, no passphrase needed
            } catch {
                // Check if error indicates encryption
                return isEncryptionError(error)
            }
        }

        return false
    }

    /// Detect the key type from the content
    func detectKeyType(from content: String) throws -> SSHKey.KeyType {
        let lowercased = content.lowercased()

        if lowercased.contains("ssh-ed25519") || lowercased.contains("ed25519") {
            return .ed25519
        } else if lowercased.contains("ssh-rsa") || lowercased.contains("rsa private key") {
            return .rsa
        } else if lowercased.contains("ecdsa-sha2-nistp256") || lowercased.contains("nistp256") {
            return .ecdsaP256
        } else if lowercased.contains("ecdsa-sha2-nistp384") || lowercased.contains("nistp384") {
            return .ecdsaP384
        } else if lowercased.contains("ecdsa-sha2-nistp521") || lowercased.contains("nistp521") {
            return .ecdsaP521
        }

        // For OpenSSH format keys without explicit type marker, try parsing
        if content.contains("-----BEGIN OPENSSH PRIVATE KEY-----") {
            // Will need to actually parse to determine type
            // Default to ed25519 as most common modern key
            return .ed25519
        }

        throw KeyServiceError.unsupportedKeyType
    }

    // MARK: - Key Parsing

    /// Parse a private key and extract metadata
    func parsePrivateKey(from content: String, passphrase: String?) throws -> ParsedKey {
        let passphraseData = passphrase?.data(using: .utf8)

        // Try Ed25519 first
        do {
            return try parseEd25519Key(content: content, passphraseData: passphraseData)
        } catch {
            if isEncryptionError(error), passphrase == nil {
                throw KeyServiceError.passphraseRequired
            }
            // Continue to try RSA
        }

        // Try RSA
        do {
            return try parseRSAKey(content: content, passphraseData: passphraseData)
        } catch {
            if isEncryptionError(error), passphrase == nil {
                throw KeyServiceError.passphraseRequired
            }
            // Fall through to error handling
        }

        // Check legacy PEM encryption marker as fallback
        if content.contains("ENCRYPTED"), passphrase == nil {
            throw KeyServiceError.passphraseRequired
        }

        throw KeyServiceError.invalidKeyFormat
    }

    /// Check if an error indicates the key is encrypted and needs a passphrase
    private func isEncryptionError(_ error: Error) -> Bool {
        let description = String(describing: error)
        // Citadel throws these for encrypted keys:
        // - missingDecryptionKey: cipher != none but no passphrase provided
        // - invalidCheck: checksum mismatch (wrong passphrase)
        // - unsupportedCipher: encrypted with unknown cipher
        return description.contains("missingDecryptionKey") ||
            description.contains("invalidCheck") ||
            description.contains("unsupportedCipher")
    }

    private func parseEd25519Key(content: String, passphraseData: Data?) throws -> ParsedKey {
        let privateKey = try Curve25519.Signing.PrivateKey(sshEd25519: content, decryptionKey: passphraseData)
        let publicKey = privateKey.publicKey

        // Build public key data in SSH wire format
        let publicKeyData = buildEd25519PublicKeyData(publicKey)
        let fingerprint = calculateFingerprint(from: publicKeyData)

        return ParsedKey(
            keyType: .ed25519,
            publicKeyData: publicKeyData,
            fingerprint: fingerprint
        )
    }

    private func parseRSAKey(content: String, passphraseData: Data?) throws -> ParsedKey {
        let privateKey = try Insecure.RSA.PrivateKey(sshRsa: content, decryptionKey: passphraseData)
        let publicKey = privateKey.publicKey

        // Build public key data in SSH wire format
        let publicKeyData = buildRSAPublicKeyData(publicKey)
        let fingerprint = calculateFingerprint(from: publicKeyData)

        return ParsedKey(
            keyType: .rsa,
            publicKeyData: publicKeyData,
            fingerprint: fingerprint
        )
    }

    private func buildEd25519PublicKeyData(_ publicKey: Curve25519.Signing.PublicKey) -> Data {
        // SSH wire format: string "ssh-ed25519" + string <32 bytes key>
        var data = Data()

        // Key type string
        let keyType = "ssh-ed25519"
        let keyTypeData = Data(keyType.utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(keyTypeData.count).bigEndian) { Array($0) })
        data.append(keyTypeData)

        // Public key bytes
        let rawKey = publicKey.rawRepresentation
        data.append(contentsOf: withUnsafeBytes(of: UInt32(rawKey.count).bigEndian) { Array($0) })
        data.append(rawKey)

        return data
    }

    private func buildRSAPublicKeyData(_ publicKey: any NIOSSHPublicKeyProtocol) -> Data {
        // Use NIO buffer to write public key
        var buffer = ByteBufferAllocator().buffer(capacity: 512)
        _ = publicKey.write(to: &buffer)
        return Data(buffer.readableBytesView)
    }

    private func calculateFingerprint(from publicKeyData: Data) -> String {
        KnownHostsService.calculateFingerprint(from: publicKeyData)
    }

    // MARK: - Auth Method Construction

    /// Build an SSHAuthenticationMethod from a stored key
    func buildAuthMethod(
        keyContent: String,
        keyType: SSHKey.KeyType,
        passphrase: String?,
        username: String
    ) throws -> SSHAuthenticationMethod {
        let passphraseData = passphrase?.data(using: .utf8)

        switch keyType {
        case .ed25519:
            let privateKey = try Curve25519.Signing.PrivateKey(sshEd25519: keyContent, decryptionKey: passphraseData)
            return .ed25519(username: username, privateKey: privateKey)

        case .rsa:
            let privateKey = try Insecure.RSA.PrivateKey(sshRsa: keyContent, decryptionKey: passphraseData)
            return .rsa(username: username, privateKey: privateKey)

        case .ecdsaP256:
            // ECDSA parsing not implemented in Citadel's public API for OpenSSH format
            throw KeyServiceError.unsupportedKeyType

        case .ecdsaP384:
            throw KeyServiceError.unsupportedKeyType

        case .ecdsaP521:
            throw KeyServiceError.unsupportedKeyType
        }
    }

    // MARK: - Key Generation

    struct GeneratedKey {
        let privateKeyPEM: String
        let publicKeyString: String
        let publicKeyData: Data
        let fingerprint: String
    }

    /// Generate a new Ed25519 key pair
    func generateEd25519Key() -> GeneratedKey {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey

        // Build public key data in SSH wire format
        let publicKeyData = buildEd25519PublicKeyData(publicKey)
        let fingerprint = calculateFingerprint(from: publicKeyData)

        // Format public key string for authorized_keys
        let publicKeyString = "ssh-ed25519 \(publicKeyData.base64EncodedString())"

        // Use Citadel's built-in OpenSSH serialization
        let privateKeyPEM = privateKey.makeSSHRepresentation()

        return GeneratedKey(
            privateKeyPEM: privateKeyPEM,
            publicKeyString: publicKeyString,
            publicKeyData: publicKeyData,
            fingerprint: fingerprint
        )
    }

    // MARK: - Keychain Storage

    func hasPrivateKey(for keyID: UUID) -> Bool {
        var query = baseQuery(for: keyID)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    func savePrivateKey(_ content: String, for keyID: UUID) throws {
        guard let data = content.data(using: .utf8) else {
            throw KeyServiceError.invalidKeyFormat
        }

        let accessControl = try makeAccessControl()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyID.uuidString,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: keyID.uuidString
            ]
            let attributes: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            if updateStatus != errSecSuccess {
                throw KeyServiceError.unexpectedStatus(updateStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw KeyServiceError.unexpectedStatus(status)
        }
    }

    func retrievePrivateKey(
        for keyID: UUID,
        prompt: String,
        reuseInterval _: TimeInterval
    ) async throws -> String {
        var query = baseQuery(for: keyID)
        query[kSecReturnData as String] = true
        query[kSecUseOperationPrompt as String] = prompt

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let content = String(data: data, encoding: .utf8)
            else {
                throw KeyServiceError.keyNotFound
            }
            return content
        case errSecItemNotFound:
            throw KeyServiceError.keyNotFound
        case errSecUserCanceled, errSecAuthFailed:
            throw KeychainService.KeychainError.userCanceled
        default:
            throw KeyServiceError.unexpectedStatus(status)
        }
    }

    func deletePrivateKey(for keyID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyID.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            throw KeyServiceError.unexpectedStatus(status)
        }
    }
}

// MARK: - Private Helpers

private extension SSHKeyService {
    func baseQuery(for keyID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyID.uuidString
        ]
    }

    func makeAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let control = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.userPresence],
            &error
        ) else {
            if let error { throw error.takeRetainedValue() as Error }
            throw KeyServiceError.unexpectedStatus(errSecParam)
        }
        return control
    }
}
