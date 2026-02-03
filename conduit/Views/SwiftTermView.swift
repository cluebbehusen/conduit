//
//  SwiftTermView.swift
//  conduit
//

import SwiftTerm
import SwiftUI

// MARK: - Terminal Theme

struct TerminalTheme {
    let background: UIColor
    let foreground: UIColor
    let cursor: UIColor

    static func current(for style: UIUserInterfaceStyle) -> TerminalTheme {
        switch style {
        case .dark, .unspecified:
            return TerminalTheme(
                background: .black,
                foreground: UIColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0),
                cursor: UIColor(red: 0.55, green: 0.65, blue: 0.85, alpha: 1.0)
            )
        case .light:
            return TerminalTheme(
                background: .white,
                foreground: UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1.0),
                cursor: UIColor(red: 0.30, green: 0.40, blue: 0.70, alpha: 1.0)
            )
        @unknown default:
            return current(for: .dark)
        }
    }
}

// MARK: - SwiftTermView

struct SwiftTermView: UIViewRepresentable {
    let sshService: SSHService
    @Binding var ctrlActive: Bool

    func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView()
        terminalView.terminalDelegate = context.coordinator

        // Critical rendering configuration - match SwiftTerm sample app
        terminalView.isOpaque = true
        terminalView.contentInsetAdjustmentBehavior = .never

        // Use Menlo for better glyph coverage (icons, box drawing, etc.)
        // Fall back to system monospace if Menlo unavailable
        let font: UIFont
        if let menlo = UIFont(name: "Menlo-Regular", size: 14) {
            font = menlo
        } else {
            font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        }
        terminalView.font = font

        // Apply theme colors before first render
        let theme = TerminalTheme.current(for: terminalView.traitCollection.userInterfaceStyle)
        terminalView.nativeBackgroundColor = theme.background
        terminalView.nativeForegroundColor = theme.foreground
        terminalView.caretColor = theme.cursor

        // Match keyboard appearance to terminal theme
        terminalView.keyboardAppearance = terminalView.traitCollection.userInterfaceStyle == .dark ? .dark : .light

        // Hide the default keyboard accessory bar (we use our own SwiftUI FAB overlay)
        // Use nil instead of empty UIView to avoid layout issues
        terminalView.inputAccessoryView = nil

        // Store reference for feeding data
        context.coordinator.terminalView = terminalView

        // Set up output handler
        Task { @MainActor in
            sshService.onOutput = { @Sendable data in
                Task { @MainActor in
                    context.coordinator.feed(data)
                }
            }
        }

        // Register for trait changes to update theme
        terminalView.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (tv: TerminalView, _) in
            let newTheme = TerminalTheme.current(for: tv.traitCollection.userInterfaceStyle)
            tv.nativeBackgroundColor = newTheme.background
            tv.nativeForegroundColor = newTheme.foreground
            tv.caretColor = newTheme.cursor
            tv.keyboardAppearance = tv.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        }

        return terminalView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sshService: sshService, ctrlActive: $ctrlActive)
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        context.coordinator.ctrlActive = $ctrlActive
    }

    @MainActor
    class Coordinator: NSObject, TerminalViewDelegate {
        let sshService: SSHService
        weak var terminalView: TerminalView?
        var ctrlActive: Binding<Bool>

        init(sshService: SSHService, ctrlActive: Binding<Bool>) {
            self.sshService = sshService
            self.ctrlActive = ctrlActive
        }

        func feed(_ data: Data) {
            let bytes = Array(data)
            terminalView?.feed(byteArray: bytes[...])
        }

        // MARK: - TerminalViewDelegate

        nonisolated func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let bytes = Array(data)
            Task { @MainActor in
                let dataToSend: Data
                if ctrlActive.wrappedValue, bytes.count == 1 {
                    // Reset Ctrl after any single-key press
                    ctrlActive.wrappedValue = false
                    if let transformed = applyCtrlModifier(bytes[0]) {
                        dataToSend = Data([transformed])
                    } else {
                        dataToSend = Data(bytes)
                    }
                } else {
                    dataToSend = Data(bytes)
                }
                sshService.send(dataToSend)
            }
        }

        /// Transforms a character byte to its corresponding control character.
        /// Returns nil if the byte doesn't have a standard Ctrl mapping.
        private func applyCtrlModifier(_ byte: UInt8) -> UInt8? {
            // A-Z (0x41-0x5A) -> Ctrl+A (0x01) through Ctrl+Z (0x1A)
            if byte >= 0x41, byte <= 0x5A {
                return byte - 0x40
            }
            // a-z (0x61-0x7A) -> same transformation as uppercase
            if byte >= 0x61, byte <= 0x7A {
                return byte - 0x60
            }
            // Special characters: @[\]^_ and alternates 2, 6
            // @=0x40->NUL, [=0x5B->ESC, \=0x5C->FS, ]=0x5D->GS, ^=0x5E->RS, _=0x5F->US
            // 2=0x32->NUL (alt Ctrl+@), 6=0x36->RS (alt Ctrl+^)
            let specialMappings: [UInt8: UInt8] = [
                0x40: 0x00, 0x5B: 0x1B, 0x5C: 0x1C, 0x5D: 0x1D,
                0x5E: 0x1E, 0x5F: 0x1F, 0x32: 0x00, 0x36: 0x1E
            ]
            return specialMappings[byte]
        }

        nonisolated func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            Task { @MainActor in
                sshService.resize(cols: newCols, rows: newRows)
            }
        }

        nonisolated func setTerminalTitle(source: TerminalView, title: String) {
            // Could update navigation title if needed
        }

        nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // Not used
        }

        nonisolated func scrolled(source: TerminalView, position: Double) {
            // Not used
        }

        nonisolated func clipboardCopy(source: TerminalView, content: Data) {
            if let string = String(data: content, encoding: .utf8) {
                Task { @MainActor in
                    UIPasteboard.general.string = string
                }
            }
        }

        nonisolated func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            if let url = URL(string: link) {
                Task { @MainActor in
                    await UIApplication.shared.open(url)
                }
            }
        }

        nonisolated func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
            // Not used
        }
    }
}
