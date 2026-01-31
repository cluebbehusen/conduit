# Snippets / Saved Commands

**Priority:** 10 (Power Feature)
**Effort:** Medium
**Impact:** Medium - Productivity boost

## Problem

Users repeatedly type the same commands:

- Deploy scripts
- Log file locations
- Complex pipelines
- Server-specific commands

## Solution

Save and organize frequently used commands as snippets.

## Tasks

### Phase 1: Basic Snippets

- [ ] **Create `Snippet` model**
  - id, name, command, hostId (optional), createdAt
  - Global snippets vs host-specific

- [ ] **Create `SnippetStore`**
  - CRUD operations
  - Persist to UserDefaults or file
  - Search/filter snippets

- [ ] **Snippets list view**
  - View all snippets
  - Add/edit/delete
  - Organize by host or category

### Phase 2: Quick Access

- [ ] **Snippet picker in terminal**
  - Toolbar button or gesture
  - Searchable list
  - Tap to insert into terminal
  - Option to execute immediately

- [ ] **Keyboard shortcut**
  - Cmd+Shift+P: Open snippet picker
  - Type to filter
  - Enter to insert

### Phase 3: Smart Snippets

- [ ] **Variables/placeholders**
  - `${cursor}` - cursor position after insert
  - `${clipboard}` - paste clipboard content
  - `${prompt:Name}` - ask user for value
  - `${date}`, `${hostname}` - auto-fill

- [ ] **Multi-line snippets**
  - Support heredocs
  - Preserve formatting

### Phase 4: Organization

- [ ] **Categories/folders**
  - Group snippets
  - Collapse/expand in list

- [ ] **Import/export**
  - Share snippets as JSON
  - Import from file

## Files to Create/Modify

- `Models/Snippet.swift` (new)
- `Models/SnippetStore.swift` (new)
- `Views/SnippetListView.swift` (new)
- `Views/SnippetEditView.swift` (new)
- `Views/SnippetPickerView.swift` (new)
- `Views/TerminalContainerView.swift`

## Acceptance Criteria

- [ ] Can create and save snippets
- [ ] Can access snippets from terminal view
- [ ] Snippets can be global or host-specific
- [ ] Can search/filter snippets
- [ ] Tap inserts command into terminal
