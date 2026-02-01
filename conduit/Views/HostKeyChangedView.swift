//
//  HostKeyChangedView.swift
//  conduit
//

import SwiftUI

/// View shown when a host's key has changed (potential MITM attack warning)
struct HostKeyChangedView: View {
    let pendingKey: PendingHostKey
    let onTrustNewKey: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Warning icon
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)

            // Title and warning
            VStack(spacing: 8) {
                Text("Host Key Changed")
                    .font(.headline)
                    .foregroundStyle(.red)

                Text(
                    """
                    The server's identity has changed since you last connected. \
                    This could indicate a man-in-the-middle attack, or the server was reinstalled.
                    """
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            // Key comparison
            VStack(spacing: 16) {
                // Old key
                if let existingHost = pendingKey.existingHost {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            Text("Previous Fingerprint")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Text(existingHost.fingerprint)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // New key
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("New Fingerprint")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(pendingKey.fingerprint)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Action buttons
            VStack(spacing: 12) {
                Button(role: .destructive) {
                    onTrustNewKey()
                } label: {
                    Text("Trust New Key")
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

        HostKeyChangedView(
            pendingKey: PendingHostKey(
                hostname: "192.168.1.100",
                port: 22,
                keyType: "ssh-ed25519",
                fingerprint: "SHA256:ff:ee:dd:cc:bb:aa:99:88:77:66:55:44:33:22:11:00",
                existingHost: KnownHost(
                    hostname: "192.168.1.100",
                    port: 22,
                    keyType: "ssh-ed25519",
                    fingerprint: "SHA256:ab:cd:ef:12:34:56:78:90:ab:cd:ef:12:34:56:78:90"
                )
            ),
            onTrustNewKey: {},
            onCancel: {}
        )
    }
}
