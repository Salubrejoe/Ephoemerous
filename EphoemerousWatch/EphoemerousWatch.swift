//
//  EphoemerousWatch.swift
//  EphoemerousWatch
//
//  Created by Licurgen on 17/07/2026.
//

import AppIntents

struct EphoemerousWatch: AppIntent {
    static var title: LocalizedStringResource { "EphoemerousWatch" }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
