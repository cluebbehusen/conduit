# Session Logging / Export

**Priority:** 13 (Quality of Life)
**Effort:** Small
**Impact:** Low-Medium - Audit/debugging

## Problem

No way to:
- Save terminal output for later review
- Share session transcript
- Audit what commands were run
- Debug issues after the fact

## Solution

Log session output to file with export options.

## Tasks

### Phase 1: Basic Logging

- [ ] **Create `SessionLogger`**
  - Write terminal output to file
  - Timestamp each chunk
  - Store in app's documents directory

- [ ] **Toggle logging**
  - Per-session logging toggle
  - Or global setting to always log
  - Visual indicator when logging

### Phase 2: Log Management

- [ ] **View past sessions**
  - List logged sessions
  - Show host, date, duration, size
  - Preview content

- [ ] **Log viewer**
  - View full log content
  - Scrollable text view
  - Search within log

### Phase 3: Export

- [ ] **Export options**
  - Share as plain text
  - Share as timestamped log
  - Export to Files app
  - Copy to clipboard

- [ ] **Format options**
  - Raw text (with ANSI codes stripped)
  - With timestamps
  - HTML (preserve colors)

### Phase 4: Auto-cleanup

- [ ] **Storage management**
  - Auto-delete logs older than X days
  - Limit total log storage
  - Manual cleanup option

## Files to Create/Modify

- `Services/SessionLogger.swift` (new)
- `Views/SessionLogsView.swift` (new)
- `Views/LogViewerView.swift` (new)
- `Views/TerminalContainerView.swift`

## Acceptance Criteria

- [ ] Can enable logging for a session
- [ ] Logs saved with timestamp and host info
- [ ] Can view past session logs
- [ ] Can export/share logs
- [ ] Storage doesn't grow unbounded
