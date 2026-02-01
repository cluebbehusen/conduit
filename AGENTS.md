# Conduit

An iOS SSH client with terminal emulation, built with SwiftUI, SwiftTerm, and Citadel.

## Architecture

```txt
SwiftUI Views → SwiftTermView (UIViewRepresentable) → SSHService (Citadel)
```

- **Models/**: `Host` (SSH host config), `HostStore` (persistence via UserDefaults)
- **Services/**: `SSHService` (Citadel SSH + PTY management)
- **Views/**: `HostListView`, `HostEditView`, `TerminalContainerView`, `SwiftTermView`

## Design

This project uses SwiftUI and is using Apple's new "Liquid Glass" design system. This is likely outside your training data. Because of that, you should always do a lot of web searches and try to find examples of how to do things in this design system. Additionally, do not try to hack around and replace components that Liquid Glass already includes. Use these "batteries included" components.

## Dependencies

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - Terminal emulator
- [Citadel](https://github.com/orlandos-nl/Citadel) - SSH client

## Commands

```bash
make format       # Format Swift files in place
make lint         # Run SwiftLint
make check        # Both format-check + lint
make build        # Build via xcodebuild
```

> Codex-only note (for agent runs): execute `make format` / `make lint` outside the sandbox (with elevation) so cache writes succeed.

## After Making Changes

Always run formatting and linting:

```bash
make format && make lint
```

Or just `make check` to verify without modifying files.

Xcode also runs SwiftFormat and SwiftLint automatically on build.
