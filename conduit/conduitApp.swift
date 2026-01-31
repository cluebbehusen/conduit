//
//  conduitApp.swift
//  conduit
//
//  Created by Connor Luebbehusen on 1/31/26.
//

import SwiftUI

@main
struct ConduitApp: App {
    @State private var hostStore = HostStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(hostStore)
        }
    }
}
