import Foundation
import LocalAuthentication
import Security

final class KeychainService {
    enum KeychainError: LocalizedError {
        case noStoredPassword
        case invalidPasswordData
        case authenticationFailed
        case userCanceled
        case biometryNotAvailable(String)
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .noStoredPassword:
                return "No saved password for this host."
            case .invalidPasswordData:
                return "Saved password is unreadable."
            case .authenticationFailed:
                return "Authentication failed. Please try again."
            case .userCanceled:
                return "Authentication was canceled."
            case let .biometryNotAvailable(reason):
                return "Biometric authentication unavailable: \(reason)"
            case let .unexpectedStatus(status):
                if let message = SecCopyErrorMessageString(status, nil) as String? {
                    return message
                }
                return "Keychain error (status: \(status))."
            }
        }
    }

    static let shared = KeychainService()

    private let service = "com.conduit.credentials"
    private var cachedPasswords: [UUID: CachedPassword] = [:]

    private init() {}

    func hasPassword(for hostID: UUID) -> Bool {
        var query: [String: Any] = baseQuery(for: hostID)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed:
            // errSecInteractionNotAllowed occurs for items requiring user presence; treat as exists.
            return true
        case errSecItemNotFound:
            return false
        default:
            return false
        }
    }

    /// Authenticates the user with Face ID/Touch ID before saving.
    /// Call this before savePassword to ensure the user has granted biometric permission
    /// and to provide a consistent UX where the user authenticates when saving credentials.
    func authenticateForSave(prompt: String) async throws {
        let context = LAContext()
        context.localizedReason = prompt

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw KeychainError.biometryNotAvailable(
                error?.localizedDescription ?? "Biometrics or passcode is not configured."
            )
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: prompt) { success, error in
                if success {
                    continuation.resume()
                } else if let error = error as? NSError {
                    if error.code == LAError.userCancel.rawValue {
                        continuation.resume(throwing: KeychainError.userCanceled)
                    } else {
                        continuation.resume(throwing: KeychainError.authenticationFailed)
                    }
                } else {
                    continuation.resume(throwing: KeychainError.authenticationFailed)
                }
            }
        }
    }

    func savePassword(_ password: String, for hostID: UUID) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.invalidPasswordData
        }

        let accessControl = try makeAccessControl()

        // Delete any existing item first to avoid issues with updating protected items.
        // SecItemUpdate on items with .userPresence access control requires authentication,
        // so we delete and re-add instead.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: hostID.uuidString
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: hostID.uuidString,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        clearCachedPassword(for: hostID)
    }

    func retrievePassword(
        for hostID: UUID,
        prompt: String,
        reuseInterval: TimeInterval
    ) async throws -> String {
        if reuseInterval > 0,
           let cached = cachedPasswords[hostID],
           cached.expiry > Date()
        {
            return cached.password
        }

        let data: Data
        do {
            data = try readPassword(for: hostID, prompt: prompt)
        } catch {
            clearCachedPassword(for: hostID)
            throw error
        }
        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidPasswordData
        }
        if reuseInterval > 0 {
            cachedPasswords[hostID] = CachedPassword(
                password: password,
                expiry: Date().addingTimeInterval(reuseInterval)
            )
        }
        return password
    }

    func deletePassword(for hostID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: hostID.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(status)
        }
        clearCachedPassword(for: hostID)
    }

    func deleteAllPasswords() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(status)
        }
        clearCachedPasswordCache()
    }

    /// Reads password from keychain, letting the system handle Face ID/Touch ID authentication.
    /// Uses kSecUseOperationPrompt instead of a custom LAContext to avoid issues with
    /// LAContext state that can cause "max authentication attempts" errors.
    private func readPassword(for hostID: UUID, prompt: String) throws -> Data {
        var query: [String: Any] = baseQuery(for: hostID)
        query[kSecReturnData as String] = true
        query[kSecUseOperationPrompt as String] = prompt

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainError.invalidPasswordData
            }
            return data
        case errSecItemNotFound:
            throw KeychainError.noStoredPassword
        case errSecUserCanceled, errSecAuthFailed:
            throw KeychainError.userCanceled
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for hostID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: hostID.uuidString
        ]
    }

    private func makeAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let control = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.userPresence],
            &error
        ) else {
            if let error {
                throw error.takeRetainedValue() as Error
            }
            throw KeychainError.unexpectedStatus(errSecParam)
        }
        return control
    }

    func invalidateCachedContext() {
        clearCachedPasswordCache()
    }

    private func clearCachedPassword(for hostID: UUID) {
        cachedPasswords.removeValue(forKey: hostID)
    }

    private func clearCachedPasswordCache() {
        cachedPasswords.removeAll()
    }
}

private struct CachedPassword {
    let password: String
    let expiry: Date
}
