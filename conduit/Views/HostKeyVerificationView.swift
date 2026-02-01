//
//  HostKeyVerificationView.swift
//  conduit
//

import SwiftUI

/// View shown when connecting to a host for the first time (Trust On First Use)
struct HostKeyVerificationView: View {
    let pendingKey: PendingHostKey
    let onTrust: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "key.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            // Title and description
            VStack(spacing: 8) {
                Text("Verify Host")
                    .font(.headline)

                Text("First connection to this server. Verify the fingerprint matches what you expect.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Fingerprint details
            VStack(spacing: 12) {
                HStack {
                    Text("Host")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(pendingKey.hostname):\(pendingKey.port)")
                        .fontDesign(.monospaced)
                }
                .font(.footnote)

                HStack {
                    Text("Key Type")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(pendingKey.keyType)
                        .fontDesign(.monospaced)
                }
                .font(.footnote)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Fingerprint (SHA256)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(pendingKey.fingerprint)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.vertical, 8)

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    onTrust()
                } label: {
                    Text("Trust")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(role: .cancel) {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        HostKeyVerificationView(
            pendingKey: PendingHostKey(
                hostname: "192.168.1.100",
                port: 22,
                keyType: "ssh-ed25519",
                fingerprint: "SHA256:ab:cd:ef:12:34:56:78:90:ab:cd:ef:12:34:56:78:90",
                existingHost: nil
            ),
            onTrust: {},
            onCancel: {}
        )
    }
}
