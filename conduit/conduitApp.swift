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
    @State private var settings = Settings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(hostStore)
                .environment(settings)
                .preferredColorScheme(settings.appTheme.colorScheme)
        }
    }
}
