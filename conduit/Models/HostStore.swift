//
//  HostStore.swift
//  conduit
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class HostStore {
    private static let hostsKey = "savedHosts"

    var hosts: [Host] = []

    init() {
        load()
    }

    func add(_ host: Host) {
        hosts.append(host)
        save()
    }

    func update(_ host: Host) {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
            save()
        }
    }

    func delete(_ host: Host) {
        hosts.removeAll { $0.id == host.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        hosts.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(hosts) {
            UserDefaults.standard.set(data, forKey: Self.hostsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.hostsKey),
           let decoded = try? JSONDecoder().decode([Host].self, from: data)
        {
            hosts = decoded
        }
    }
}
