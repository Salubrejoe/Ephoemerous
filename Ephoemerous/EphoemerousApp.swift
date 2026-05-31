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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainView()
                    .fontDesign(.rounded)
            }
            .ignoresSafeArea()
            .onAppear(perform: state.startCloudSync)
            .onAppear(perform: EMotionService.shared.start)
            .onChange(of: ELocationService.shared.location) { _, location in
                if let location { state.adoptInitialDeviceLocation(location) }
            }
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

