//
//  TerminalContainerView.swift
//  conduit
//

import SwiftUI

struct TerminalContainerView: View {
    let host: Host
    @Binding var showAddHost: Bool

    @Environment(HostStore.self) private var hostStore
    @Environment(Settings.self) private var settings

    @State private var sshService = SSHService()
    @State private var showPasswordPrompt = false
    @State private var password = ""
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

            case let .disconnected(.error(message)):
                errorView(message: message)

            case .connecting:
                connectingView

            case .connected:
                SwiftTermView(sshService: sshService, ctrlActive: $ctrlActive)
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
                StatusIcon(systemName: "checkmark.circle.fill", color: .green)

                VStack(spacing: 8) {
                    Text("Session Ended")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("The connection was closed normally.")
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

// MARK: - Status Card

private struct StatusCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(28)
            .frame(maxWidth: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Status Icon

private struct StatusIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 44))
            .foregroundStyle(color)
    }
}

#Preview {
    NavigationStack {
        TerminalContainerView(host: .example, showAddHost: .constant(false))
    }
    .environment(HostStore())
    .environment(Settings())
}
