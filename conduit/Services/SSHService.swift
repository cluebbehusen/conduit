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
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    private(set) var state: ConnectionState = .disconnected

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
                    await MainActor.run {
                        self.state = .error("Stream error: \(error.localizedDescription)")
                    }
                }

                await MainActor.run {
                    self.handleDisconnection()
                }
            }
        } catch {
            await MainActor.run {
                self.state = .error(error.localizedDescription)
                self.client = nil
                self.stdinWriter = nil
            }
        }
    }

    private func handleDisconnection() {
        state = .disconnected
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
                    self.state = .error("Send error: \(error.localizedDescription)")
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

        Task {
            try? await client?.close()
            await MainActor.run {
                self.handleDisconnection()
            }
        }
    }
}
