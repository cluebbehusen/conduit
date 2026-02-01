//
//  HostListView.swift
//  conduit
//

import SwiftUI

struct HostListView: View {
    @Environment(HostStore.self) private var hostStore
    @Environment(Settings.self) private var settings

    @State private var selectedHostID: Host.ID?
    @State private var showAddHost = false
    @State private var hostToEdit: Host?
    @State private var showSettings = false
    @State private var searchText = ""

    private var filteredHosts: [Host] {
        let sorted = hostStore.sortedHosts
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { host in
            host.name.localizedCaseInsensitiveContains(searchText) ||
                host.hostname.localizedCaseInsensitiveContains(searchText) ||
                host.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredHosts, id: \.id, selection: $selectedHostID) { host in
                NavigationLink(value: host) {
                    HostRow(host: host)
                }
                .contextMenu {
                    Button {
                        hostStore.toggleFavorite(host)
                    } label: {
                        Label(
                            host.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: host.isFavorite ? "star.slash" : "star"
                        )
                    }

                    Button {
                        hostToEdit = host
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        hostStore.delete(host)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        hostStore.toggleFavorite(host)
                    } label: {
                        Label(
                            host.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: host.isFavorite ? "star.slash" : "star.fill"
                        )
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        hostStore.delete(host)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Search hosts")
            .navigationTitle("Hosts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .overlay {
                if hostStore.hosts.isEmpty {
                    EmptyHostsView(showAddHost: $showAddHost)
                } else if filteredHosts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        } detail: {
            if let hostID = selectedHostID,
               let host = hostStore.hosts.first(where: { $0.id == hostID })
            {
                TerminalContainerView(host: host, showAddHost: $showAddHost)
            } else {
                NoHostSelectedView(showAddHost: $showAddHost)
            }
        }
        .sheet(isPresented: $showAddHost) {
            HostEditView(hostStore: hostStore)
                .preferredColorScheme(settings.appTheme.colorScheme)
        }
        .sheet(item: $hostToEdit) { host in
            HostEditView(hostStore: hostStore, existingHost: host)
                .preferredColorScheme(settings.appTheme.colorScheme)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(settings)
                .preferredColorScheme(settings.appTheme.colorScheme)
        }
    }
}

struct HostRow: View {
    @Environment(HostStore.self) private var hostStore
    let host: Host

    var body: some View {
        HStack(spacing: 12) {
            // Simple server icon
            Image(systemName: "terminal")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if host.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                    }

                    Text(host.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if host.hasStoredCredential {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                    }
                }

                HStack(spacing: 6) {
                    Text("\(host.username)@\(host.hostname)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if hostStore.isConnected(host) {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Text("connected")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if let lastConnected = host.lastConnectedFormatted {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Text(lastConnected)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - No Host Selected View

struct NoHostSelectedView: View {
    @Binding var showAddHost: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Host Selected", systemImage: "terminal")
        } description: {
            Text("Select a host to connect.")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddHost = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - Empty Hosts View

struct EmptyHostsView: View {
    @Binding var showAddHost: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Illustration - no glass, just a subtle background
            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 88, height: 88)

                Image(systemName: "server.rack")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("No Hosts Yet")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Add your first SSH host to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddHost = true
            } label: {
                Label("Add Host", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    HostListView()
        .environment(HostStore())
        .environment(Settings())
}
