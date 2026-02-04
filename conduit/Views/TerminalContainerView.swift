//
//  TerminalContainerView.swift
//  conduit
//

// swiftlint:disable file_length

import SwiftUI

// swiftlint:disable:next type_body_length
struct TerminalContainerView: View {
    let host: Host
    @Binding var showAddHost: Bool

    @Environment(HostStore.self) private var hostStore
    @Environment(SSHKeyStore.self) private var keyStore
    @Environment(Settings.self) private var settings

    @State private var sshService = SSHService()
    @State private var showPasswordPrompt = false
    @State private var password = ""
    @State private var showKeyPassphrasePrompt = false
    @State private var keyPassphrase = ""
    @State private var attemptedAutoConnect = false
    @State private var keychainErrorMessage: String?
    @State private var showKeychainError = false
    @State private var ctrlActive = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
                .backgroundExtensionEffect()

            switch sshService.state {
            case .disconnected(nil), .disconnected(.userInitiated):
                disconnectedView

            case .disconnected(.sessionEnded):
                sessionEndedView

            case .disconnected(.hostKeyRejected):
                hostKeyRejectedView

            case let .disconnected(.error(message)):
                errorView(message: message)

            case .connecting:
                connectingView

            case .verifyingHostKey:
                hostKeyVerificationView

            case .connected:
                SwiftTermView(sshService: sshService, ctrlActive: $ctrlActive)
                    .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .background(Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white }))
                    .ignoresSafeArea(.keyboard)
                    .overlay(alignment: .bottomTrailing) {
                        TerminalAccessoryFAB(
                            sshService: sshService,
                            mode: settings.accessoryBarMode,
                            ctrlActive: $ctrlActive,
                            onKeyTap: {}
                        )
                    }
            }
        }
        .navigationTitle(host.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if sshService.state == .connected {
                ToolbarItem {
                    Button {
                        sshService.disconnect()
                    } label: {
                        Image(systemName: "network.slash")
                    }
                }
                ToolbarSpacer(.fixed)
            }

            ToolbarItem {
                Button {
                    showAddHost = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Enter Password", isPresented: $showPasswordPrompt) {
            // Use .oneTimeCode to prevent iOS offering to save to Apple Passwords
            SecureField("Password", text: $password)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Connect") {
                connectWithPassword()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter password for \(host.username)@\(host.hostname)")
        }
        .alert("Enter Key Passphrase", isPresented: $showKeyPassphrasePrompt) {
            // Use .oneTimeCode to prevent iOS from offering to save to Apple Passwords
            SecureField("Passphrase", text: $keyPassphrase)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Connect") {
                Task {
                    await connectWithKeyPassphrase()
                }
            }
            Button("Cancel", role: .cancel) {
                keyPassphrase = ""
            }
        } message: {
            Text("Enter passphrase for your SSH key")
        }
        .alert("Security Error", isPresented: $showKeychainError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(keychainErrorMessage ?? "Unknown error")
        }
        .onDisappear {
            if sshService.state == .connected {
                hostStore.markDisconnected(host)
            }
            sshService.disconnect()
        }
        .task {
            await attemptAutoConnectIfPossible()
        }
        .onChange(of: sshService.state) { oldState, newState in
            if newState == .connected {
                hostStore.recordConnection(for: host)
                hostStore.markConnected(host)
            } else if oldState == .connected {
                hostStore.markDisconnected(host)
            }
        }
    }

    private var disconnectedView: some View {
        StatusCard {
            VStack(spacing: 20) {
                StatusIcon(systemName: "terminal", color: .secondary)

                VStack(spacing: 8) {
                    Text("Ready to Connect")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(host.username + "@" + host.hostname)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await connectTapped()
                    }
                } label: {
                    Text("Connect")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var sessionEndedView: some View {
        StatusCard {
            VStack(spacing: 20) {
                StatusIcon(systemName: "terminal", color: .secondary)

                VStack(spacing: 8) {
                    Text("Session Ended")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(host.username + "@" + host.hostname)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await connectTapped()
                    }
                } label: {
                    Text("Reconnect")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var connectingView: some View {
        StatusCard {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.accentColor)

                VStack(spacing: 8) {
                    Text("Connecting...")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(host.hostname)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var hostKeyVerificationView: some View {
        if let pendingKey = sshService.pendingHostKey {
            if pendingKey.isKeyChange {
                HostKeyChangedView(
                    pendingKey: pendingKey,
                    onTrustNewKey: {
                        sshService.approveHostKey()
                    },
                    onCancel: {
                        sshService.rejectHostKey()
                    }
                )
            } else {
                HostKeyVerificationView(
                    pendingKey: pendingKey,
                    onTrust: {
                        sshService.approveHostKey()
                    },
                    onCancel: {
                        sshService.rejectHostKey()
                    }
                )
            }
        } else {
            connectingView
        }
    }

    private var hostKeyRejectedView: some View {
        StatusCard {
            VStack(spacing: 20) {
                StatusIcon(systemName: "xmark.shield.fill", color: .orange)

                VStack(spacing: 8) {
                    Text("Connection Canceled")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Host key verification was declined.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await connectTapped()
                    }
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func errorView(message: String) -> some View {
        StatusCard {
            VStack(spacing: 20) {
                StatusIcon(systemName: "exclamationmark.triangle.fill", color: .red)

                VStack(spacing: 8) {
                    Text("Connection Failed")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await connectTapped()
                    }
                } label: {
                    Text("Retry")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func connectWithPassword() {
        guard !password.isEmpty else { return }
        sshService.connect(host: host, password: password)
        password = ""
        showPasswordPrompt = false
    }

    @MainActor
    private func attemptAutoConnectIfPossible() async {
        guard !attemptedAutoConnect else { return }
        attemptedAutoConnect = true
        guard host.hasStoredCredential else { return }

        switch host.authMethod {
        case .password:
            await connectWithStoredPassword()
        case .key:
            await connectWithKey()
        }
    }

    private func connectTapped() async {
        switch host.authMethod {
        case .password:
            if host.hasStoredCredential {
                await connectWithStoredPassword()
            } else {
                await MainActor.run {
                    showPasswordPrompt = true
                }
            }
        case .key:
            await connectWithKey()
        }
    }

    private func connectWithStoredPassword() async {
        let prompt = "Authenticate to connect to \(host.name)"

        do {
            let retrievedPassword = try await KeychainService.shared.retrievePassword(
                for: host.id,
                prompt: prompt,
                reuseInterval: settings.autoLockTimeout
            )

            await MainActor.run {
                settings.recordUnlock()
                sshService.connect(host: host, password: retrievedPassword)
            }
        } catch let error as KeychainService.KeychainError {
            handleKeychainError(error)
        } catch {
            await MainActor.run {
                keychainErrorMessage = error.localizedDescription
                showKeychainError = true
            }
        }
    }

    private func connectWithKey() async {
        guard let keyID = host.keyID,
              let sshKey = keyStore.key(for: keyID)
        else {
            await MainActor.run {
                keychainErrorMessage = "No SSH key configured for this host."
                showKeychainError = true
            }
            return
        }

        let prompt = "Authenticate to use SSH key \"\(sshKey.name)\""

        do {
            let keyContent = try await SSHKeyService.shared.retrievePrivateKey(
                for: keyID,
                prompt: prompt,
                reuseInterval: settings.autoLockTimeout
            )

            // Check if key requires passphrase
            if sshKey.requiresPassphrase {
                await MainActor.run {
                    showKeyPassphrasePrompt = true
                }
                return
            }

            // Build auth method and connect
            let authMethod = try SSHKeyService.shared.buildAuthMethod(
                keyContent: keyContent,
                keyType: sshKey.keyType,
                passphrase: nil,
                username: host.username
            )

            await MainActor.run {
                settings.recordUnlock()
                sshService.connect(host: host, authMethod: authMethod)
            }
        } catch let error as KeychainService.KeychainError {
            handleKeychainError(error)
        } catch {
            await MainActor.run {
                keychainErrorMessage = error.localizedDescription
                showKeychainError = true
            }
        }
    }

    private func connectWithKeyPassphrase() async {
        guard let keyID = host.keyID,
              let sshKey = keyStore.key(for: keyID)
        else {
            return
        }

        do {
            let keyContent = try await SSHKeyService.shared.retrievePrivateKey(
                for: keyID,
                prompt: "Authenticate to use SSH key",
                reuseInterval: settings.autoLockTimeout
            )

            let authMethod = try SSHKeyService.shared.buildAuthMethod(
                keyContent: keyContent,
                keyType: sshKey.keyType,
                passphrase: keyPassphrase,
                username: host.username
            )

            await MainActor.run {
                keyPassphrase = ""
                showKeyPassphrasePrompt = false
                settings.recordUnlock()
                sshService.connect(host: host, authMethod: authMethod)
            }
        } catch {
            await MainActor.run {
                keyPassphrase = ""
                keychainErrorMessage = "Failed to decrypt key: \(error.localizedDescription)"
                showKeychainError = true
            }
        }
    }

    private func handleKeychainError(_ error: KeychainService.KeychainError) {
        switch error {
        case .noStoredPassword, .userCanceled:
            if host.authMethod == .password {
                showPasswordPrompt = true
            }
        case let .biometryNotAvailable(message):
            keychainErrorMessage = message
            showKeychainError = true
            if host.authMethod == .password {
                showPasswordPrompt = true
            }
        default:
            keychainErrorMessage = error.errorDescription ?? error.localizedDescription
            showKeychainError = true
        }
    }
}

private struct StatusCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(28).frame(maxWidth: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct StatusIcon: View {
    let systemName: String
    let color: Color
    var body: some View {
        Image(systemName: systemName).font(.system(size: 44)).foregroundStyle(color)
    }
}

#Preview {
    NavigationStack {
        TerminalContainerView(host: .example, showAddHost: .constant(false))
    }
    .environment(HostStore())
    .environment(SSHKeyStore())
    .environment(Settings())
}
