//
//  HostStoreTests.swift
//  conduitTests
//

@testable import conduit
import Foundation
import Testing

@MainActor
struct HostStoreTests {
    private static let suiteName = "HostStoreTests"

    private func makeStore() -> HostStore {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            fatalError("Failed to create UserDefaults for test suite")
        }
        defaults.removePersistentDomain(forName: Self.suiteName)
        return HostStore(defaults: defaults)
    }

    // MARK: - Add

    @Test func addHost() {
        let store = makeStore()
        let host = Host(name: "Test", hostname: "example.com", username: "user")

        store.add(host)

        #expect(store.hosts.count == 1)
        #expect(store.hosts.first?.name == "Test")
    }

    @Test func addMultipleHosts() {
        let store = makeStore()

        store.add(Host(name: "Server 1", hostname: "s1.example.com", username: "user"))
        store.add(Host(name: "Server 2", hostname: "s2.example.com", username: "user"))

        #expect(store.hosts.count == 2)
    }

    // MARK: - Update

    @Test func updateHost() {
        let store = makeStore()
        var host = Host(name: "Test", hostname: "example.com", username: "user")
        store.add(host)

        host.name = "Updated Name"
        store.update(host)

        #expect(store.hosts.first?.name == "Updated Name")
    }

    @Test func updateNonexistentHostDoesNothing() {
        let store = makeStore()
        let host = Host(name: "Test", hostname: "example.com", username: "user")

        store.update(host) // Host not in store

        #expect(store.hosts.isEmpty)
    }

    // MARK: - Delete

    @Test func deleteHost() {
        let store = makeStore()
        let host = Host(name: "Test", hostname: "example.com", username: "user")
        store.add(host)

        store.delete(host)

        #expect(store.hosts.isEmpty)
    }

    @Test func deleteAtOffsets() {
        let store = makeStore()
        store.add(Host(name: "Server 1", hostname: "s1.example.com", username: "user"))
        store.add(Host(name: "Server 2", hostname: "s2.example.com", username: "user"))

        store.delete(at: IndexSet(integer: 0))

        #expect(store.hosts.count == 1)
        #expect(store.hosts.first?.name == "Server 2")
    }

    // MARK: - Persistence

    @Test func persistsAcrossInstances() throws {
        let defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)

        // Create first store and add host
        let store1 = HostStore(defaults: defaults)
        store1.add(Host(name: "Persistent", hostname: "example.com", username: "user"))

        // Create second store with same defaults
        let store2 = HostStore(defaults: defaults)

        #expect(store2.hosts.count == 1)
        #expect(store2.hosts.first?.name == "Persistent")
    }

    // MARK: - Favorites

    @Test func toggleFavorite() throws {
        let store = makeStore()
        let host = Host(name: "Test", hostname: "example.com", username: "user")
        store.add(host)

        #expect(store.hosts.first?.isFavorite == false)

        store.toggleFavorite(host)

        #expect(store.hosts.first?.isFavorite == true)

        try store.toggleFavorite(#require(store.hosts.first))

        #expect(store.hosts.first?.isFavorite == false)
    }

    // MARK: - Sorting

    @Test func sortedHostsFavoritesFirst() {
        let store = makeStore()
        var host1 = Host(name: "Zebra", hostname: "z.example.com", username: "user")
        let host2 = Host(name: "Alpha", hostname: "a.example.com", username: "user")

        store.add(host1)
        store.add(host2)

        // Before favoriting - alphabetical order
        #expect(store.sortedHosts.first?.name == "Alpha")

        // Favorite Zebra
        host1.isFavorite = true
        store.update(host1)

        // After favoriting - favorites first
        #expect(store.sortedHosts.first?.name == "Zebra")
    }

    @Test func sortedHostsAlphabeticalWithinGroups() {
        let store = makeStore()
        store.add(Host(name: "Charlie", hostname: "c.example.com", username: "user"))
        store.add(Host(name: "Alpha", hostname: "a.example.com", username: "user"))
        store.add(Host(name: "Bravo", hostname: "b.example.com", username: "user"))

        let names = store.sortedHosts.map(\.name)
        #expect(names == ["Alpha", "Bravo", "Charlie"])
    }

    // MARK: - Connection Tracking

    @Test func recordConnection() {
        let store = makeStore()
        let host = Host(name: "Test", hostname: "example.com", username: "user")
        store.add(host)

        #expect(store.hosts.first?.lastConnected == nil)

        store.recordConnection(for: host)

        #expect(store.hosts.first?.lastConnected != nil)
    }

    @Test func markConnectedAndDisconnected() {
        let store = makeStore()
        let host = Host(name: "Test", hostname: "example.com", username: "user")
        store.add(host)

        #expect(store.isConnected(host) == false)

        store.markConnected(host)
        #expect(store.isConnected(host) == true)

        store.markDisconnected(host)
        #expect(store.isConnected(host) == false)
    }
}
