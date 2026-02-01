//
//  KeyDetailView.swift
//  conduit
//

import SwiftUI

struct KeyDetailView: View {
    let key: SSHKey
    let keyStore: SSHKeyStore

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var publicKeyCopied = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Key Information") {
                    LabeledContent("Name", value: key.name)
                    LabeledContent("Type", value: key.keyType.displayName)
                    LabeledContent("Created", value: key.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if key.requiresPassphrase {
                        LabeledContent("Protected") {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                Text("Passphrase required")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Fingerprint") {
                    Text(key.fingerprint)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Public Key")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(key.publicKeyString)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)

                    Button {
                        UIPasteboard.general.string = key.publicKeyString
                        publicKeyCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            publicKeyCopied = false
                        }
                    } label: {
                        Label(
                            publicKeyCopied ? "Copied!" : "Copy Public Key",
                            systemImage: publicKeyCopied ? "checkmark" : "doc.on.doc"
                        )
                    }
                } header: {
                    Text("For Server Setup")
                } footer: {
                    Text("Add this public key to ~/.ssh/authorized_keys on your server.")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Key", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Key Details")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(.regularMaterial)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Key?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    try? SSHKeyService.shared.deletePrivateKey(for: key.id)
                    keyStore.delete(key)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \"\(key.name)\" and remove it from the Keychain.")
            }
        }
    }
}

#Preview {
    KeyDetailView(key: SSHKey.example, keyStore: SSHKeyStore())
}
