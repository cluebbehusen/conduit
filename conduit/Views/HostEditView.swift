//
//  HostEditView.swift
//  conduit
//

import SwiftUI

struct HostEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SSHKeyStore.self) private var keyStore
    @Environment(Settings.self) private var settings

    let hostStore: HostStore
    let existingHost: Host?

    @State private var name: String = ""
    @State private var hostname: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var authMethod: Host.AuthMethod = .password
    @State private var selectedKeyID: UUID?
    @State private var password: String = ""
    @State private var savePassword: Bool = false
    @State private var showPasswordField: Bool = false
    @State private var showKeychainError = false
    @State private var keychainErrorMessage = ""
    @State private var showKeyList = false

    init(hostStore: HostStore, existingHost: Host? = nil) {
        self.hostStore = hostStore
        self.existingHost = existingHost

        if let host = existingHost {
            _name = State(initialValue: host.name)
            _hostname = State(initialValue: host.hostname)
            _port = State(initialValue: String(host.port))
            _username = State(initialValue: host.username)
            _authMethod = State(initialValue: host.authMethod)
            _selectedKeyID = State(initialValue: host.keyID)
            _savePassword = State(initialValue: host.authMethod == .password && host.hasStoredCredential)
        }
    }

    private var isValid: Bool {
        let baseValid = !name.isEmpty && !hostname.isEmpty && !username.isEmpty && Int(port) != nil

        switch authMethod {
        case .password:
            let passwordRequired = savePassword && (!hasStoredPasswordCredential || showPasswordField)
            let passwordOK = !passwordRequired || !password.isEmpty
            return baseValid && passwordOK
        case .key:
            return baseValid && selectedKeyID != nil
        }
    }

    private var hasStoredPasswordCredential: Bool {
        guard let host = existingHost, host.authMethod == .password else { return false }
        return KeychainService.shared.hasPassword(for: host.id)
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

                    Picker("Method", selection: $authMethod) {
                        ForEach(Host.AuthMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if authMethod == .password {
                    passwordSection
                } else {
                    keySection
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
            .onChange(of: authMethod) { _, newValue in
                if newValue == .password {
                    selectedKeyID = nil
                } else {
                    savePassword = false
                    password = ""
                    showPasswordField = false
                }
            }
            .onChange(of: savePassword) { _, newValue in
                if newValue {
                    if !hasStoredPasswordCredential {
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
            .sheet(isPresented: $showKeyList) {
                KeyListView()
                    .environment(keyStore)
                    .environment(settings)
            }
        }
    }

    private var passwordSection: some View {
        Section {
            Toggle("Save password in Keychain", isOn: $savePassword)
                .toggleStyle(.switch)

            if !savePassword {
                Text("The password is stored securely and protected by biometrics.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if savePassword {
                if hasStoredPasswordCredential, !showPasswordField {
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

                if !hasStoredPasswordCredential || showPasswordField {
                    SecureField("Password", text: $password)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if hasStoredPasswordCredential, showPasswordField {
                        Button("Cancel update") {
                            password = ""
                            showPasswordField = false
                        }
                    }
                }
            }
        }
    }

    private var keySection: some View {
        Section {
            if keyStore.keys.isEmpty {
                HStack {
                    Text("No SSH keys available")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Import") {
                        showKeyList = true
                    }
                }
            } else {
                Picker("SSH Key", selection: $selectedKeyID) {
                    Text("Select a key").tag(nil as UUID?)
                    ForEach(keyStore.sortedKeys) { key in
                        HStack {
                            Text(key.name)
                            Spacer()
                            Text(key.keyType.displayName)
                                .foregroundStyle(.secondary)
                        }
                        .tag(key.id as UUID?)
                    }
                }

                Button {
                    showKeyList = true
                } label: {
                    Label("Manage Keys", systemImage: "key")
                }
            }
        } footer: {
            if let keyID = selectedKeyID, let key = keyStore.key(for: keyID) {
                Text("Fingerprint: \(key.shortFingerprint)")
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
            authMethod: authMethod,
            keyID: authMethod == .key ? selectedKeyID : nil,
            isFavorite: existingHost?.isFavorite ?? false,
            lastConnected: existingHost?.lastConnected
        )

        do {
            if authMethod == .password {
                if savePassword {
                    if !password.isEmpty {
                        try KeychainService.shared.savePassword(password, for: host.id)
                    } else if !hasStoredPasswordCredential || showPasswordField {
                        keychainErrorMessage = "Enter a password to save to Keychain."
                        showKeychainError = true
                        return
                    }
                } else {
                    try KeychainService.shared.deletePassword(for: host.id)
                }
            } else {
                // Clean up password if switching to key auth
                try? KeychainService.shared.deletePassword(for: host.id)
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
        .environment(SSHKeyStore())
        .environment(Settings())
}
