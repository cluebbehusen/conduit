//
//  SSHService.swift
//  conduit
//

import Citadel
import Foundation
import NIOCore
import NIOFoundationCompat
import NIOSSH

@MainActor
@Observable
final class SSHService {
    enum DisconnectReason: Equatable {
        case userInitiated // User clicked Disconnect
        case sessionEnded // Clean exit (user typed `exit`, remote closed normally)
        case error(String) // Actual error (auth failure, network drop, timeout)
    }

    enum ConnectionState: Equatable {
        case disconnected(DisconnectReason?) // nil = initial state
        case connecting
        case connected
    }

    private(set) var state: ConnectionState = .disconnected(nil)

    var onOutput: (@Sendable (Data) -> Void)?
    var onDisconnect: (@Sendable () -> Void)?

    private var client: SSHClient?
    private var stdinWriter: TTYStdinWriter?
    private var connectionTask: Task<Void, Never>?

    private var currentCols: Int = 80
    private var currentRows: Int = 24

    func connect(host: Host, password: String) {
        guard state != .connecting else { return }

        state = .connecting

        connectionTask = Task { [weak self] in
            await self?.performConnection(host: host, password: password)
        }
    }

    private func performConnection(host: Host, password: String) async {
        do {
            let sshClient = try await SSHClient.connect(
                host: host.hostname,
                port: host.port,
                authenticationMethod: .passwordBased(username: host.username, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )

            self.client = sshClient

            let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
                wantReply: true,
                term: "xterm-256color",
                terminalCharacterWidth: currentCols,
                terminalRowHeight: currentRows,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0,
                terminalModes: .init([:])
            )

            try await sshClient.withPTY(ptyRequest) { inbound, writer in
                await MainActor.run {
                    self.stdinWriter = writer
                    self.state = .connected
                }

                do {
                    for try await event in inbound {
                        switch event {
                        case let .stdout(buffer):
                            let data = Data(buffer: buffer)
                            if let onOutput = await MainActor.run(body: { self.onOutput }) {
                                onOutput(data)
                            }
                        case let .stderr(buffer):
                            let data = Data(buffer: buffer)
                            if let onOutput = await MainActor.run(body: { self.onOutput }) {
                                onOutput(data)
                            }
                        }
                    }
                } catch {
                    // ChannelError indicates the channel closed - typically a clean exit
                    let reason: DisconnectReason = if error is ChannelError {
                        .sessionEnded
                    } else {
                        .error("Stream error: \(error.localizedDescription)")
                    }
                    await MainActor.run {
                        self.handleDisconnection(reason: reason)
                    }
                    return
                }

                await MainActor.run {
                    self.handleDisconnection(reason: .sessionEnded)
                }
            }
        } catch {
            // ChannelError from withPTY indicates the session ended cleanly
            let reason: DisconnectReason = if error is ChannelError {
                .sessionEnded
            } else {
                .error(error.localizedDescription)
            }
            await MainActor.run {
                self.handleDisconnection(reason: reason)
            }
        }
    }

    private func handleDisconnection(reason: DisconnectReason) {
        // Don't overwrite userInitiated with sessionEnded from the closing channel
        if case .disconnected(.userInitiated) = state {
            return
        }
        state = .disconnected(reason)
        client = nil
        stdinWriter = nil
        onDisconnect?()
    }

    func send(_ data: Data) {
        guard let writer = stdinWriter else { return }

        Task {
            do {
                var buffer = ByteBufferAllocator().buffer(capacity: data.count)
                buffer.writeBytes(data)
                try await writer.write(buffer)
            } catch {
                await MainActor.run {
                    self.state = .disconnected(.error("Send error: \(error.localizedDescription)"))
                }
            }
        }
    }

    func resize(cols: Int, rows: Int) {
        currentCols = cols
        currentRows = rows

        guard let writer = stdinWriter else { return }

        Task {
            do {
                try await writer.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0)
            } catch {
                // Resize errors are non-fatal
            }
        }
    }

    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil

        // Set state synchronously so it's not overwritten by stream handlers
        state = .disconnected(.userInitiated)
        let clientToClose = client
        client = nil
        stdinWriter = nil
        onDisconnect?()

        Task {
            try? await clientToClose?.close()
        }
    }
}
