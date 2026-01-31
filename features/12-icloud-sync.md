# iCloud Sync

**Priority:** 12 (Convenience)
**Effort:** Medium
**Impact:** Medium - Multi-device users

## Problem

Host configurations only exist on one device. Users with multiple iPads/iPhones need to manually recreate hosts.

## Solution

Sync hosts (not credentials) via iCloud.

## Tasks

### Phase 1: CloudKit Setup

- [ ] **Enable CloudKit**
  - Add iCloud capability to project
  - Create CloudKit container
  - Define record types

- [ ] **Create sync service**
  - `CloudSyncService` to handle iCloud operations
  - Map Host model to CloudKit records
  - Handle conflicts

### Phase 2: Host Sync

- [ ] **Upload hosts**
  - Sync new hosts to iCloud
  - Update modified hosts
  - Delete removed hosts

- [ ] **Download hosts**
  - Fetch hosts from iCloud on launch
  - Merge with local hosts
  - Handle duplicates (by hostname+username)

### Phase 3: Conflict Resolution

- [ ] **Detect conflicts**
  - Same host modified on multiple devices
  - Timestamp-based resolution
  - Or prompt user to choose

- [ ] **Merge strategy**
  - Last-write-wins (simple)
  - Or manual merge UI

### Phase 4: Settings Sync (Optional)

- [ ] **Sync preferences**
  - Theme settings
  - Global snippets
  - App preferences

## Files to Create/Modify

- `Services/CloudSyncService.swift` (new)
- `Models/HostStore.swift`
- `conduit.entitlements` (iCloud capability)

## Security Notes

- **DO NOT sync credentials** - Keychain doesn't sync automatically
- Only sync: host names, hostnames, ports, usernames
- Credentials stay local to each device's Keychain

## Acceptance Criteria

- [ ] Hosts appear on all devices with same iCloud account
- [ ] New host on device A appears on device B
- [ ] Deleted host syncs across devices
- [ ] Credentials NOT synced (security)
- [ ] Works offline, syncs when online
