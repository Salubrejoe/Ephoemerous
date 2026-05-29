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
                    .fontDesign(.rounded)
            }
            .ignoresSafeArea()
            .onAppear(perform: state.startCloudSync)
            .onChange(of: ELocationService.shared.location) { _, location in
                if let location { state.adoptInitialDeviceLocation(location) }
            }
            .environment(state)
        }
    }
}

