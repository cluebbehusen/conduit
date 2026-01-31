# Keychain Storage with Face ID / Touch ID

**Priority:** 2 (Security Essential)
**Effort:** Medium
**Impact:** High - Secure credential storage

## Problem

Passwords are currently entered every time. Users want to save credentials securely.

## Solution

Store credentials in iOS Keychain with biometric protection.

## Dependencies

Consider using [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) for cleaner API, or use Security framework directly.

## Tasks

### Phase 1: Keychain Storage

- [ ] **Create `KeychainService`**
  - Save password for host (keyed by host ID)
  - Retrieve password for host
  - Delete password for host
  - Handle Keychain errors gracefully

- [ ] **Update `Host` model**
  - Add `hasStoredCredential: Bool` computed property
  - Don't store password in UserDefaults (keep in Keychain only)

- [ ] **Update `HostEditView`**
  - Add optional password field
  - Toggle for "Save password"
  - Save to Keychain on host save

### Phase 2: Biometric Unlock

- [ ] **Add biometric authentication**
  - Use `LAContext` from LocalAuthentication framework
  - Prompt for Face ID / Touch ID before retrieving password
  - Fall back to device passcode

- [ ] **Update `TerminalContainerView`**
  - If credentials stored, attempt biometric unlock
  - On success, connect automatically
  - On failure/cancel, show password prompt

### Phase 3: Settings

- [ ] **Add security settings**
  - Option to require biometrics for all connections
  - Option to clear all stored credentials
  - Auto-lock timeout option

## Files to Create/Modify

- `Services/KeychainService.swift` (new)
- `Models/Host.swift`
- `Views/HostEditView.swift`
- `Views/TerminalContainerView.swift`

## Acceptance Criteria

- [ ] Can save password when creating/editing host
- [ ] Saved passwords stored in Keychain (not UserDefaults)
- [ ] Face ID / Touch ID prompt before auto-connecting
- [ ] Can delete stored credentials
- [ ] Graceful fallback if biometrics unavailable
