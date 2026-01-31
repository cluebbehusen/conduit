//
//  SwiftTermView.swift
//  conduit
//

import SwiftTerm
import SwiftUI

struct SwiftTermView: UIViewRepresentable {
    let sshService: SSHService

    func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView()
        terminalView.terminalDelegate = context.coordinator
        terminalView.backgroundColor = .black
        terminalView.nativeForegroundColor = .init(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        terminalView.nativeBackgroundColor = .black

        // Configure terminal appearance
        let font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        terminalView.font = font

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

        return terminalView
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        // Nothing to update dynamically
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sshService: sshService)
    }

    @MainActor
    class Coordinator: NSObject, TerminalViewDelegate {
        let sshService: SSHService
        weak var terminalView: TerminalView?

        init(sshService: SSHService) {
            self.sshService = sshService
        }

        func feed(_ data: Data) {
            let bytes = Array(data)
            terminalView?.feed(byteArray: bytes[...])
        }

        // MARK: - TerminalViewDelegate

        nonisolated func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let dataToSend = Data(data)
            Task { @MainActor in
                sshService.send(dataToSend)
            }
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
