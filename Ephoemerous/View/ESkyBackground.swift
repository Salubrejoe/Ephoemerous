import SwiftUI

// MARK: - Sky palette

extension Color {
    static let deepNavy       = Color(hex: "#03001a")
    static let darkIndigo     = Color(hex: "#070022")
    static let nearBlack      = Color(hex: "#0a0015")
    
    static let twilightBlue   = Color(hex: "#1a2255")
    static let dustyPurple    = Color(hex: "#3d2860")
    static let mutedRose      = Color(hex: "#7d3b52")
    
    static let steelBlue      = Color(hex: "#475279")
    static let warmPink       = Color(hex: "#b55179")
    static let goldenAmber    = Color(hex: "#d3801e")
    
    static let skyBlue        = Color(hex: "#2a6aaa")
    static let lightCerulean  = Color(hex: "#5a9fd4")
    static let paleAzure      = Color(hex: "#a8d4f0")
    static let sunGold        = Color(hex: "#f0c060")
    //    static let sunGold        = Color(hex: "#a8d4f0")
    
    static let midnightBlue   = Color(hex: "#0d1240")
    static let darkTeal       = Color(hex: "#2f4858")
    static let lavenderMauve  = Color(hex: "#7d5487")
    
    static let deepPlum       = Color(hex: "#2a1f52")
    static let darkBerry      = Color(hex: "#4a1f3a")
    
    static let morningPeach   = Color(hex: "#e8b87c")
    static let morningGold    = Color(hex: "#e8a050")
    static let afternoonHaze  = Color(hex: "#7a9ec0")
    static let afternoonAmber = Color(hex: "#c87840")
}

// MARK: - Sky phase

enum ESkyPhase: CaseIterable, Equatable {
    case night, civilDawn, sunrise, morning, midday, afternoon, sunset, civilDusk

    var colors: [Color] {
        switch self {
        case .night:
            return [.deepNavy, .darkIndigo, .nearBlack]
        case .civilDawn:
            return [.twilightBlue, .dustyPurple, .mutedRose]
        case .sunrise:
            return [.twilightBlue, .steelBlue, .warmPink, .goldenAmber]
        case .morning:
            return [.skyBlue, .lightCerulean, .morningPeach, .morningGold]
        case .midday:
            return [.skyBlue, .lightCerulean, .paleAzure, .sunGold]
        case .afternoon:
            return [.skyBlue, .afternoonHaze, .afternoonAmber, .goldenAmber]
        case .sunset:
            return [.midnightBlue, .darkTeal, .lavenderMauve, .goldenAmber]
        case .civilDusk:
            return [.darkIndigo, .midnightBlue, .deepPlum, .darkBerry]
        }
    }

    var center: UnitPoint {
        switch self {
        case .night:                 return UnitPoint(x: 0.5, y: 1.1)
        case .civilDawn, .civilDusk: return UnitPoint(x: 0.5, y: 1.05)
        case .sunrise, .sunset:      return UnitPoint(x: 0.5, y: 1.0)
        case .morning, .afternoon:   return UnitPoint(x: 0.5, y: 0.95)
        case .midday:                return UnitPoint(x: 0.5, y: 0.9)
        }
    }

