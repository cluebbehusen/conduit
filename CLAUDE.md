# Conduit

An iOS SSH client with terminal emulation, built with SwiftUI, SwiftTerm, and Citadel.

## Architecture

```txt
SwiftUI Views → SwiftTermView (UIViewRepresentable) → SSHService (Citadel)
```

- **Models/**: `Host` (SSH host config), `HostStore` (persistence via UserDefaults)
- **Services/**: `SSHService` (Citadel SSH + PTY management)
- **Views/**: `HostListView`, `HostEditView`, `TerminalContainerView`, `SwiftTermView`

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

## After Making Changes

Always run formatting and linting:

```bash
make format && make lint
```

Or just `make check` to verify without modifying files.

Xcode also runs SwiftFormat and SwiftLint automatically on build.
