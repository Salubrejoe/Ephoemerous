import SwiftUI
import CoreLocation
import Observation
import CoreGraphics
import simd

// MARK: - EAppState
// The single source of truth for the app.
// Stored properties live here; all logic is delegated to focused extensions:
//   EAppState+Time.swift   — observation date, animation clock
//   EAppState+Space.swift  — observer geometry, origin/plane
//   EAppState+Stars.swift  — star filtering, caching, selection, recents
//   EAppState+Sheets.swift — sheet / modal presentation helpers
// Preset & tracking logic lives in EViewPreset.swift.

@Observable
class EAppState {

    // MARK: - Canvas feedback
    // Written by canvas layers each frame; read by tracking presets.
    var canvasSize:             CGSize             = .zero
    var sunScreenPosition:      CGPoint?           = nil
    var moonScreenPosition:     CGPoint?           = nil
    var selectedStarPositions:  [String: CGPoint]  = [:]

    // MARK: - App mode
    var appMode:        EAppMode        = .clock
    var projectionMode: ProjectionMode  = .drag
    var coupledAxis:    Axis?           = nil
    var haptics:        Bool            = false

    // MARK: - Temporal state  (logic → EAppState+Time.swift)
    var observationDate: Date   = .now  { didSet { invalidateStarCache() } }
    var animationTime:   Double = 0.0
    var _dateTransition: EDateTransition? = nil

    // MARK: - Spatial state  (logic → EAppState+Space.swift)
    var origin: Origin
    var plane:  Plane
    var scale:  Double   = AstroConstants.defaultScale
    var offset: CGPoint  = .init(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY)
    var _originTransition:  EOriginTransition?  = nil   // defined in EViewPreset.swift
    var _inertiaTransition: EInertiaTransition? = nil   // defined in EViewPreset.swift

    // MARK: - Star state  (logic → EAppState+Stars.swift)
    var magnitudeFilter: Double = AstroConstants.defaultMagCap { didSet { invalidateStarCache() } }
    var selectedStars:   [EStar] = [] {
        didSet {
            let names = selectedStars.map(\.name).joined(separator: ", ")
            ELogger.selectedStars("selection changed (\(selectedStars.count)) → [\(names)]")
            ECloudSync.shared.saveSelectedStars(selectedStars)
        }
    }
    private(set) var recentStars:            [EStar]        = []
    var currentlyDisplayedStar:              EStar?
    var currentlyDisplayedConstellation:     EConstellation?
    var _starsCache:                         [EStar]?        = nil
    var _travelStarsCache:                   [EStar]?        = nil

    // MARK: - Sheet state  (helpers → EAppState+Sheets.swift)
    var showSunInfo:         Bool = false
    var showMoonInfo:        Bool = false
    var showStarList:        Bool = false
    var showStarView:        Bool = false
    var showMagnFilter:      Bool = false
    var isShowingDatePicker: Bool = false

    // MARK: - Layer visibility
    var showEquatorTropics: Bool = true
    var showEcliptic:       Bool = true
    var showNSMeridians:    Bool = true
    var showULMeridians:    Bool = true
    var showHorizon:        Bool = true
    var showStars:          Bool = true
    var showPlanets:        Bool = true
    var showSelectedStars:  Bool = true

    // MARK: - Preset backing store  (logic → EViewPreset.swift)
    var _activeTransition: EPresetTransition? = nil

    // MARK: - Init
    init() {
        if let loc = ELocationService.shared.location {
            var o = Origin()
            o.latitude  = .degrees(loc.coordinate.latitude)
            o.longitude = .degrees(loc.coordinate.longitude)
            self.origin = o
        } else {
            self.origin = .init()
        }
        self.plane = .init()
    }
}

// MARK: - Supporting value types

enum EAppMode {
    case clock, travel
    mutating func toggle() { self = self == .clock ? .travel : .clock }
}

enum ProjectionMode: String, CaseIterable {
    case drag    = "drag"
    case coupled = "coupled"
    case origin  = "origin"

    var symbol: String {
        switch self {
        case .drag:    return "arrow.up.and.down.and.arrow.left.and.right"
        case .coupled: return "arcade.stick.and.arrow.up.and.arrow.down"
        case .origin:  return "figure.walk.motion"
        }
    }

    var color: Color {
        switch self {
        case .drag:    return .primary
        case .coupled: return .baseOrange
        case .origin:  return .baseCoral
        }
    }
}

struct Origin: Equatable {
    var latitude:  Angle = .degrees(51)
    var longitude: Angle = .zero
}

struct Plane: Equatable {
    var latitude:  Angle = .degrees(51 + 180)
    var longitude: Angle = .zero
}
