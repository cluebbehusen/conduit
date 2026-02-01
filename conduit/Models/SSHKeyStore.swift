//
//  SSHKeyStore.swift
//  conduit
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class SSHKeyStore {
    private static let keysKey = "savedSSHKeys"

    private let defaults: UserDefaults
    var keys: [SSHKey] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ key: SSHKey) {
        keys.append(key)
        save()
    }

    func update(_ key: SSHKey) {
        if let index = keys.firstIndex(where: { $0.id == key.id }) {
            keys[index] = key
            save()
        }
    }

    func delete(_ key: SSHKey) {
        keys.removeAll { $0.id == key.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        keys.remove(atOffsets: offsets)
        save()
    }

    func key(for id: UUID) -> SSHKey? {
        keys.first { $0.id == id }
    }

    /// Returns keys sorted by name
    var sortedKeys: [SSHKey] {
        keys.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(keys) {
            defaults.set(data, forKey: Self.keysKey)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: Self.keysKey),
           let decoded = try? JSONDecoder().decode([SSHKey].self, from: data)
        {
            keys = decoded
        }
    }
}
