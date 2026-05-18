//
//  EphoemerousApp.swift
//  Ephoemerous
//
//  Created by Licurgen on 15/04/2026.
//

import SwiftUI
import CoreLocation

@main
struct EphoemerousApp: App {
    @State private var state = EAppState()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainView()
            }
            .ignoresSafeArea()
            .onAppear { ECloudSync.shared.start(appState: state) }
            .onChange(of: ELocationService.shared.location) { _, loc in
                guard let loc, state.origin == .init() else { return }
                state.setOrigin(lat: .degrees(loc.coordinate.latitude),
                                lon: .degrees(loc.coordinate.longitude))
            }
            .environment(state)
        }
    }
}

