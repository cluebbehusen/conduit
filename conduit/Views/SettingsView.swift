import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Settings.self) private var settings

    @State private var showClearAlert = false
    @State private var clearError: String?

    private let timeoutOptions: [(label: String, value: TimeInterval)] = [
        ("Always prompt", 0),
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("1 hour", 3600)
    ]

    var body: some View {
        @Bindable var bindableSettings = settings
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $bindableSettings.appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Terminal") {
                    Picker("Quick keys", selection: $bindableSettings.accessoryBarMode) {
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
                    Picker("Auto-lock timeout", selection: $bindableSettings.autoLockTimeout) {
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
        }
    }
}

#Preview {
    SettingsView()
        .environment(Settings())
}
