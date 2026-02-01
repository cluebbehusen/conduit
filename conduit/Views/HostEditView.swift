//
//  HostEditView.swift
//  conduit
//

import SwiftUI

struct HostEditView: View {
    @Environment(\.dismiss) private var dismiss

    let hostStore: HostStore
    let existingHost: Host?

    @State private var name: String = ""
    @State private var hostname: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var savePassword: Bool = false
    @State private var showPasswordField: Bool = false
    @State private var showKeychainError = false
    @State private var keychainErrorMessage = ""

    init(hostStore: HostStore, existingHost: Host? = nil) {
        self.hostStore = hostStore
        self.existingHost = existingHost

        if let host = existingHost {
            _name = State(initialValue: host.name)
            _hostname = State(initialValue: host.hostname)
            _port = State(initialValue: String(host.port))
            _username = State(initialValue: host.username)
            _savePassword = State(initialValue: host.hasStoredCredential)
        }
    }

    private var isValid: Bool {
        let passwordRequired = savePassword && (!hasStoredCredential || showPasswordField)
        let passwordOK = !passwordRequired || !password.isEmpty
        return !name.isEmpty && !hostname.isEmpty && !username.isEmpty && Int(port) != nil && passwordOK
    }

    private var hasStoredCredential: Bool {
        existingHost?.hasStoredCredential ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField("Hostname", text: $hostname)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    LabeledContent("Port") {
                        TextField("22", text: $port)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Authentication") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Toggle("Save password in Keychain", isOn: $savePassword)
                        .toggleStyle(.switch)

                    if !savePassword {
                        Text("The password is stored securely and protected by biometrics.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if savePassword {
                        if hasStoredCredential, !showPasswordField {
                            HStack {
                                Text("Password")
                                Spacer()
                                Text("Saved")
                                    .foregroundStyle(.secondary)
                                Button("Update") {
                                    showPasswordField = true
                                }
                            }
                        }

                        if !hasStoredCredential || showPasswordField {
                            SecureField("Password", text: $password)
                                .textContentType(.none)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            if hasStoredCredential, showPasswordField {
                                Button("Cancel update") {
                                    password = ""
                                    showPasswordField = false
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingHost == nil ? "Add Host" : "Edit Host")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(.regularMaterial)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .onChange(of: savePassword) { _, newValue in
                if newValue {
                    if !hasStoredCredential {
                        showPasswordField = true
                    }
                } else {
                    password = ""
                    showPasswordField = false
                }
            }
            .alert("Keychain Error", isPresented: $showKeychainError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(keychainErrorMessage)
            }
        }
    }

    private func save() {
        let host = Host(
            id: existingHost?.id ?? UUID(),
            name: name,
            hostname: hostname,
            port: Int(port) ?? 22,
            username: username,
            authMethod: .password,
            isFavorite: existingHost?.isFavorite ?? false,
            lastConnected: existingHost?.lastConnected
        )

        do {
            if savePassword {
                if !password.isEmpty {
                    try KeychainService.shared.savePassword(password, for: host.id)
                } else if !hasStoredCredential || showPasswordField {
                    keychainErrorMessage = "Enter a password to save to Keychain."
                    showKeychainError = true
                    return
                }
            } else {
                try KeychainService.shared.deletePassword(for: host.id)
            }

            if existingHost != nil {
                hostStore.update(host)
            } else {
                hostStore.add(host)
            }

            dismiss()
        } catch {
            keychainErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showKeychainError = true
        }
    }
}

#Preview {
    HostEditView(hostStore: HostStore())
}
