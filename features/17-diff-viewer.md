# Diff Viewer

**Priority:** 17 (Niche Feature)
**Effort:** Medium-Large
**Impact:** Low-Medium - Developer convenience

## Problem

Git diffs and file comparisons in terminal are hard to read:
- No syntax highlighting
- Hard to see additions/deletions
- No side-by-side view

## Solution

Detect and render diffs with proper formatting and colors.

## Tasks

### Phase 1: Diff Detection

- [ ] **Detect diff output**
  - Recognize unified diff format
  - Recognize git diff output
  - Trigger on `git diff`, `diff` commands

- [ ] **Parse diff format**
  - Extract hunks
  - Identify additions (+), deletions (-), context
  - Parse file headers

### Phase 2: Inline Rendering

- [ ] **Enhanced terminal rendering**
  - Color additions green
  - Color deletions red
  - Highlight changed words within lines
  - Better than default git colors

### Phase 3: Dedicated Diff View

- [ ] **Diff viewer modal**
  - Option to open diff in dedicated view
  - Syntax highlighting for code
  - Line numbers

- [ ] **Side-by-side view**
  - Before/after columns
  - Synchronized scrolling
  - Collapsible unchanged sections

### Phase 4: Interactive Features

- [ ] **Navigation**
  - Jump to next/previous hunk
  - Jump to specific file
  - Collapse/expand files

- [ ] **Actions**
  - Copy diff
  - Share diff
  - Apply to other file (patch)

## Files to Create/Modify

- `Services/DiffParser.swift` (new)
- `Views/DiffViewerView.swift` (new)
- `Views/DiffHunkView.swift` (new)
- `Views/SwiftTermView.swift` (for detection)

## Technical Considerations

Two approaches:
1. **Intercept command output** - Complex, need to detect command
2. **Manual trigger** - User pipes to diff viewer, simpler

Start with manual trigger, consider auto-detection later.

## Acceptance Criteria

- [ ] Can view diffs with syntax highlighting
- [ ] Additions/deletions clearly colored
- [ ] Can switch between unified and side-by-side
- [ ] Can navigate between hunks
- [ ] Works with git diff output
