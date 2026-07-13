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
    // User-controlled spin of the whole celestial canvas. Applied INSIDE
    // `EGraphicContext.toScreen`, so each projected point's *position*
    // rotates around the canvas centre while the badge shapes / glyphs /
    // text labels drawn there stay axis-aligned to screen "up". The
    // gesture coordinator's `skyPoint` / `screenPin` apply the inverse
    // rotation so pan + pinch still match the user's drag direction.
    //
    // The app is portrait-only, so this is NOT driven by device
    // orientation — it's owned entirely by the user (the rotation slider
    // today; the two-finger rotation gesture next), reset to 0° via the
    // compass control.
    var canvasRotation: Angle = .zero
    /// Compass (heading-up) mode. While true, `renderedRotation` ignores
    /// `canvasRotation` and follows the device heading instead, so the map
    /// spins under a fixed-up aim cone — the phone becomes the dial. Driven
    /// by `EMotionService.aim`; toggled via `toggleCompassMode()`.
    var compassMode: Bool = false
    /// NorthOUT toggle. While true (and NOT in compass mode) the projection
    /// switches to the celestial frame — centred on the South celestial pole,
    /// the sky fixed and the horizon the thing that moves. See
    /// `skyPerspective` / `SkyPerspective`. Mutually exclusive with compass
    /// mode (engaging compass clears it).
    var isNorthOut: Bool = false
    /// Smoothed heading rotation (radians) while in compass mode — the
    /// low-pass `renderedRotation` eases toward `−aim.azimuth` each frame.
    /// `nil` when not in compass mode (re-entry snaps fresh to the live
    /// heading). ObservationIgnored: it's mutated from inside the
    /// `renderedRotation` getter every frame and must not invalidate the
    /// view; the continuous redraw comes from the timeline, not from this.
    @ObservationIgnored var _compassRotCurrent: Double? = nil
    /// `animationTime` at the last compass-rotation step, for the per-frame
    /// dt the low-pass integrates against.
    @ObservationIgnored var _compassRotTime: Double = 0
    /// Drives the "return to your location?" confirmation before compass
    /// mode snaps the observer back to Here. Observed → MainView's `.alert`.
    var _compassReturnHomePrompt: Bool = false
    /// In-flight bouncy spin-back (the compass reset). Interpolated lazily
    /// in `renderedRotation` and nil'd when finished — same pattern as
    /// `_activeTransition`. Lets the *canvas* animate the rotation (it
    /// samples `renderedRotation` per frame); `withAnimation` alone only
    /// animates SwiftUI modifiers, so the sky would otherwise snap.
    var _rotationTransition: ERotationTransition? = nil

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
    /// Legacy manual magnitude cap. As of the zoom-driven star reveal,
    /// the visible magnitude is a function of zoom (see
    /// `EAppState.magnitudeCap(forScale:)`), so this no longer gates the
    /// star set. Kept only for iCloud back-compat (the key still
    /// round-trips) and any future "max depth" preference. No longer
    /// invalidates the star cache — the cache is magnitude-independent
    /// now (sorted once; capped per frame).
    var magnitudeFilter: Double = AstroConstants.defaultMagCap {
        didSet {
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

    /// Legacy stars-only recents — kept for the existing cloud key and
    /// any star-specific callers. Superseded for the search sheet by
    /// `recentObjects` (universal), which is what Recents renders.
    var recentStars: [EStar]  = []

    /// Universal "recently viewed" list — any sky object the user has
    /// opened (star / sun / moon / planet / constellation), most-recent
    /// first, capped at 10. Recorded in `focus(on:)` (the one funnel
    /// every selection passes through) and surfaced as the search
    /// sheet's Recents section. Persisted by object id via ECloudSync.
    var recentObjects: [ESkyObject] = []

    var _starsCache: [EStar]? = nil

    // MARK: - Star projection cache (gesture optimisation)
    // A star's PROJECTION (precess → project → projection-unit point)
    // depends only on (date, origin). `canvasRotation`, `scale` and
    // `offset` are all applied later, in `toScreen` — so pan, pinch AND
    // rotate leave the projection untouched and only change the cheap
    // post-transform. We cache each star's projection-unit point keyed by
    // (date, origin); while those hold, every gesture frame just re-runs
    // toScreen instead of re-projecting ~2k stars. Aligned 1:1 with
    // `sortedStars` (NaN where a star doesn't project). All
    // ObservationIgnored — pure per-frame render scratch. See `StarsLayer`.
    @ObservationIgnored var _lastStarKey:    StarProjectionKey? = nil
    @ObservationIgnored var _starProjKey:    StarProjectionKey? = nil
    @ObservationIgnored var _starProjPoints: [CGPoint] = []

    // MARK: - Curve projection caches (gesture optimisation)
    // Same invariant as the star cache, applied to every curve layer: the
    // grid meridians/parallels, the (bumped) horizon rim + twilight bands,
    // the zodiac-bulged ecliptic rim + glyph anchors, and the constellation
    // segment endpoints are all fixed in PROJECTION space while
    // (date, origin) hold — i.e. for every frame of a pan / pinch / rotate.
    // Each layer rebuilds its slice when its key falls stale and otherwise
    // just re-runs `toScreen` / `strokeCurve` on the cached points. All
    // ObservationIgnored — pure per-frame render scratch, written from
    // inside the Canvas closure.
    @ObservationIgnored var _gridProjKey:     StarProjectionKey? = nil
    @ObservationIgnored var _gridCurves:      [[CGPoint?]] = []
    @ObservationIgnored var _horizonProjKey:  StarProjectionKey? = nil
    @ObservationIgnored var _twilightBandPts: [[CGPoint?]] = []
    @ObservationIgnored var _horizonRimPts:   [CGPoint?] = []
    @ObservationIgnored var _eclipticProjKey: StarProjectionKey? = nil
    @ObservationIgnored var _eclipticRimPts:  [CGPoint?] = []
    @ObservationIgnored var _eclipticCentre:  CGPoint = .zero
    @ObservationIgnored var _zodiacGlyphPts:  [CGPoint?] = []
    @ObservationIgnored var _consSegProjKey:  StarProjectionKey? = nil
    @ObservationIgnored var _consSegProj:     [EConstellation: [(a: CGPoint, b: CGPoint)?]] = [:]

    // MARK: - Detail destination  (logic → EAppState+Detail.swift)
    // Single source of truth for "what detail is the user looking at?".
    // Replaces the old four-boolean / four-modal-sheet system
    // (showSunInfo / showMoonInfo / showStarView / showConstellationView
    //  plus currentlyDisplayedStar / currentlyDisplayedConstellation).
    // The root sheet in MainView binds to this; canvas taps go through
    // `focus(on:)` which sets it and pans the camera.
    var detailDestination: ESkyObject? = nil {
        didSet {
            // A selection (or deselection) starts a promotion spring,
            // animated on the canvas clock: the draw computes
            // `animationTime - _selectionStart`. The catch is that
            // `animationTime` is FROZEN while the canvas is parked at
            // rest — it only catches up to real time by ticking forward
            // once the timeline resumes. So we can't stamp these with
            // `Date.now`: the read side would sit seconds behind the
            // stamp and the spring would stay pinned at 0 until the
            // clock caught up (the "delay before the promotion shows").
            //
            // Instead stamp provisionally with the current (frozen)
            // `animationTime`, set `_promotionActive` (below) so the
            // timeline resumes, then RE-stamp on the first drawn frame
            // via the pending flags below (see `advanceCanvasClock`) so
            // the spring's elapsed starts at exactly 0 on the canvas
            // clock — no cross-clock skew.
            //
            // ObservationIgnored: `detailDestination` itself is observed
            // and drives the redraw; these are just timestamps read
            // inside that redraw.
            guard detailDestination?.id != oldValue?.id else { return }
            if let old = oldValue {
                _deselectingID       = old.id
                _deselectStart       = animationTime
                _deselectClockPending = true
            }
            if detailDestination != nil {
                // Sentinel "not started yet": until the pan lands and
                // `advanceCanvasClock` stamps the real start time, the
                // spring's elapsed (`animationTime - _selectionStart`)
                // stays hugely negative → `poiSelectProgress` clamps to
                // 0, so the label holds flat DURING the pan. Stamping the
                // tap time here instead would let the spring play against
                // that stale stamp through the pan (promote #1), then
                // replay on the pan-end re-stamp (promote #2) — the
                // double promotion.
                _selectionStart       = .greatestFiniteMagnitude
                _selectionClockPending = true
            }
            // Wake the timeline for the spring. Stable flag — see
            // `_promotionActive`; `advanceCanvasClock` clears it once
            // the spring settles.
            _promotionActive = true
        }
    }
    /// Canvas-clock time the current selection's promote-up spring
    /// began. Re-stamped on the first frame after selection (see
    /// `_selectionClockPending`).
    @ObservationIgnored var _selectionStart: Double = 0
    /// Id of the object whose label is springing back DOWN after being
    /// deselected (so it animates out instead of snapping), plus the
    /// canvas-clock time that spring began.
    @ObservationIgnored var _deselectingID: String? = nil
    @ObservationIgnored var _deselectStart: Double = 0
    /// Set in `detailDestination.didSet`, consumed on the next
    /// `advanceCanvasClock`: pins the spring start to that frame's live
    /// `animationTime` so the promotion's elapsed begins at 0 regardless
    /// of how stale the parked clock was at tap time.
    @ObservationIgnored var _selectionClockPending = false
    @ObservationIgnored var _deselectClockPending  = false

    /// True while a promotion spring is in flight — `CelestialCanva`
    /// ORs this into `isAnimating` so the timeline keeps ticking through
    /// the promotion, then parks once settled.
    ///
    /// CRITICAL: this is a STABLE stored flag, not a computed value that
    /// reads `animationTime`. `isAnimating` must not depend on
    /// `animationTime` — that value is written every frame *inside* the
    /// Canvas render, so if the schedule depended on it the write would
    /// re-invalidate the body every frame and never reach a fixed point,
    /// spinning the main thread (frozen sheet + gestures). Instead this
    /// flag is set true in `detailDestination.didSet` and flipped false
    /// exactly once by `advanceCanvasClock` when the spring settles —
    /// the same nil-once pattern `_activeTransition` uses.
    var _promotionActive: Bool = false

    /// Id of the object the camera most recently STARTED a focus-pan to,
    /// held while that pan is in flight. `panTo` skips re-panning to the
    /// same object so a fresh selection's two pan calls — focus(on:) and
    /// the detail view's .onAppear — don't fire two transitions. The
    /// `animateTo` target dedupe can't catch these now: the comfort zone
    /// makes the target position-dependent, and the two calls land a
    /// frame apart at different camera positions, so they compute
    /// DIFFERENT edge-pans → the second one used to restart the
    /// transition mid-flight (the "two-step" star/constellation move).
    /// Keyed on object, not target, so it's immune to that. Cleared when
    /// the pan settles (in advanceCanvasClock). A genuinely different
    /// object (constellation→star push, pop-back) still pans.
    @ObservationIgnored var _panningToID: String? = nil
    // (mythDestination removed — the myth cycle sheet is retired; each
    //  constellation shows its own story in EConstellationDetailView.)
    /// Monotonic counter bumped on every `focus(on:)`
    /// / `dismissDetail()` call. The deferred
    /// re-presentation in each opener captures the epoch it scheduled
    /// with and aborts if anything else has happened since — so rapid
    /// taps can't race a pending destination assignment back on top
    /// of a newer one. Observation-ignored: pure internal
    /// coordination, no view should redraw on it.
    @ObservationIgnored var _focusEpoch: UInt64 = 0

    // MARK: - Sheet state  (inline pickers — modal flow that hasn't
    // been re-architected yet). The magnitude filter and search are
    // both handled by local `@State` in MainView now.
    var isShowingDatePicker:     Bool = false
    var isShowingLocationPicker: Bool = false
    /// True only during the brief window where one bottom-slot sheet is
    /// being torn down and another presented in its place (detail ⇄ scene
    /// editor, detail → detail, detail → myth). The persistent search
    /// sheet keys off this so it doesn't flash into the teardown gap — see
    /// `presentSceneEditor` / `focus(on:)` / `openMyth(_:)` and MainView's
    /// `searchPresented`.
    var _sheetSwapping: Bool = false

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
