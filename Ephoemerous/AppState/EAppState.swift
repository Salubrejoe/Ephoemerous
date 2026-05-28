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
    /// Per-planet screen position, republished every frame by
    /// `EPlanetsLayer`. Keyed by `planet.name` (the planet's unique
    /// id). `ObjectsTrackingOverlay` reads this to drop tap targets;
    /// `state.focus(on: .planet(...))` reads it to pan-to-centre.
    var planetPositions:             [String: CGPoint]           = [:]
    // Per-favourite screen position, republished every frame by
    // FavouritesLayer. Keyed by `ESkyObject.id` so it generalises
    // beyond stars — sun / moon / planets / constellations all get
    // the same per-frame position channel once we wire them up.
    var favouritePositions:          [String: CGPoint]           = [:]
    // Per-constellation label hit area (the capsule rect), republished
    // every frame by ConstellationNamesLayer; read by ObjectsTrackingOverlay.
    var constellationLabelHitRects:  [EConstellation: CGRect]    = [:]
    // Per-named-star label hit area, republished every frame by
    // NamedStarsLayer once the user zooms past `namedStarTapMinScale`.
    // Keyed by `star.name` (the catalogue name, e.g. "α CMa"); the
    // overlay resolves back to the EStar via NamedStarsLayer.star(named:).
    var namedStarHitRects:           [String: CGRect]            = [:]

    // MARK: - Haptics
    var haptics: Bool = true

    // MARK: - Canvas rotation
    //
    // Sky-fixed canvas: in landscape the celestial projection rotates
    // so "celestial up" (where the sun/north sit) lands by the
    // device's dynamic-island edge — same world-relative position as
    // portrait. The rotation is applied INSIDE `EGraphicContext.toScreen`,
    // so each projected point's *position* spins around the canvas
    // centre, but the badge shapes + glyphs + text labels drawn at
    // those positions stay axis-aligned to the device's current "up".
    // The gesture coordinator's `skyPoint` / `screenPin` apply the
    // inverse rotation so pan + pinch still match the user's drag
    // direction.
    //
    // Driven by `MainView` from `verticalSizeClass`:
    //   regular (portrait)  → 0°
    //   compact (landscape) → -90°  (correct for landscape-left;
    //                                mirrored for landscape-right)
    var canvasRotation: Angle = .zero

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
    // Transient — true once the device's first location fix has been adopted
    // as the origin. Not persisted. See EAppState+Location.swift.
    var _didAdoptDeviceLocation: Bool = false

    // MARK: - Star state  (logic → EAppState+Stars.swift)
    // Persisted to iCloud on every change via the didSet — keeping
    // the save here (rather than a `.onChange` in a view) means the
    // sync survives toolbar / sheet refactors and there's only one
    // source of truth for "magnitude filter changed".
    var magnitudeFilter: Double = AstroConstants.defaultMagCap {
        didSet {
            invalidateStarCache()
            ECloudSync.shared.saveMagnitudeFilter(magnitudeFilter)
        }
    }

    // MARK: - Favourites  (logic → EAppState+Favourites.swift)
    // Universal favourites list — any sky object the user has starred.
    // For now FavouritesLayer only renders the `.star` cases (halo +
    // pentagon badge); other cases are stored and ready to be wired
    // up when their favourite-visual treatment ships. iCloud sync
    // persists the .star subset to the existing key for back-compat.
    var favourites: [ESkyObject] = [] {
        didSet {
            let ids = favourites.map(\.id).joined(separator: ", ")
            ELogger.favourites("favourites changed (\(favourites.count)) → [\(ids)]")
            ECloudSync.shared.saveFavourites(favourites)
        }
    }

    var recentStars: [EStar]  = []
    var _starsCache: [EStar]? = nil

    // MARK: - Detail destination  (logic → EAppState+Detail.swift)
    // Single source of truth for "what detail is the user looking at?".
    // Replaces the old four-boolean / four-modal-sheet system
    // (showSunInfo / showMoonInfo / showStarView / showConstellationView
    //  plus currentlyDisplayedStar / currentlyDisplayedConstellation).
    // The root sheet in MainView binds to this; canvas taps go through
    // `focus(on:)` which sets it and pans the camera.
    var detailDestination: ESkyObject? = nil
    /// Monotonic counter bumped on every `focus(on:)` / `dismissDetail()`
    /// call. The deferred re-presentation in `focus(on:)` captures the
    /// epoch it scheduled with and aborts if anything else has happened
    /// since — so rapid taps can't race a pending `detailDestination`
    /// assignment back on top of a newer one. Observation-ignored:
    /// pure internal coordination, no view should redraw on it.
    @ObservationIgnored var _focusEpoch: UInt64 = 0

    // MARK: - Sheet state  (list + filter + inline pickers — modal flow
    // that hasn't been re-architected yet)
    var showStarList:            Bool = false
    var showMagnFilter:          Bool = false
    var isShowingDatePicker:     Bool = false
    var isShowingLocationPicker: Bool = false

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

struct Origin: Equatable {
    var latitude:  Angle = .degrees(51)
    var longitude: Angle = .zero
}

struct Plane: Equatable {
    var latitude:  Angle = .degrees(51 + 180)
    var longitude: Angle = .zero
}
