//
//  KeyGenerateView.swift
//  conduit
//

import SwiftUI

struct KeyGenerateView: View {
    @Environment(\.dismiss) private var dismiss

    let keyStore: SSHKeyStore

    @State private var keyName: String = ""
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var generatedResult: GeneratedResult?

    struct GeneratedResult {
        let sshKey: SSHKey
        let publicKeyString: String
    }

    private var isValid: Bool {
        !keyName.isEmpty
    }

    var body: some View {
        NavigationStack {
            if let result = generatedResult {
                successView(result: result)
            } else {
                formView
            }
        }
    }

    private var formView: some View {
        Form {
            Section("Key Details") {
                TextField("Name", text: $keyName)
                    .textContentType(.name)

                LabeledContent("Type") {
                    Text("Ed25519")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Ed25519 keys are compact, fast, and secure. This is the recommended key type for most use cases.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Generate SSH Key")
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
                Button("Generate") { generateKey() }
                    .disabled(!isValid || isGenerating)
            }
        }
        .overlay {
            if isGenerating {
                ProgressView("Generating...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Generation Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func successView(result: GeneratedResult) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Key Generated")
                    .font(.title2.bold())

                Text("\"\(result.sshKey.name)\" has been created and saved.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Public Key")
                    .font(.headline)

                Text("Add this to your server's ~/.ssh/authorized_keys file:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(result.publicKeyString)
                    .font(.caption.monospaced())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)

                CopyButton(text: result.publicKeyString)
            }
            .padding()

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .navigationTitle("Key Generated")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func generateKey() {
        isGenerating = true

        // Generate synchronously (Ed25519 is fast)
        let generated = SSHKeyService.shared.generateEd25519Key()

        let sshKey = SSHKey(
            name: keyName,
            keyType: .ed25519,
            fingerprint: generated.fingerprint,
            publicKeyData: generated.publicKeyData,
            requiresPassphrase: false,
            createdAt: Date()
        )

        do {
            // Save private key to Keychain
            try SSHKeyService.shared.savePrivateKey(generated.privateKeyPEM, for: sshKey.id)

            // Add to store
            keyStore.add(sshKey)

            generatedResult = GeneratedResult(
                sshKey: sshKey,
                publicKeyString: generated.publicKeyString
            )
            isGenerating = false
        } catch {
            isGenerating = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

private struct CopyButton: View {
    let text: String

    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        } label: {
            Label(
                copied ? "Copied!" : "Copy Public Key",
                systemImage: copied ? "checkmark" : "doc.on.doc"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}

#Preview {
    KeyGenerateView(keyStore: SSHKeyStore())
}
