# SSH Key Authentication

**Priority:** 4 (Security & Compatibility)
**Effort:** Medium-Large
**Impact:** High - Many servers require key auth

## Problem

Currently only password authentication is supported. Many servers:
- Disable password auth entirely
- Require key-based authentication
- Use keys for automation/security

## Solution

Support SSH key pairs with secure storage and optional passphrase protection.

## Tasks

### Phase 1: Import Existing Keys

- [ ] **Create `SSHKeyService`**
  - Parse PEM/OpenSSH private key formats
  - Support RSA, Ed25519, ECDSA key types
  - Handle passphrase-protected keys
  - Store private keys in Keychain (secure enclave if available)

- [ ] **Add key import UI**
  - Import from Files app (document picker)
  - Paste key text directly
  - Passphrase prompt if encrypted
  - Name/label the key

- [ ] **Update `Host` model**
  - Add `selectedKeyId: UUID?` for key-based auth
  - Update `AuthMethod` to include `.key(keyId: UUID)`

### Phase 2: Key Management

- [ ] **Create `KeyListView`**
  - List all stored keys
  - Show key type, fingerprint, creation date
  - Delete keys
  - View public key (for adding to servers)

- [ ] **Update `HostEditView`**
  - Auth method picker: Password / Key
  - Key selector dropdown
  - "Manage Keys" link

### Phase 3: Generate Keys

- [ ] **Key generation**
  - Generate Ed25519 keys (recommended)
  - Generate RSA keys (legacy compatibility)
  - Optional passphrase protection
  - Export public key for server setup

- [ ] **Add to `KeyListView`**
  - "Generate New Key" button
  - Key type picker
  - Passphrase optional input
  - Show/copy public key after generation

### Phase 4: Connect with Keys

- [ ] **Update `SSHService`**
  - Load key from Keychain
  - Prompt for passphrase if needed
  - Use Citadel's key-based auth method
  - Handle auth failures gracefully

## Files to Create/Modify

- `Services/SSHKeyService.swift` (new)
- `Models/SSHKey.swift` (new)
- `Views/KeyListView.swift` (new)
- `Views/KeyImportView.swift` (new)
- `Views/HostEditView.swift`
- `Services/SSHService.swift`
- `Models/Host.swift`

## Technical Notes

Citadel supports key auth via:
```swift
.init(username: "user", privateKey: .init(sshEd25519: keyData))
```

Key types to support:
- Ed25519 (modern, recommended)
- RSA (legacy, widely supported)
- ECDSA (less common)

## Acceptance Criteria

- [ ] Can import existing private key from file
- [ ] Can import passphrase-protected keys
- [ ] Can generate new key pair
- [ ] Keys stored securely in Keychain
- [ ] Can connect to server using key auth
- [ ] Can view/copy public key for server setup
- [ ] Passphrase prompted only when needed
