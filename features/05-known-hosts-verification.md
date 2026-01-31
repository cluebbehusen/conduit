# Known Hosts Verification

**Priority:** 5 (Security)
**Effort:** Small-Medium
**Impact:** Medium - Prevents MITM attacks

## Problem

Currently using `.acceptAnything()` for host key validation:

```swift
hostKeyValidator: .acceptAnything()
```

This is insecure - vulnerable to man-in-the-middle attacks. Users should verify and trust host keys.

## Solution

Implement known_hosts style verification with trust-on-first-use (TOFU) and change detection.

## Tasks

### Phase 1: Store Known Hosts

- [ ] **Create `KnownHostsService`**
  - Store host fingerprints (keyed by hostname:port)
  - Use UserDefaults or separate file
  - Support multiple key types per host

- [ ] **Create fingerprint model**
  - `KnownHost`: hostname, port, keyType, fingerprint, firstSeen, lastSeen
  - Compute SHA256 fingerprint from public key

### Phase 2: Trust on First Use

- [ ] **Create `HostKeyVerificationView`**
  - Show host fingerprint on first connection
  - "Trust" / "Cancel" buttons
  - Display key type and fingerprint clearly
  - Warn this is first connection

- [ ] **Update `SSHService`**
  - Implement custom `hostKeyValidator`
  - Check against known hosts
  - If new: prompt user, await decision
  - If known: verify match
  - If changed: warn user (potential attack)

### Phase 3: Host Key Changed Warning

- [ ] **Create `HostKeyChangedView`**
  - Strong warning: key has changed
  - Show old vs new fingerprint
  - Explain MITM risk
  - "Trust New Key" / "Cancel" buttons
  - Require explicit confirmation

### Phase 4: Management

- [ ] **Add known hosts management**
  - View all trusted hosts
  - See fingerprints and first-seen dates
  - Remove trusted hosts
  - Export/import known_hosts file (optional)

## Files to Create/Modify

- `Services/KnownHostsService.swift` (new)
- `Models/KnownHost.swift` (new)
- `Views/HostKeyVerificationView.swift` (new)
- `Views/HostKeyChangedView.swift` (new)
- `Services/SSHService.swift`

## Technical Notes

Citadel's `hostKeyValidator` parameter accepts custom validators:

```swift
hostKeyValidator: .custom { hostKey in
    // Verify against known hosts
    // Return true to accept, false to reject
}
```

## Acceptance Criteria

- [ ] First connection shows fingerprint for approval
- [ ] Approved fingerprints stored persistently
- [ ] Subsequent connections auto-verify silently
- [ ] Changed host key shows strong warning
- [ ] Can view and manage known hosts
- [ ] Connection rejected if user declines
