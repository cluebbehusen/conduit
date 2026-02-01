import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SecuritySettings.self) private var securitySettings

    @State private var showClearAlert = false
    @State private var showClearKnownHostsAlert = false
    @State private var clearError: String?

    private let timeoutOptions: [(label: String, value: TimeInterval)] = [
        ("Always prompt", 0),
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("1 hour", 3600)
    ]

    var body: some View {
        @Bindable var settings = securitySettings
        NavigationStack {
            Form {
                Section("Terminal") {
                    Picker("Quick keys", selection: $settings.accessoryBarMode) {
                        ForEach(AccessoryBarMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    Text("Quick access to special keys while typing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Security") {
                    Picker("Auto-lock timeout", selection: $settings.autoLockTimeout) {
                        ForEach(timeoutOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                    Text("Controls how long a successful biometric unlock is trusted before asking again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Credentials") {
                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        Label("Clear saved passwords", systemImage: "trash")
                    }
                    Button(role: .destructive) {
                        showClearKnownHostsAlert = true
                    } label: {
                        Label("Clear known hosts", systemImage: "key")
                    }
                    if let clearError {
                        Text(clearError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
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
            .alert("Clear saved passwords?", isPresented: $showClearAlert) {
                Button("Delete", role: .destructive) {
                    do {
                        try KeychainService.shared.deleteAllPasswords()
                        settings.resetUnlock()
                    } catch {
                        clearError = error.localizedDescription
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all passwords stored in the Keychain for Conduit.")
            }
            .alert("Clear known hosts?", isPresented: $showClearKnownHostsAlert) {
                Button("Delete", role: .destructive) {
                    KnownHostsService.shared.removeAllKnownHosts()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    """
                    This removes all trusted host fingerprints. \
                    You will need to verify each host again on next connection.
                    """
                )
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(SecuritySettings())
}
