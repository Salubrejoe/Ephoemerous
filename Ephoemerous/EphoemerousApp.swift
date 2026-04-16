//
//  EphoemerousApp.swift
//  Ephoemerous
//
//  Created by Licurgen on 15/04/2026.
//

import SwiftUI

@main
struct EphoemerousApp: App {
    @State private var state = EAppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(state)
        }
    }
}
