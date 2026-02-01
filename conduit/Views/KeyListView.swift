//
//  KeyListView.swift
//  conduit
//

import SwiftUI

struct KeyListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SSHKeyStore.self) private var keyStore
    @Environment(Settings.self) private var settings

    @State private var showImportSheet = false
    @State private var showGenerateSheet = false
    @State private var selectedKey: SSHKey?
    @State private var keyToDelete: SSHKey?

    var body: some View {
        NavigationStack {
            Group {
                if keyStore.keys.isEmpty {
                    ContentUnavailableView {
                        Label("No SSH Keys", systemImage: "key")
                    } description: {
                        Text("Import or generate SSH keys to use for authentication.")
                    } actions: {
                        HStack(spacing: 12) {
                            Button("Import Key") {
                                showImportSheet = true
                            }
                            .buttonStyle(.bordered)

                            Button("Generate Key") {
                                showGenerateSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    List {
                        ForEach(keyStore.sortedKeys) { key in
                            Button {
                                selectedKey = key
                            } label: {
                                KeyRow(key: key)
                            }
                            .contextMenu {
                                Button {
                                    copyPublicKey(key)
                                } label: {
                                    Label("Copy Public Key", systemImage: "doc.on.doc")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    keyToDelete = key
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    keyToDelete = key
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("SSH Keys")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(.regularMaterial)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                if !keyStore.keys.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showImportSheet = true
                            } label: {
                                Label("Import Key", systemImage: "square.and.arrow.down")
                            }

                            Button {
                                showGenerateSheet = true
                            } label: {
                                Label("Generate Key", systemImage: "plus.circle")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                KeyImportView(keyStore: keyStore)
                    .preferredColorScheme(settings.appTheme.colorScheme)
            }
            .sheet(isPresented: $showGenerateSheet) {
                KeyGenerateView(keyStore: keyStore)
                    .preferredColorScheme(settings.appTheme.colorScheme)
            }
            .sheet(item: $selectedKey) { key in
                KeyDetailView(key: key, keyStore: keyStore)
                    .preferredColorScheme(settings.appTheme.colorScheme)
            }
            .alert("Delete Key?", isPresented: .init(
                get: { keyToDelete != nil },
                set: { if !$0 { keyToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let key = keyToDelete {
                        deleteKey(key)
                    }
                }
                Button("Cancel", role: .cancel) {
                    keyToDelete = nil
                }
            } message: {
                if let key = keyToDelete {
                    Text("This will permanently delete \"\(key.name)\" and remove it from the Keychain.")
                }
            }
        }
    }

    private func copyPublicKey(_ key: SSHKey) {
        UIPasteboard.general.string = key.publicKeyString
    }

    private func deleteKey(_ key: SSHKey) {
        try? SSHKeyService.shared.deletePrivateKey(for: key.id)
        keyStore.delete(key)
        keyToDelete = nil
    }
}

struct KeyRow: View {
    let key: SSHKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(key.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(key.keyType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.quaternary)

                    Text(key.shortFingerprint)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            if key.requiresPassphrase {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    KeyListView()
        .environment(SSHKeyStore())
        .environment(Settings())
}
