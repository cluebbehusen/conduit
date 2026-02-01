//
//  HostTests.swift
//  conduitTests
//

@testable import conduit
import Foundation
import Testing

@MainActor
struct HostTests {
    // MARK: - Codable Round-Trip

    @Test func codableRoundTrip() throws {
        let host = Host(
            name: "Test Server",
            hostname: "192.168.1.100",
            port: 2222,
            username: "testuser",
            authMethod: .password,
            isFavorite: true,
            lastConnected: Date(timeIntervalSince1970: 1_000_000)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(host)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Host.self, from: data)

        #expect(decoded.name == host.name)
        #expect(decoded.hostname == host.hostname)
        #expect(decoded.port == host.port)
        #expect(decoded.username == host.username)
        #expect(decoded.authMethod == host.authMethod)
        #expect(decoded.isFavorite == host.isFavorite)
        #expect(decoded.lastConnected == host.lastConnected)
    }

    @Test func codableRoundTripWithKeyAuth() throws {
        let keyID = UUID()
        let host = Host(
            name: "Key Auth Server",
            hostname: "example.com",
            username: "admin",
            authMethod: .key,
            keyID: keyID
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(host)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Host.self, from: data)

        #expect(decoded.authMethod == .key)
        #expect(decoded.keyID == keyID)
    }

    // MARK: - Default Values

    @Test func defaultPort() {
        let host = Host(name: "Test", hostname: "example.com", username: "user")
        #expect(host.port == 22)
    }

    @Test func defaultAuthMethod() {
        let host = Host(name: "Test", hostname: "example.com", username: "user")
        #expect(host.authMethod == .password)
    }

    @Test func defaultIsFavorite() {
        let host = Host(name: "Test", hostname: "example.com", username: "user")
        #expect(host.isFavorite == false)
    }

    @Test func defaultLastConnected() {
        let host = Host(name: "Test", hostname: "example.com", username: "user")
        #expect(host.lastConnected == nil)
    }

    // MARK: - AuthMethod

    @Test func authMethodDisplayNames() {
        #expect(Host.AuthMethod.password.displayName == "Password")
        #expect(Host.AuthMethod.key.displayName == "SSH Key")
    }

    @Test func authMethodCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for method in Host.AuthMethod.allCases {
            let data = try encoder.encode(method)
            let decoded = try decoder.decode(Host.AuthMethod.self, from: data)
            #expect(decoded == method)
        }
    }

    // MARK: - lastConnectedFormatted

    @Test func lastConnectedFormattedNil() {
        let host = Host(name: "Test", hostname: "example.com", username: "user")
        #expect(host.lastConnectedFormatted == nil)
    }

    @Test func lastConnectedFormattedJustNow() {
        var host = Host(name: "Test", hostname: "example.com", username: "user")
        host.lastConnected = Date()
        #expect(host.lastConnectedFormatted == "just now")
    }

    @Test func lastConnectedFormattedRecent() {
        var host = Host(name: "Test", hostname: "example.com", username: "user")
        host.lastConnected = Date().addingTimeInterval(-30)
        #expect(host.lastConnectedFormatted == "just now")
    }

    @Test func lastConnectedFormattedOlder() {
        var host = Host(name: "Test", hostname: "example.com", username: "user")
        host.lastConnected = Date().addingTimeInterval(-120) // 2 minutes ago
        let formatted = host.lastConnectedFormatted
        #expect(formatted != nil)
        #expect(formatted != "just now")
    }
}
