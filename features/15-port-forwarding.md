# Port Forwarding

**Priority:** 15 (Advanced Feature)
**Effort:** Large
**Impact:** Medium - Developer/power user feature

## Problem

Users need to:
- Access remote services through SSH tunnel
- Forward local ports to remote servers
- Create reverse tunnels

## Solution

Implement local and remote port forwarding.

## Tasks

### Phase 1: Local Port Forwarding

- [ ] **Implement local forwarding**
  - Bind local port
  - Forward connections through SSH to remote host:port
  - Standard `-L` behavior: `localPort:remoteHost:remotePort`

- [ ] **Create `PortForward` model**
  - type: local/remote
  - localPort, remoteHost, remotePort
  - enabled state
  - Associated host

### Phase 2: Forward Management UI

- [ ] **Add forwarding to host config**
  - List of port forwards per host
  - Add/remove forwards
  - Enable/disable individual forwards

- [ ] **Active forwards view**
  - Show currently active tunnels
  - Connection count per forward
  - Stop individual forwards

### Phase 3: Remote Port Forwarding

- [ ] **Implement remote forwarding**
  - Standard `-R` behavior
  - Bind on remote, forward to local

### Phase 4: Dynamic Forwarding (SOCKS)

- [ ] **SOCKS proxy support**
  - Standard `-D` behavior
  - Create local SOCKS5 proxy
  - Route through SSH connection

## Files to Create/Modify

- `Models/PortForward.swift` (new)
- `Services/PortForwardService.swift` (new)
- `Views/PortForwardListView.swift` (new)
- `Views/HostEditView.swift`
- `Services/SSHService.swift`

## Technical Notes

Citadel supports port forwarding:
```swift
try await client.createDirectTCPIPChannel(
    to: remoteHost,
    port: remotePort
)
```

## Acceptance Criteria

- [ ] Can create local port forward
- [ ] Can access remote services via forwarded port
- [ ] Can create remote port forward
- [ ] Forwards start automatically with connection
- [ ] Can see active forwards and stop them
