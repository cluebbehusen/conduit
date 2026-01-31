//
//  HostListView.swift
//  conduit
//

import SwiftUI

struct HostListView: View {
    @Environment(HostStore.self) private var hostStore

    @State private var selectedHost: Host?
    @State private var showAddHost = false
    @State private var hostToEdit: Host?

    var body: some View {
        NavigationSplitView {
            List(hostStore.hosts, selection: $selectedHost) { host in
                NavigationLink(value: host) {
                    HostRow(host: host)
                }
                .contextMenu {
                    Button {
                        hostToEdit = host
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        hostStore.delete(host)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        hostStore.delete(host)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Hosts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddHost = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if hostStore.hosts.isEmpty {
                    ContentUnavailableView {
                        Label("No Hosts", systemImage: "server.rack")
                    } description: {
                        Text("Add a host to get started.")
                    } actions: {
                        Button("Add Host") {
                            showAddHost = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        } detail: {
            if let host = selectedHost {
                TerminalContainerView(host: host)
            } else {
                ContentUnavailableView {
                    Label("No Host Selected", systemImage: "terminal")
                } description: {
                    Text("Select a host to connect.")
                }
            }
        }
        .sheet(isPresented: $showAddHost) {
            HostEditView(hostStore: hostStore)
        }
        .sheet(item: $hostToEdit) { host in
            HostEditView(hostStore: hostStore, existingHost: host)
        }
    }
}

struct HostRow: View {
    let host: Host

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(host.name)
                .font(.headline)

            Text("\(host.username)@\(host.hostname):\(host.port)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HostListView()
        .environment(HostStore())
}
