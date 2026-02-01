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
        case hostKeyRejected // User rejected host key verification
    }

    enum ConnectionState: Equatable {
        case disconnected(DisconnectReason?) // nil = initial state
        case connecting
        case verifyingHostKey // Waiting for user to verify host key
        case connected
    }

    private(set) var state: ConnectionState = .disconnected(nil)

    /// Pending host key that needs user verification
    private(set) var pendingHostKey: PendingHostKey?

    var onOutput: (@Sendable (Data) -> Void)?
    var onDisconnect: (@Sendable () -> Void)?

    private var client: SSHClient?
    private var stdinWriter: TTYStdinWriter?
    private var connectionTask: Task<Void, Never>?

    private var currentCols: Int = 80
    private var currentRows: Int = 24

    /// Continuation for host key verification - resumed when user makes a decision
    private var hostKeyVerificationContinuation: CheckedContinuation<Bool, Never>?

    /// Host info needed for verification callback
    private var pendingHostname: String?
    private var pendingPort: Int?

    func connect(host: Host, password: String) {
        guard state != .connecting, state != .verifyingHostKey else { return }

        state = .connecting
        pendingHostKey = nil
        pendingHostname = host.hostname
        pendingPort = host.port

        connectionTask = Task { [weak self] in
            await self?.performConnection(host: host, password: password)
        }
    }

    /// Called by UI when user approves the host key
    func approveHostKey() {
        guard let pending = pendingHostKey else { return }

        // Save to known hosts
        KnownHostsService.shared.trustHostKey(
            hostname: pending.hostname,
            port: pending.port,
            keyType: pending.keyType,
            fingerprint: pending.fingerprint
        )

        // Resume connection
        pendingHostKey = nil
        hostKeyVerificationContinuation?.resume(returning: true)
        hostKeyVerificationContinuation = nil
    }

    /// Called by UI when user rejects the host key
    func rejectHostKey() {
        pendingHostKey = nil
        hostKeyVerificationContinuation?.resume(returning: false)
        hostKeyVerificationContinuation = nil
    }

    // swiftlint:disable:next function_body_length
    private func performConnection(host: Host, password: String) async {
        // Create a validation handler that uses KnownHostsService
        let hostname = host.hostname
        let port = host.port

        // We need to capture self weakly for the closure
        let validator = NIOSSHClientConfiguration.HostKeyValidator.custom { [weak self] hostKey in
            guard let self else { return false }

            // Extract key type and calculate fingerprint
            let keyType = self.extractKeyType(from: hostKey)
            let fingerprint = self.calculateFingerprint(from: hostKey)

            // Check against known hosts
            let pendingVerification = KnownHostsService.shared.verifyHostKey(
                hostname: hostname,
                port: port,
                keyType: keyType,
                fingerprint: fingerprint
            )

            if let pending = pendingVerification {
                // Need user verification - use continuation to pause
                return await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        self.pendingHostKey = pending
                        self.state = .verifyingHostKey
                        self.hostKeyVerificationContinuation = continuation
                    }
                }
            }

            // Key is known and matches - allow connection
            return true
        }

        do {
            let sshClient = try await SSHClient.connect(
                host: host.hostname,
                port: host.port,
                authenticationMethod: .passwordBased(username: host.username, password: password),
                hostKeyValidator: validator,
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
            // Check if this was a host key rejection
            if state == .verifyingHostKey || pendingHostKey != nil {
                await MainActor.run {
                    self.handleDisconnection(reason: .hostKeyRejected)
                }
                return
            }

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
        pendingHostKey = nil
        hostKeyVerificationContinuation = nil
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

        // Cancel any pending host key verification
        if hostKeyVerificationContinuation != nil {
            hostKeyVerificationContinuation?.resume(returning: false)
            hostKeyVerificationContinuation = nil
        }
        pendingHostKey = nil

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

    // MARK: - Host Key Utilities

    private func extractKeyType(from hostKey: NIOSSHPublicKey) -> String {
        // Extract key type from the key's string description
        let description = String(describing: hostKey)

        // The description typically contains the key type
        if description.contains("ed25519") || description.contains("Ed25519") {
            return "ssh-ed25519"
        } else if description.contains("P256") || description.contains("nistp256") {
            return "ecdsa-sha2-nistp256"
        } else if description.contains("P384") || description.contains("nistp384") {
            return "ecdsa-sha2-nistp384"
        } else if description.contains("P521") || description.contains("nistp521") {
            return "ecdsa-sha2-nistp521"
        } else if description.contains("RSA") || description.contains("rsa") {
            return "ssh-rsa"
        }
        return "unknown"
    }

    private func calculateFingerprint(from hostKey: NIOSSHPublicKey) -> String {
        // Since NIOSSHPublicKey doesn't expose raw bytes publicly,
        // we use the string description to generate a stable fingerprint
        let description = String(describing: hostKey)
        let keyData = Data(description.utf8)
        return KnownHostsService.calculateFingerprint(from: keyData)
    }
}
