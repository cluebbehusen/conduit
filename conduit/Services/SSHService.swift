//
//  SSHService.swift
//  conduit
//

import Citadel
import Foundation
import NIO
import NIOFoundationCompat
import NIOSSH

/// Error thrown when user rejects a host key
struct HostKeyRejected: Error {}

/// Custom host key validator that bridges Citadel's delegate API with our async UI flow
final class InteractiveHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let validationHandler: @Sendable (NIOSSHPublicKey, EventLoopPromise<Void>) -> Void

    init(validationHandler: @escaping @Sendable (NIOSSHPublicKey, EventLoopPromise<Void>) -> Void) {
        self.validationHandler = validationHandler
    }

    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationHandler(hostKey, validationCompletePromise)
    }
}

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

    /// Promise for host key verification - completed when user makes a decision
    private var hostKeyValidationPromise: EventLoopPromise<Void>?

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

        // Resume connection by succeeding the promise
        pendingHostKey = nil
        hostKeyValidationPromise?.succeed(())
        hostKeyValidationPromise = nil
    }

    /// Called by UI when user rejects the host key
    func rejectHostKey() {
        pendingHostKey = nil
        hostKeyValidationPromise?.fail(HostKeyRejected())
        hostKeyValidationPromise = nil
    }

    private func performConnection(host: Host, password: String) async {
        let hostname = host.hostname
        let port = host.port

        // Create validator that bridges to our async UI flow
        let validator = InteractiveHostKeyValidator { [weak self] hostKey, promise in
            guard let self else {
                promise.fail(HostKeyRejected())
                return
            }

            let keyType = self.extractKeyType(from: hostKey)
            let fingerprint = self.calculateFingerprint(from: hostKey)

            let pendingVerification = KnownHostsService.shared.verifyHostKey(
                hostname: hostname,
                port: port,
                keyType: keyType,
                fingerprint: fingerprint
            )

            if let pending = pendingVerification {
                // Need user verification - store promise to complete later
                Task { @MainActor in
                    self.pendingHostKey = pending
                    self.state = .verifyingHostKey
                    self.hostKeyValidationPromise = promise
                }
            } else {
                // Key is known and matches - allow connection
                promise.succeed(())
            }
        }

        do {
            let sshClient = try await SSHClient.connect(
                host: host.hostname,
                port: host.port,
                authenticationMethod: .passwordBased(username: host.username, password: password),
                hostKeyValidator: .custom(validator),
                reconnect: .never
            )

            self.client = sshClient
            try await runPTYSession(sshClient: sshClient)
        } catch {
            handleConnectionError(error)
        }
    }

    private func runPTYSession(sshClient: SSHClient) async throws {
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
                    await handleSSHOutput(event)
                }
            } catch {
                let reason: DisconnectReason = error is ChannelError
                    ? .sessionEnded
                    : .error("Stream error: \(error.localizedDescription)")
                await MainActor.run { self.handleDisconnection(reason: reason) }
                return
            }

            await MainActor.run { self.handleDisconnection(reason: .sessionEnded) }
        }
    }

    private func handleSSHOutput(_ event: ExecCommandOutput) async {
        let data = switch event {
        case let .stdout(buffer):
            Data(buffer: buffer)
        case let .stderr(buffer):
            Data(buffer: buffer)
        }
        if let onOutput = await MainActor.run(body: { self.onOutput }) {
            onOutput(data)
        }
    }

    private func handleConnectionError(_ error: Error) {
        // Check if this was a host key rejection
        if state == .verifyingHostKey || pendingHostKey != nil || error is HostKeyRejected {
            Task { @MainActor in
                self.handleDisconnection(reason: .hostKeyRejected)
            }
            return
        }

        let reason: DisconnectReason = error is ChannelError
            ? .sessionEnded
            : .error(error.localizedDescription)
        Task { @MainActor in
            self.handleDisconnection(reason: reason)
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
        hostKeyValidationPromise = nil
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
        if hostKeyValidationPromise != nil {
            hostKeyValidationPromise?.fail(HostKeyRejected())
            hostKeyValidationPromise = nil
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

    nonisolated private func extractKeyType(from hostKey: NIOSSHPublicKey) -> String {
        let description = String(describing: hostKey).lowercased()
        let keyTypes: [(pattern: String, type: String)] = [
            ("ed25519", "ssh-ed25519"),
            ("p256", "ecdsa-sha2-nistp256"),
            ("nistp256", "ecdsa-sha2-nistp256"),
            ("p384", "ecdsa-sha2-nistp384"),
            ("nistp384", "ecdsa-sha2-nistp384"),
            ("p521", "ecdsa-sha2-nistp521"),
            ("nistp521", "ecdsa-sha2-nistp521"),
            ("rsa", "ssh-rsa")
        ]
        return keyTypes.first { description.contains($0.pattern) }?.type ?? "unknown"
    }

    nonisolated private func calculateFingerprint(from hostKey: NIOSSHPublicKey) -> String {
        // Since NIOSSHPublicKey doesn't expose raw bytes publicly,
        // we use the string description to generate a stable fingerprint
        let description = String(describing: hostKey)
        let keyData = Data(description.utf8)
        return KnownHostsService.calculateFingerprint(from: keyData)
    }
}
