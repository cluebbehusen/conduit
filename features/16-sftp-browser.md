# SFTP File Browser

**Priority:** 16 (Major Feature)
**Effort:** Extra Large
**Impact:** High - Complete SSH experience

## Problem

Can't browse or transfer files over SSH connection. Users need to:

- Browse remote file system
- Download files to iPad
- Upload files from iPad
- Edit remote files

## Solution

Implement SFTP client with file browser UI.

## Tasks

### Phase 1: SFTP Connection

- [ ] **Create `SFTPService`**
  - Establish SFTP subsystem over SSH
  - List directories
  - Get file info
  - Read/write files

- [ ] **Use Citadel's SFTP support**
  - `client.openSFTP()` for SFTP session
  - Handle connection lifecycle

### Phase 2: File Browser UI

- [ ] **Directory listing view**
  - Show files and folders
  - File icons by type
  - File size, modification date
  - Sort options (name, date, size)

- [ ] **Navigation**
  - Tap folder to enter
  - Back button / breadcrumb
  - Path bar for direct navigation
  - Bookmarks for common locations

### Phase 3: File Operations

- [ ] **Download files**
  - Download to Files app
  - Progress indicator
  - Background download for large files

- [ ] **Upload files**
  - Pick from Files app
  - Pick from Photos
  - Drag and drop (iPad)
  - Progress indicator

- [ ] **File management**
  - Rename files
  - Delete files
  - Create directories
  - Move/copy (within remote)

### Phase 4: Quick Edit

- [ ] **View files**
  - Quick Look preview for supported types
  - Text file viewer

- [ ] **Edit text files**
  - Simple text editor
  - Save back to server
  - Syntax highlighting (optional)

### Phase 5: Integration

- [ ] **Access from terminal**
  - Button to open SFTP for current connection
  - Share SSH connection

- [ ] **Files app integration**
  - File Provider extension
  - Browse remote files in Files app

## Files to Create/Modify

- `Services/SFTPService.swift` (new)
- `Views/SFTPBrowserView.swift` (new)
- `Views/SFTPFileRow.swift` (new)
- `Views/FilePreviewView.swift` (new)
- `Views/TextEditorView.swift` (new)
- `Views/TerminalContainerView.swift`

## Technical Notes

Citadel SFTP example:

```swift
let sftp = try await client.openSFTP()
let files = try await sftp.listDirectory(atPath: "/home/user")
let data = try await sftp.readFile(atPath: "/etc/hosts")
```

## Acceptance Criteria

- [ ] Can browse remote directories
- [ ] Can download files to iPad
- [ ] Can upload files from iPad
- [ ] Can delete/rename files
- [ ] Can preview common file types
- [ ] Progress shown for transfers
