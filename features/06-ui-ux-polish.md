# UI/UX Polish

**Priority:** 6 (Visual Polish)
**Effort:** Medium
**Impact:** Medium - Professional appearance

## Problem

Current UI is functional but basic:

- Default SwiftUI styling
- No theming options
- Limited terminal customization
- Host list could be more informative
- Not using iOS 26's Liquid Glass design language

## Solution

Modernize UI with Apple's Liquid Glass styling and add customization options.

## Tasks

### Phase 1: Liquid Glass Design System

- [ ] **Adopt Liquid Glass materials**
  - Use `.glassEffect()` modifier for translucent surfaces
  - Apply to navigation bars, toolbars, sheets
  - Frosted glass backgrounds with adaptive tinting
  - Ensure proper contrast with terminal content

- [ ] **Update host list**
  - Glass-effect sidebar
  - Translucent host rows with subtle blur
  - Adaptive colors that respond to content behind

- [ ] **Update terminal chrome**
  - Glass-effect navigation bar
  - Translucent disconnect button
  - Glass status overlays

- [ ] **Sheets and modals**
  - Glass-effect backgrounds
  - Smooth corner radius
  - Proper depth and layering

### Phase 2: Terminal Appearance

- [ ] **Theme support**
  - Dark theme (current default)
  - Light theme option
  - Popular terminal themes: Dracula, Solarized, Nord, Monokai
  - Store theme preference per-host or globally

- [ ] **Font customization**
  - Font size picker
  - Font family selection (system monospace fonts)
  - Preview in settings

- [ ] **Terminal colors**
  - Customize ANSI color palette
  - Background/foreground colors
  - Cursor color and style

### Phase 3: Host List Polish

- [ ] **Improved host rows**
  - Connection status indicator (colored dot with glass effect)
  - Last connected timestamp
  - Favorite/pin option
  - Host grouping/folders

- [ ] **Empty states**
  - Better onboarding for first-time users
  - Illustration with glass styling
  - Helpful tips

- [ ] **Search/filter**
  - Glass-effect search bar
  - Search hosts by name/hostname
  - Filter by group/tag

### Phase 4: Connection States

- [ ] **Better status indicators**
  - Connecting: animated spinner with glass overlay
  - Connected: subtle glass status bar
  - Error: glass card with error details and retry action
  - Disconnected: glass reconnect prompt

- [ ] **Connection info overlay**
  - Glass-effect info card
  - Show current user@host
  - Connection duration
  - Quick actions (disconnect, info)

### Phase 5: App Icon & Branding

- [ ] **Custom app icon**
  - Design terminal/SSH themed icon
  - Consider glass-like icon style
  - Multiple color variants

- [ ] **Launch screen**
  - Branded launch screen
  - Quick fade to app

### Phase 6: Keyboard Accessory Bar (Related to Feature 03)

- [ ] **Glass-effect accessory bar**
  - Dark translucent background
  - Buttons with glass effect
  - Matches terminal aesthetic

## Technical Notes

iOS 26 Liquid Glass APIs:

```swift
// Basic glass effect
.glassEffect()

// Customized glass
.glassEffect(.regular.tint(.blue))

// Glass background
.background(.ultraThinMaterial)
.background(.regularMaterial)
.background(.thickMaterial)
```

## Acceptance Criteria

- [ ] UI uses Liquid Glass materials throughout
- [ ] Glass effects adapt to content behind them
- [ ] At least 3 terminal themes available
- [ ] Font size adjustable
- [ ] Host list shows connection status
- [ ] Smooth state transitions with glass overlays
- [ ] Consistent visual language throughout
- [ ] Follows Apple's iOS 26 design guidelines
