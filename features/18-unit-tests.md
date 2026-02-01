# Unit Tests

**Priority:** High (Code Quality)
**Effort:** Medium
**Impact:** High - Catch regressions, enable confident refactoring

## Problem

No automated tests exist. Changes to models, services, or stores can introduce regressions that aren't caught until manual testing or production.

## Solution

Add unit tests for models, services, and stores. Focus on pure logic that doesn't require simulators, Keychain access, or UI rendering.

## Tasks

### Phase 1: Test Infrastructure

- [ ] **Create test target**
  - Add `conduitTests` target to Xcode project
  - Create `conduitTests/` directory
  - Add `make test` command to Makefile

- [ ] **Configure CI-friendly testing**
  - Tests should run without simulator where possible
  - Use dependency injection for testability
  - Mock external dependencies (Keychain, network)

### Phase 2: Model Tests

- [ ] **`Host` model tests**
  - Codable round-trip (encode/decode)
  - `hasStoredCredential` logic
  - `lastConnectedFormatted` formatting
  - Default values

- [ ] **`SSHKey` model tests**
  - Codable round-trip
  - `publicKeyString` formatting
  - `shortFingerprint` truncation
  - Key type display names

- [ ] **`KnownHost` model tests**
  - Codable round-trip
  - Fingerprint matching

### Phase 3: Service Tests

- [ ] **`SSHKeyService` tests**
  - Key type detection from content
  - Passphrase requirement detection (legacy PEM + OpenSSH format)
  - Ed25519 key parsing (unencrypted)
  - RSA key parsing (unencrypted)
  - Public key data building
  - Fingerprint calculation
  - Key generation produces valid output
  - Generated keys can be parsed back (round-trip)

- [ ] **`KnownHostsService` tests**
  - Fingerprint calculation from public key data
  - Host matching logic
  - Fingerprint comparison

### Phase 4: Store Tests

- [ ] **`HostStore` tests**
  - Add/update/delete hosts
  - Persistence to UserDefaults (mock)
  - Sorting (favorites first, then recent)
  - Favorite toggling

- [ ] **`SSHKeyStore` tests**
  - Add/delete keys
  - Persistence to UserDefaults (mock)
  - Sorting by creation date
  - Key lookup by ID

- [ ] **`Settings` tests**
  - Theme color scheme mapping
  - Auto-lock timeout logic
  - Persistence to UserDefaults (mock)

## Files to Create

- `conduitTests/` directory
- `conduitTests/HostTests.swift`
- `conduitTests/SSHKeyTests.swift`
- `conduitTests/KnownHostTests.swift`
- `conduitTests/SSHKeyServiceTests.swift`
- `conduitTests/KnownHostsServiceTests.swift`
- `conduitTests/HostStoreTests.swift`
- `conduitTests/SSHKeyStoreTests.swift`
- `conduitTests/SettingsTests.swift`
- `conduitTests/Mocks/MockUserDefaults.swift`

## Files to Modify

- `Makefile` - add `test` target
- `conduit.xcodeproj` - add test target

## Technical Notes

### Test Fixtures

Include test key fixtures for parsing tests:

```swift
enum TestKeys {
    static let unencryptedEd25519 = """
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----
    """

    static let encryptedEd25519 = """
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...  // bcrypt encrypted
    -----END OPENSSH PRIVATE KEY-----
    """

    static let legacyEncryptedRSA = """
    -----BEGIN RSA PRIVATE KEY-----
    Proc-Type: 4,ENCRYPTED
    ...
    -----END RSA PRIVATE KEY-----
    """
}
```

### Dependency Injection

For testability, services that access Keychain or UserDefaults should accept these as dependencies:

```swift
final class HostStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}
```

### What NOT to Test

- Keychain operations (requires simulator + entitlements)
- Biometric authentication
- SwiftUI views
- SSH connections
- File system access

## Acceptance Criteria

- [ ] `make test` runs all unit tests
- [ ] Tests pass without requiring simulator
- [ ] Model Codable round-trips verified
- [ ] SSHKeyService parsing logic covered
- [ ] Store CRUD operations verified
- [ ] Tests run in < 10 seconds
