# Search Terminal Scrollback

**Priority:** 9 (Quality of Life)
**Effort:** Small-Medium
**Impact:** Medium - Common need

## Problem

Can't search through terminal output. Users need to:
- Find previous command output
- Search for errors in logs
- Locate specific text in long output

## Solution

Add search functionality for terminal scrollback buffer.

## Tasks

### Phase 1: Basic Search

- [ ] **Add search bar**
  - Cmd+F or toolbar button to show
  - Text input with search field
  - Dismiss on Escape or tap outside

- [ ] **Implement search**
  - Query SwiftTerm's buffer
  - Highlight all matches
  - Navigate between matches (next/prev)
  - Show match count

### Phase 2: Search UX

- [ ] **Keyboard shortcuts**
  - Cmd+F: Open search
  - Cmd+G: Next match
  - Cmd+Shift+G: Previous match
  - Escape: Close search

- [ ] **Visual feedback**
  - Highlight current match distinctly
  - Scroll to match
  - Dim non-matching content (optional)

### Phase 3: Advanced Search (Optional)

- [ ] **Search options**
  - Case sensitive toggle
  - Regex support
  - Search direction

## Files to Create/Modify

- `Views/TerminalSearchBar.swift` (new)
- `Views/SwiftTermView.swift`
- `Views/TerminalContainerView.swift`

## Technical Notes

SwiftTerm's Terminal class has search capabilities:
- `search(for:)` method
- Access via `terminalView.getTerminal()`

## Acceptance Criteria

- [ ] Can open search with Cmd+F
- [ ] Matches highlighted in terminal
- [ ] Can navigate between matches
- [ ] Match count displayed
- [ ] Search bar doesn't block terminal