    @ViewBuilder
    var gradient: some View {
        GeometryReader { proxy in
            RadialGradient(
                colors: colors.reversed(),
                center: center,
                startRadius: -100,
                endRadius: proxy.size.height * 1.1
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Sky background

struct ESkyBackground: View {
    @Environment(EAppState.self) var state

    @State private var blendFactor:   Double    = 0
    @State private var currentPhase:  ESkyPhase = .night
    @State private var nextPhase:     ESkyPhase = .civilDawn
    @State private var lastUpdateTime: Date     = .distantPast

    private let scrubThreshold: TimeInterval = 0.2

    var body: some View {
        ZStack {
            currentPhase.gradient
            nextPhase.gradient
                .opacity(blendFactor)
        }
        .ignoresSafeArea()
        .onChange(of: state.observationDate) { updateSky() }
        .onChange(of: state.origin.latitude)  { updateSky() }
        .onChange(of: state.origin.longitude) { updateSky() }
        .onAppear { applySky() }
    }

    private func updateSky() {
        let now = Date()
        let isScrubbing = now.timeIntervalSince(lastUpdateTime) < scrubThreshold
        lastUpdateTime = now

        let (phase, next, blend) = resolvePhase(
            date: state.observationDate,
            latitude: state.origin.latitude,
            longitude: state.origin.longitude
        )

        if isScrubbing {
            currentPhase = phase
            nextPhase    = next
            blendFactor  = blend
        } else {
            currentPhase = phase
            nextPhase    = next
            blendFactor  = 0
            withAnimation(.easeInOut(duration: 1.5)) {
                blendFactor = blend
            }
        }
    }

    private func applySky() {
        let (phase, next, blend) = resolvePhase(
            date: state.observationDate,
            latitude: state.origin.latitude,
            longitude: state.origin.longitude
        )
        currentPhase = phase
        nextPhase    = next
        blendFactor  = blend
    }
}

// MARK: - Phase resolution from sun altitude

extension ESkyBackground {

    // Sun altitude in degrees for a given date and observer location
    private static func sunAltitude(date: Date, latitude: Angle, longitude: Angle) -> Double {
        let lambda = ESunPosition.eclipticLongitude(for: date)
        let (ra, dec) = ESunPosition.equatorialCoords(lambda: lambda)
        let lst = EPrecession.lst(for: date, longitude: longitude)
        let hourAngle = lst.radians - ra.radians
        let sinAlt = sin(dec.radians) * sin(latitude.radians)
                   + cos(dec.radians) * cos(latitude.radians) * cos(hourAngle)
        return asin(max(-1, min(1, sinAlt))) * 180 / .pi
    }

    private static let civilThreshold:  Double = -10.0
    private static let horizonBand:     Double =  10.0
    private static let middayThreshold: Double = 40.0

    private func resolvePhase(
        date: Date,
        latitude: Angle,
        longitude: Angle
    ) -> (current: ESkyPhase, next: ESkyPhase, blend: Double) {

        let alt = Self.sunAltitude(date: date, latitude: latitude, longitude: longitude)

        let altBefore = Self.sunAltitude(
            date: date.addingTimeInterval(-1800),
            latitude: latitude,
            longitude: longitude
        )
        let isRising = alt >= altBefore

        switch alt {

        case ..<(Self.civilThreshold):
            let depth = alt - (-18.0)
            let range = Self.civilThreshold - (-18.0)
            let blend = (depth / range).clamped(to: 0...1)
            if isRising {
                return (.night, .civilDawn, blend)
            } else {
                return (.night, .civilDusk, 1 - blend)
            }

        case Self.civilThreshold..<0:
            let blend = ((alt - Self.civilThreshold) / (0 - Self.civilThreshold)).clamped(to: 0...1)
            if isRising {
                return (.civilDawn, .sunrise, blend)
            } else {
                return (.sunset, .civilDusk, blend)
            }

        case 0..<Self.horizonBand:
            let blend = (alt / Self.horizonBand).clamped(to: 0...1)
            if isRising {
                return (.sunrise, .morning, blend)
            } else {
                return (.afternoon, .sunset, blend)
            }

        case Self.horizonBand..<Self.middayThreshold:
            if isRising {
                let blend = ((alt - Self.horizonBand) / (Self.middayThreshold - Self.horizonBand)).clamped(to: 0...1)
                return (.morning, .midday, blend)
            } else {
                let blend = ((Self.middayThreshold - alt) / (Self.middayThreshold - Self.horizonBand)).clamped(to: 0...1)
                return (.midday, .afternoon, blend)
            }

        default:
            return (.midday, .midday, 0)
        }
    }
}


/*
 static let deepNavy       = Color(hex: "#03001a")
 static let darkIndigo     = Color(hex: "#070022")
 static let nearBlack      = Color(hex: "#0a0015")
 
 static let twilightBlue   = Color(hex: "#1a2255")
 static let dustyPurple    = Color(hex: "#3d2860")
 static let mutedRose      = Color(hex: "#7d3b52")
 
 static let steelBlue      = Color(hex: "#475279")
 static let warmPink       = Color(hex: "#b55179")
 static let goldenAmber    = Color(hex: "#d3801e")
 
 static let skyBlue        = Color(hex: "#2a6aaa")
 static let lightCerulean  = Color(hex: "#5a9fd4")
 static let paleAzure      = Color(hex: "#a8d4f0")
 static let sunGold        = Color(hex: "#f0c060")
 //    static let sunGold        = Color(hex: "#a8d4f0")
 
 static let midnightBlue   = Color(hex: "#0d1240")
 static let darkTeal       = Color(hex: "#2f4858")
 static let lavenderMauve  = Color(hex: "#7d5487")
 
 static let deepPlum       = Color(hex: "#2a1f52")
 static let darkBerry      = Color(hex: "#4a1f3a")
 
 static let morningPeach   = Color(hex: "#e8b87c")
 static let morningGold    = Color(hex: "#e8a050")
 static let afternoonHaze  = Color(hex: "#7a9ec0")
 static let afternoonAmber = Color(hex: "#c87840")
 
 
 static let deepNavy       = Color(hex: "#05051a")
 static let darkIndigo     = Color(hex: "#0a0a1e")
 static let nearBlack      = Color(hex: "#080812")
 
 static let twilightBlue   = Color(hex: "#1e2748")
 static let dustyPurple    = Color(hex: "#352a4a")
 static let mutedRose      = Color(hex: "#5e3a48")
 
 static let steelBlue      = Color(hex: "#4a5468")
 static let warmPink       = Color(hex: "#8a5568")
 static let goldenAmber    = Color(hex: "#9a7040")
 
 static let skyBlue        = Color(hex: "#3a6088")
 static let lightCerulean  = Color(hex: "#5888a8")
 static let paleAzure      = Color(hex: "#8ab0ca")
 static let sunGold        = Color(hex: "#c0a870")
 
 static let midnightBlue   = Color(hex: "#101438")
 static let darkTeal       = Color(hex: "#2e4048")
 static let lavenderMauve  = Color(hex: "#604868")
 
 static let deepPlum       = Color(hex: "#252040")
 static let darkBerry      = Color(hex: "#3a2030")
 
 static let morningPeach   = Color(hex: "#b8a080")
 static let morningGold    = Color(hex: "#b09060")
 static let afternoonHaze  = Color(hex: "#6888a0")
 static let afternoonAmber = Color(hex: "#906848")
 */
