//
//  TerminalContainerView.swift
//  conduit
//

import SwiftUI

struct TerminalContainerView: View {
    let host: Host

    @State private var sshService = SSHService()
    @State private var showPasswordPrompt = true
    @State private var password = ""
    @State private var isConnecting = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch sshService.state {
            case .disconnected:
                disconnectedView

            case .connecting:
                connectingView

            case .connected:
                SwiftTermView(sshService: sshService)
                    .ignoresSafeArea(.keyboard)

            case let .error(message):
                errorView(message: message)
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
            Button("Connect") {
                connect()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter password for \(host.username)@\(host.hostname)")
        }
        .onDisappear {
            sshService.disconnect()
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
                showPasswordPrompt = true
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
                showPasswordPrompt = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func connect() {
        guard !password.isEmpty else { return }
        sshService.connect(host: host, password: password)
        password = ""
    }
}

#Preview {
    NavigationStack {
        TerminalContainerView(host: .example)
    }
}
