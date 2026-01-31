# Auto Reconnect

**Priority:** 14 (Quality of Life)
**Effort:** Small
**Impact:** Medium - Reliability

## Problem

When connection drops (network issues, server restart, sleep/wake), user must manually reconnect.

## Solution

Automatically detect disconnection and attempt reconnection.

## Tasks

### Phase 1: Detect Disconnection

- [ ] **Improve disconnect detection**
  - Network reachability monitoring
  - SSH keepalive packets
  - Detect various disconnect causes

- [ ] **Classify disconnect type**
  - User-initiated (don't auto-reconnect)
  - Network loss (reconnect when network returns)
  - Server closed (offer reconnect)
  - Timeout (attempt reconnect)

### Phase 2: Reconnection Logic

- [ ] **Auto-reconnect on network loss**
  - Wait for network to return
  - Attempt reconnection automatically
  - Show "Reconnecting..." status

- [ ] **Retry with backoff**
  - Attempt immediately once
  - Then wait 1s, 2s, 4s, 8s... (exponential backoff)
  - Max retry attempts configurable
  - Stop on auth failure (don't hammer server)

### Phase 3: User Feedback

- [ ] **Reconnection UI**
  - "Connection lost. Reconnecting..." message
  - Show retry count
  - Manual "Retry now" button
  - "Cancel" to give up

- [ ] **Notification**
  - Optional notification when reconnected
  - Notification when all retries exhausted

### Phase 4: Settings

- [ ] **User preferences**
  - Enable/disable auto-reconnect
  - Max retry attempts
  - Retry timeout

## Files to Create/Modify

- `Services/SSHService.swift`
- `Services/NetworkMonitor.swift` (new)
- `Views/TerminalContainerView.swift`

## Technical Notes

Use NWPathMonitor for network reachability:
```swift
let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    if path.status == .satisfied {
        // Network available, attempt reconnect
    }
}
```

## Acceptance Criteria

- [ ] Detects when connection is lost
- [ ] Automatically attempts to reconnect
- [ ] Shows reconnection status to user
- [ ] Stops retrying after max attempts
- [ ] Reconnects when network returns
- [ ] Can disable auto-reconnect in settings
