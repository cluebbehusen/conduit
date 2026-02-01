//
//  SSHKeyStoreTests.swift
//  conduitTests
//

@testable import conduit
import Foundation
import Testing

@MainActor
struct SSHKeyStoreTests {
    private static let suiteName = "SSHKeyStoreTests"

    private func makeStore() -> SSHKeyStore {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            fatalError("Failed to create UserDefaults for test suite")
        }
        defaults.removePersistentDomain(forName: Self.suiteName)
        return SSHKeyStore(defaults: defaults)
    }

    private func makeKey(name: String = "Test Key") -> SSHKey {
        SSHKey(
            name: name,
            keyType: .ed25519,
            fingerprint: "aa:bb:cc:dd",
            publicKeyData: Data([0x01, 0x02, 0x03]),
            requiresPassphrase: false,
            createdAt: Date()
        )
    }

    // MARK: - Add

    @Test func addKey() {
        let store = makeStore()
        let key = makeKey()

        store.add(key)

        #expect(store.keys.count == 1)
        #expect(store.keys.first?.name == "Test Key")
    }

    @Test func addMultipleKeys() {
        let store = makeStore()

        store.add(makeKey(name: "Key 1"))
        store.add(makeKey(name: "Key 2"))

        #expect(store.keys.count == 2)
    }

    // MARK: - Update

    @Test func updateKey() {
        let store = makeStore()
        var key = makeKey()
        store.add(key)

        key.name = "Updated Name"
        store.update(key)

        #expect(store.keys.first?.name == "Updated Name")
    }

    @Test func updateNonexistentKeyDoesNothing() {
        let store = makeStore()
        let key = makeKey()

        store.update(key) // Key not in store

        #expect(store.keys.isEmpty)
    }

    // MARK: - Delete

    @Test func deleteKey() {
        let store = makeStore()
        let key = makeKey()
        store.add(key)

        store.delete(key)

        #expect(store.keys.isEmpty)
    }

    @Test func deleteAtOffsets() {
        let store = makeStore()
        store.add(makeKey(name: "Key 1"))
        store.add(makeKey(name: "Key 2"))

        store.delete(at: IndexSet(integer: 0))

        #expect(store.keys.count == 1)
        #expect(store.keys.first?.name == "Key 2")
    }

    // MARK: - Lookup

    @Test func keyForId() {
        let store = makeStore()
        let key = makeKey()
        store.add(key)

        let found = store.key(for: key.id)

        #expect(found != nil)
        #expect(found?.id == key.id)
    }

    @Test func keyForIdNotFound() {
        let store = makeStore()

        let found = store.key(for: UUID())

        #expect(found == nil)
    }

    // MARK: - Persistence

    @Test func persistsAcrossInstances() throws {
        let defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)

        // Create first store and add key
        let store1 = SSHKeyStore(defaults: defaults)
        store1.add(makeKey(name: "Persistent Key"))

        // Create second store with same defaults
        let store2 = SSHKeyStore(defaults: defaults)

        #expect(store2.keys.count == 1)
        #expect(store2.keys.first?.name == "Persistent Key")
    }

    // MARK: - Sorting

    @Test func sortedKeysAlphabetical() {
        let store = makeStore()
        store.add(makeKey(name: "Charlie"))
        store.add(makeKey(name: "Alpha"))
        store.add(makeKey(name: "Bravo"))

        let names = store.sortedKeys.map(\.name)
        #expect(names == ["Alpha", "Bravo", "Charlie"])
    }

    @Test func sortedKeysCaseInsensitive() {
        let store = makeStore()
        store.add(makeKey(name: "alpha"))
        store.add(makeKey(name: "Bravo"))
        store.add(makeKey(name: "CHARLIE"))

        let names = store.sortedKeys.map(\.name)
        #expect(names == ["alpha", "Bravo", "CHARLIE"])
    }
}
