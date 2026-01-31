# Graceful Exit Handling

**Priority:** 1 (Bug Fix)
**Effort:** Small
**Impact:** High - Fixes confusing UX

## Problem

When user types `exit` or the remote shell closes cleanly, the app shows:
- "Connection Error"
- "The operation couldn't be completed. (NIOCore.ChannelError error 6.)"

This is incorrect - a clean exit isn't an error.

## Solution

Detect clean disconnection vs actual errors in `SSHService`.

## Tasks

- [ ] **Identify clean exit signals**
  - SSH channel EOF with exit code 0 = clean exit
  - Channel closed by remote = clean exit
  - Differentiate from connection drops, auth failures, timeouts

- [ ] **Update `SSHService` state handling**
  - Add `ConnectionState.disconnected(reason: DisconnectReason)` enum
  - `DisconnectReason`: `.userInitiated`, `.remoteExit`, `.error(String)`
  - Update stream handling to detect exit code from PTY

- [ ] **Update `TerminalContainerView` UI**
  - Show "Session ended" for clean exits (not error styling)
  - Offer "Reconnect" button
  - Only show error styling for actual errors

## Files to Modify

- `Services/SSHService.swift`
- `Views/TerminalContainerView.swift`

## Acceptance Criteria

- [ ] Typing `exit` shows "Session ended" with reconnect option
- [ ] Connection timeout shows error with details
- [ ] Auth failure shows error with details
- [ ] Network drop shows error with details
