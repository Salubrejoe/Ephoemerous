import SwiftUI
import Observation
import CoreGraphics
import simd
import LoreKit

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
    var canvasSize: CGSize = .zero {
        didSet {
            if oldValue == .zero && canvasSize != .zero {
                scale  = defaultScale
                offset = defaultOffset
            }
        }
    }
    var sunScreenPosition:           CGPoint?                    = nil
    var moonScreenPosition:          CGPoint?                    = nil
    var selectedStarPositions:       [String: CGPoint]           = [:]
    // Per-constellation label hit area (the capsule rect), republished
    // every frame by ConstellationNamesLayer; read by ObjectsTrackingOverlay.
    var constellationLabelHitRects:  [EConstellation: CGRect]    = [:]

    // MARK: - App mode
    var appMode: EAppMode = .clock
    var haptics: Bool     = true

    // MARK: - Temporal state  (logic → EAppState+Time.swift)
    var observationDate: Date   = .now  { didSet { invalidateStarCache() } }
    var animationTime:   Double = 0.0
    var _dateTransition: EDateTransition? = nil

    // MARK: - Spatial state  (logic → EAppState+Space.swift)
    var origin:   Origin
    var plane:    Plane
    // Best-effort locality name for the current origin (e.g. "London"),
    // resolved asynchronously via `LocalityResolver`. `nil` while the
    // geocode is in flight or has failed — the toolbar falls back to
    // raw coordinates in that case. Refreshed via
    // `refreshLocalityName()` (see EAppState+Locality.swift).
    var localityName: String? = nil
    var scale:    Double   = AstroConstants.defaultScale
    var offset:   CGPoint  = .init(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY)
    var _originTransition:     EOriginTransition?     = nil   // defined in EAppState+Location.swift
    var _inertiaTransition:    FlingInertia?          = nil   // LoreKit (exponential-decay momentum)
    var _chromeTransition:     EChromeTransition?     = nil   // defined in EAppState+ProjectionBlend.swift
    // Snapshot of the clock-mode origin, captured on Clock→Travel so we can
    // slerp back to it on Travel→Clock. Travel mode parks the observer at NP.
    var _savedClockOrigin:     Origin?                = nil
    // Transient — true once the device's first location fix has been adopted
    // as the origin. Not persisted. See EAppState+Location.swift.
    var _didAdoptDeviceLocation: Bool = false

    // MARK: - Star state  (logic → EAppState+Stars.swift)
    var magnitudeFilter: Double = AstroConstants.defaultMagCap { didSet { invalidateStarCache() } }
    var selectedStars:   [EStar] = [] {
        didSet {
            let names = selectedStars.map(\.name).joined(separator: ", ")
            ELogger.selectedStars("selection changed (\(selectedStars.count)) → [\(names)]")
            ECloudSync.shared.saveSelectedStars(selectedStars)
        }
    }
    
    var recentStars:                         [EStar]        = []
    var currentlyDisplayedStar:              EStar?
    var currentlyDisplayedConstellation:     EConstellation?
    var _starsCache:                         [EStar]?        = nil
    var _travelStarsCache:                   [EStar]?        = nil

    // MARK: - Sheet state  (helpers → EAppState+Sheets.swift)
    var showSunInfo:           Bool = false
    var showMoonInfo:          Bool = false
    var showStarList:          Bool = false
    var showStarView:          Bool = false
    var showConstellationView: Bool = false
    var showMagnFilter:        Bool = false
    var isShowingDatePicker:     Bool = false
    var isShowingLocationPicker: Bool = false

    // MARK: - Layer visibility
    var showEquatorTropics: Bool = true
    var showEcliptic:       Bool = true
    var showNSMeridians:    Bool = true
    var showULMeridians:    Bool = true
    var showHorizon:        Bool = true
    var showStars:          Bool = true
    var showPlanets:        Bool = true
    var showSelectedStars:  Bool = true
    var showConstellationLines: Bool = true
    var showConstellationNames: Bool = true

    // MARK: - Preset backing store  (logic → EViewPreset.swift)
    var _activeTransition: EPresetTransition? = nil

    // MARK: - Init
    // At launch CoreLocation has no fix yet, so origin/plane start at their
    // defaults; the first real fix is adopted once via
    // adoptInitialDeviceLocation(_:) (see EAppState+Location.swift).
    init() {
        self.origin   = .init()
        self.plane    = .init()
    }
}

// MARK: - Supporting value types

// EAppMode and its behaviour live in EAppState+AppMode.swift.

struct Origin: Equatable {
    var latitude:  Angle = .degrees(51)
    var longitude: Angle = .zero
}

struct Plane: Equatable {
    var latitude:  Angle = .degrees(51 + 180)
    var longitude: Angle = .zero
}
