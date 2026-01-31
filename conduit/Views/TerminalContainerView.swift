//
//  TerminalContainerView.swift
//  conduit
//

import SwiftUI

struct TerminalContainerView: View {
    let host: Host

    @Environment(SecuritySettings.self) private var securitySettings

    @State private var sshService = SSHService()
    @State private var showPasswordPrompt = false
    @State private var password = ""
    @State private var attemptedAutoConnect = false
    @State private var keychainErrorMessage: String?
    @State private var showKeychainError = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch sshService.state {
            case .disconnected(nil), .disconnected(.userInitiated):
                disconnectedView

            case .disconnected(.sessionEnded):
                sessionEndedView

            case let .disconnected(.error(message)):
                errorView(message: message)

            case .connecting:
                connectingView

            case .connected:
                SwiftTermView(sshService: sshService)
                    .ignoresSafeArea(.keyboard)
            }
        }
        .navigationTitle(host.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if sshService.state == .connected {
                    Button("Disconnect") {
                        sshService.disconnect()
                    }
                }
            }
        }
        .alert("Enter Password", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $password)
                .textContentType(.none)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Connect") {
                connect()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter password for \(host.username)@\(host.hostname)")
        }
        .alert("Security Error", isPresented: $showKeychainError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(keychainErrorMessage ?? "Unknown error")
        }
        .onDisappear {
            sshService.disconnect()
        }
        .task {
            await attemptAutoConnectIfPossible()
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Disconnected")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button("Connect") {
                Task {
                    await connectTapped()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var sessionEndedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Session Ended")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button("Reconnect") {
                Task {
                    await connectTapped()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Connecting to \(host.hostname)...")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Connection Error")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                Task {
                    await connectTapped()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func connect() {
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
        await connectWithStoredCredential()
    }

    private func connectTapped() async {
        if host.hasStoredCredential {
            await connectWithStoredCredential()
        } else {
            await MainActor.run {
                showPasswordPrompt = true
            }
        }
    }

    private func connectWithStoredCredential() async {
        let prompt = "Authenticate to connect to \(host.name)"

        do {
            let retrievedPassword = try await KeychainService.shared.retrievePassword(
                for: host.id,
                prompt: prompt,
                reuseInterval: securitySettings.autoLockTimeout
            )

            await MainActor.run {
                securitySettings.recordUnlock()
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

    private func handleKeychainError(_ error: KeychainService.KeychainError) {
        switch error {
        case .noStoredPassword, .userCanceled:
            showPasswordPrompt = true
        case let .biometryNotAvailable(message):
            keychainErrorMessage = message
            showKeychainError = true
            showPasswordPrompt = true
        default:
            keychainErrorMessage = error.errorDescription ?? error.localizedDescription
            showKeychainError = true
        }
    }
}

#Preview {
    NavigationStack {
        TerminalContainerView(host: .example)
    }
    .environment(SecuritySettings())
}
