//
//  KeyImportView.swift
//  conduit
//

import SwiftUI
import UniformTypeIdentifiers

struct KeyImportView: View {
    @Environment(\.dismiss) private var dismiss

    let keyStore: SSHKeyStore

    @State private var importMethod: ImportMethod = .file
    @State private var keyName: String = ""
    @State private var pastedKeyContent: String = ""
    @State private var loadedKeyContent: String = ""
    @State private var showFileImporter = false
    @State private var needsPassphrase = false
    @State private var passphrase: String = ""
    @State private var parsedKey: SSHKeyService.ParsedKey?
    @State private var detectedKeyType: SSHKey.KeyType?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false

    enum ImportMethod: String, CaseIterable {
        case file = "From File"
        case paste = "Paste Key"
    }

    private var isValid: Bool {
        !keyName.isEmpty && parsedKey != nil
    }

    private var currentKeyContent: String {
        importMethod == .file ? loadedKeyContent : pastedKeyContent
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Import Method") {
                    Picker("Method", selection: $importMethod) {
                        ForEach(ImportMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if importMethod == .file {
                    Section("Key File") {
                        Button {
                            showFileImporter = true
                        } label: {
                            HStack {
                                Image(systemName: parsedKey != nil ? "checkmark.circle.fill" : "doc.badge.plus")
                                    .foregroundStyle(parsedKey != nil ? .green : .accentColor)
                                Text(parsedKey != nil ? "Key loaded" : "Select private key file")
                                Spacer()
                            }
                        }

                        if let keyType = detectedKeyType {
                            LabeledContent("Type", value: keyType.displayName)
                        }
                    }
                } else {
                    Section("Paste Private Key") {
                        TextEditor(text: $pastedKeyContent)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 120)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        if !pastedKeyContent.isEmpty, parsedKey == nil {
                            Button("Parse Key") {
                                processKeyContent(pastedKeyContent)
                            }
                        }

                        if let keyType = detectedKeyType {
                            LabeledContent("Detected Type", value: keyType.displayName)
                        }
                    }
                }

                if needsPassphrase {
                    Section("Passphrase") {
                        SecureField("Key passphrase", text: $passphrase)
                            .textContentType(.none)

                        Button("Unlock Key") {
                            processKeyWithPassphrase()
                        }
                        .disabled(passphrase.isEmpty)
                    }
                }

                Section("Key Details") {
                    TextField("Name", text: $keyName)
                        .textContentType(.name)

                    if let parsed = parsedKey {
                        LabeledContent("Type", value: parsed.keyType.displayName)
                        LabeledContent("Fingerprint") {
                            Text(String(parsed.fingerprint.prefix(32)) + "...")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Import SSH Key")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(.regularMaterial)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importKey() }
                        .disabled(!isValid || isProcessing)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.text, .data, .item],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isProcessing {
                    ProgressView("Processing...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .onChange(of: importMethod) { _, _ in
                // Reset state when switching methods
                parsedKey = nil
                detectedKeyType = nil
                needsPassphrase = false
                passphrase = ""
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access the selected file."
                showError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                loadedKeyContent = content
                if keyName.isEmpty {
                    keyName = url.deletingPathExtension().lastPathComponent
                }
                processKeyContent(content)
            } catch {
                errorMessage = "Failed to read key file: \(error.localizedDescription)"
                showError = true
            }

        case let .failure(error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func processKeyContent(_ content: String) {
        // Reset state
        parsedKey = nil
        needsPassphrase = false

        // Detect key type
        do {
            detectedKeyType = try SSHKeyService.shared.detectKeyType(from: content)
        } catch {
            // Continue anyway, parsing might still work
        }

        // Check if passphrase is needed
        if SSHKeyService.shared.keyRequiresPassphrase(content) {
            needsPassphrase = true
            return
        }

        // Try to parse
        do {
            parsedKey = try SSHKeyService.shared.parsePrivateKey(from: content, passphrase: nil)
            detectedKeyType = parsedKey?.keyType
        } catch SSHKeyService.KeyServiceError.passphraseRequired {
            needsPassphrase = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func processKeyWithPassphrase() {
        let content = currentKeyContent
        do {
            parsedKey = try SSHKeyService.shared.parsePrivateKey(from: content, passphrase: passphrase)
            detectedKeyType = parsedKey?.keyType
            needsPassphrase = false
        } catch {
            errorMessage = "Failed to decrypt key: \(error.localizedDescription)"
            showError = true
        }
    }

    private func importKey() {
        guard let parsed = parsedKey else { return }

        isProcessing = true

        Task {
            do {
                let sshKey = SSHKey(
                    name: keyName,
                    keyType: parsed.keyType,
                    fingerprint: parsed.fingerprint,
                    publicKeyData: parsed.publicKeyData,
                    requiresPassphrase: SSHKeyService.shared.keyRequiresPassphrase(currentKeyContent),
                    createdAt: Date()
                )

                // Save private key content to Keychain
                try SSHKeyService.shared.savePrivateKey(currentKeyContent, for: sshKey.id)

                // Add to store
                await MainActor.run {
                    keyStore.add(sshKey)
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    KeyImportView(keyStore: SSHKeyStore())
}
