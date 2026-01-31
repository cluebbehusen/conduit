# Multiple Sessions / Tabs

**Priority:** 7 (Power Feature)
**Effort:** Large
**Impact:** High - Essential for power users

## Problem

Can only have one terminal session at a time. Users need to:

- Connect to multiple servers simultaneously
- Have multiple sessions to same server
- Switch between sessions quickly

## Solution

Implement tabbed interface for multiple concurrent SSH sessions.

## Tasks

### Phase 1: Session Management

- [ ] **Create `SessionManager`**
  - Track multiple active sessions
  - Each session has: id, host, SSHService, connection state
  - Limit max concurrent sessions (memory management)

- [ ] **Update data model**
  - `Session`: id, hostId, createdAt, title
  - Session state independent of SSHService

### Phase 2: Tab UI

- [ ] **Create tab bar**
  - Horizontal scrollable tabs above terminal
  - Show host name or custom title
  - Close button on each tab
  - "+" button to add new session

- [ ] **Tab interactions**
  - Tap to switch
  - Long-press for options (rename, close, duplicate)
  - Swipe to close (optional)
  - Reorder via drag (optional)

### Phase 3: Session Switching

- [ ] **Preserve terminal state**
  - Keep TerminalView instances alive when switching
  - Maintain scroll position and content
  - Handle memory pressure (discard oldest inactive)

- [ ] **Quick switcher**
  - Keyboard shortcut: Cmd+1-9 for tabs
  - Cmd+Tab to cycle
  - Cmd+Shift+] and Cmd+Shift+[ to navigate

### Phase 4: Visual Indicators

- [ ] **Tab status**
  - Activity indicator (output received while inactive)
  - Connection status color
  - Bell/alert indicator

- [ ] **Badge on app icon**
  - Show number of active sessions (optional)

## Files to Create/Modify

- `Services/SessionManager.swift` (new)
- `Models/Session.swift` (new)
- `Views/SessionTabBar.swift` (new)
- `Views/TerminalContainerView.swift`
- `Views/HostListView.swift`

## Technical Considerations

- Memory: Each TerminalView holds scrollback buffer
- Consider lazy loading / unloading inactive sessions
- SwiftTerm may need multiple instances

## Acceptance Criteria

- [ ] Can open multiple sessions to different hosts
- [ ] Can open multiple sessions to same host
- [ ] Tabs show host name and status
- [ ] Switching preserves terminal content
- [ ] Can close individual sessions
- [ ] Keyboard shortcuts work (with hardware keyboard)
