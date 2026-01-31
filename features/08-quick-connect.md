# Quick Connect

**Priority:** 8 (Convenience)
**Effort:** Small
**Impact:** Medium - Faster workflow

## Problem

To connect to a new server, must:
1. Tap "+"
2. Fill out form (name, hostname, port, username)
3. Save
4. Select from list
5. Enter password

This is slow for one-off connections.

## Solution

Add quick connect bar for immediate connections without saving.

## Tasks

### Phase 1: Quick Connect UI

- [ ] **Add quick connect option**
  - Text field in host list: "user@hostname"
  - Parse standard SSH format: `user@host:port`
  - Default port 22 if omitted
  - Connect immediately on submit

- [ ] **Smart parsing**
  - `hostname` → prompt for username
  - `user@hostname` → use default port
  - `user@hostname:port` → full specification
  - `ssh://user@hostname:port` → handle URL scheme

### Phase 2: History

- [ ] **Recent connections**
  - Store last N quick connects
  - Show as suggestions while typing
  - Tap to reconnect
  - Clear history option

### Phase 3: URL Scheme

- [ ] **Handle SSH URLs**
  - Register `ssh://` URL scheme
  - Open app and connect from Safari, other apps
  - Format: `conduit://connect?host=x&user=y&port=z`

### Phase 4: Save from Quick Connect

- [ ] **Promote to saved host**
  - After connecting, offer "Save this host"
  - Pre-fill form with connection details
  - Optionally save password

## Files to Create/Modify

- `Views/QuickConnectView.swift` (new)
- `Views/HostListView.swift`
- `Models/RecentConnection.swift` (new)
- `conduitApp.swift` (URL handling)
- `Info.plist` (URL scheme registration)

## Acceptance Criteria

- [ ] Can type `user@host` and connect immediately
- [ ] Port parsing works correctly
- [ ] Recent connections shown as suggestions
- [ ] Can save quick connection as host
- [ ] URL scheme opens and connects (optional)
