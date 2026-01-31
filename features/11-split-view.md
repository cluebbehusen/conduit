# Split View

**Priority:** 11 (Power Feature)
**Effort:** Large
**Impact:** Medium - Power user feature

## Problem

Can only see one terminal at a time. Users want to:
- Compare output from two servers
- Monitor logs while running commands
- Reference one session while working in another

## Solution

Split terminal view horizontally or vertically.

## Tasks

### Phase 1: Basic Split

- [ ] **Split container view**
  - Horizontal split (side by side)
  - Vertical split (top/bottom)
  - Draggable divider to resize
  - Minimum pane size

- [ ] **Split actions**
  - Menu/button to split current view
  - Choose direction
  - New pane connects to same host or shows picker

### Phase 2: Split Management

- [ ] **Focus handling**
  - Visual indicator of active pane
  - Tap to focus
  - Keyboard input goes to focused pane

- [ ] **Close/unsplit**
  - Close one pane, expand other
  - Close button on each pane
  - Drag divider to edge to close

### Phase 3: Advanced Layouts

- [ ] **Multiple splits**
  - Split already-split panes
  - Support 2x2 grid
  - Limit max panes (4?)

- [ ] **Layout presets**
  - 50/50 horizontal
  - 50/50 vertical
  - 70/30 main + sidebar

### Phase 4: iPad Multitasking Integration

- [ ] **System split view**
  - Support iPad's native split view
  - Two Conduit instances side by side
  - Slide Over support

## Files to Create/Modify

- `Views/SplitTerminalView.swift` (new)
- `Views/TerminalContainerView.swift`
- `Views/HostListView.swift`

## Technical Considerations

- Each split needs its own SSHService instance
- Memory usage doubles/triples
- Keyboard routing to correct pane
- SwiftUI nested split views can be tricky

## Acceptance Criteria

- [ ] Can split view horizontally
- [ ] Can split view vertically
- [ ] Can resize panes by dragging
- [ ] Can close split and return to single view
- [ ] Active pane clearly indicated
- [ ] Keyboard input routes correctly
