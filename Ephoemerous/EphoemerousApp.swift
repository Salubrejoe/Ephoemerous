//
//  EphoemerousApp.swift
//  Ephoemerous
//
//  Created by Licurgen on 15/04/2026.
//

import SwiftUI
import CoreLocation
import AppIntents

@main
struct EphoemerousApp: App {
    @State private var state: EAppState
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let state = EAppState()
        _state    = State(initialValue: state)
        // Hand the SAME instance the views observe to the App Intents
        // runtime — `OpenSkyObjectIntent` resolves it via `@Dependency`
        // so a Siri/widget launch drives the live scene, not a copy.
        AppDependencyManager.shared.add(dependency: state)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainView😇()
            }
            .ignoresSafeArea()
            
            .onAppear(perform: state.startCloudSync)
            
            .onChange(of: ELocationService.shared.location) { _, location in
                if let location { state.adoptInitialDeviceLocation(location) }
            }

            .onAppear(perform: EMotionService.shared.start)
            .onChange(of: scenePhase) { _, phase in
                // Attitude streaming is battery-cheap but pointless in
                // the background — stop with the app, resume on return.
                if phase == .active { EMotionService.shared.start() }
                else                { EMotionService.shared.stop()  }
            }
            .environment(state)
        }
    }
}

