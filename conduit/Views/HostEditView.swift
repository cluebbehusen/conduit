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

    init(hostStore: HostStore, existingHost: Host? = nil) {
        self.hostStore = hostStore
        self.existingHost = existingHost

        if let host = existingHost {
            _name = State(initialValue: host.name)
            _hostname = State(initialValue: host.hostname)
            _port = State(initialValue: String(host.port))
            _username = State(initialValue: host.username)
        }
    }

    private var isValid: Bool {
        !name.isEmpty && !hostname.isEmpty && !username.isEmpty && Int(port) != nil
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

                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }

                Section("Authentication") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(existingHost == nil ? "Add Host" : "Edit Host")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private func save() {
        let host = Host(
            id: existingHost?.id ?? UUID(),
            name: name,
            hostname: hostname,
            port: Int(port) ?? 22,
            username: username,
            authMethod: .password
        )

        if existingHost != nil {
            hostStore.update(host)
        } else {
            hostStore.add(host)
        }

        dismiss()
    }
}

#Preview {
    HostEditView(hostStore: HostStore())
}
