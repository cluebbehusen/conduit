# Keyboard Accessory Bar Styling

**Priority:** 3 (iPad UX Polish)
**Effort:** Small-Medium
**Impact:** Medium - Visual polish

## Problem

SwiftTerm's built-in accessory bar works but looks dated:
- Light gray background clashes with dark terminal
- Button styling doesn't match app theme
- No customization options

## Solution

Style the accessory bar to match the terminal aesthetic, or replace with custom implementation.

## Tasks

### Option A: Style SwiftTerm's Bar

- [ ] **Investigate SwiftTerm customization**
  - Check if TerminalView exposes accessory bar styling
  - Look for color/font properties
  - Check if we can access the UIInputView

- [ ] **Apply dark theme**
  - Dark background matching terminal
  - Light text on buttons
  - Subtle borders/separators

### Option B: Custom Accessory Bar

- [ ] **Create `TerminalAccessoryView`**
  - Custom UIInputView subclass
  - Dark themed to match terminal
  - Same keys: Esc, Ctrl, Tab, ~, |, /, -, F1-F8, arrows

- [ ] **Style buttons**
  - Dark background (#1a1a1a or similar)
  - Rounded buttons with subtle borders
  - Proper spacing and padding
  - Highlight state for Ctrl toggle

- [ ] **Replace SwiftTerm's bar**
  - Disable built-in accessory
  - Attach custom view as inputAccessoryView

### Phase 2: Customization (Optional)

- [ ] **User preferences**
  - Show/hide specific keys
  - Reorder keys
  - Add custom keys/macros

## Files to Create/Modify

- `Views/TerminalAccessoryView.swift` (new, if Option B)
- `Views/SwiftTermView.swift`

## Reference

Current bar has: esc, ctrl, →|, ~, |, /, -, F1-F8, ←↑↓→, touchpad, keyboard toggle

## Acceptance Criteria

- [ ] Accessory bar has dark theme matching terminal
- [ ] Buttons are clearly visible and tappable
- [ ] Ctrl toggle state is visually clear
- [ ] Consistent with overall app aesthetic
