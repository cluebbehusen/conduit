//
//  ContentView.swift
//  conduit
//
//  Created by Connor Luebbehusen on 1/31/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        HostListView()
    }
}

#Preview {
    ContentView()
        .environment(HostStore())
        .environment(Settings())
}
