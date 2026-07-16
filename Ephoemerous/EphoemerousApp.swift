//
//  EphoemerousApp.swift
//  Ephoemerous
//
//  Created by Licurgen on 15/04/2026.
//

import SwiftUI
import CoreLocation
import AppIntents
import WidgetKit

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
            .preferredColorScheme(.dark)
            .ignoresSafeArea()
            
            .onAppear(perform: state.startCloudSync)
            
            .onChange(of: ELocationService.shared.location) { _, location in
                if let location { state.adoptInitialDeviceLocation(location) }
            }

            // Widget tap-through: ephoemerous://object/<entity-id> lands on
            // the same focus path as a canvas tap. The id is the durable
            // SkyObjectEntity scheme (star_Sirius, planet_Mars, sun…).
            .onOpenURL { url in
                guard url.scheme == "ephoemerous", url.host() == "object",
                      let id  = url.pathComponents.dropFirst().first,
                      let obj = SkyObjectEntity(id: id)?.skyObject
                else { return }
                state.focus(on: obj)
            }

            .onAppear(perform: EMotionService.shared.start)
            .onChange(of: scenePhase) { _, phase in
                // Attitude streaming is battery-cheap but pointless in
                // the background — stop with the app, resume on return.
                if phase == .active { EMotionService.shared.start() }
                else                { EMotionService.shared.stop()  }
                // Leaving: park the observer origin for the widget process
                // (it has no location access) and re-render the widgets so
                // fresh favourites / origin land immediately.
                if phase == .background {
                    ECloudSync.shared.saveObserverOrigin(
                        latDeg: state.origin.latitude.degrees,
                        lonDeg: state.origin.longitude.degrees)
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .environment(state)
        }
    }
}

