import SwiftUI
import simd
import LoreKit

// MARK: - AppState + Space
// Observer geometry: converts the stored origin/plane angles into
// the 3-D vectors and sidereal offsets the projection pipeline needs.
extension AppState {

    /// Unit vector pointing from the Earth's centre toward the observer's zenith.
    var originVector: SIMD3<Double> {
        Angle.spherePoint(latitude: origin.latitude, longitude: origin.longitude)
    }

    /// Unit vector normal to the view plane (used in north-south projection mode).
    var planeVector: SIMD3<Double> {
        Angle.spherePoint(latitude: plane.latitude, longitude: plane.longitude)
    }

    /// Per-frame snapshot of the projection vectors. Resolved once in
    /// `CelestialCanva` and threaded through `GraphicContext` so the
    /// per-point `Projection.project` calls never re-read observable
    /// origin / plane state. See `Projection.Viewpoint`.
    var viewpoint: Projection.Viewpoint {
        // Compass forces NorthIN; otherwise the eased `perspectiveMorph`
        // drives the projection (0 = NorthIN, 1 = NorthOUT).
        Projection.Viewpoint(originVector: originVector,
                              planeVector:  planeVector,
                              morph:        compassMode ? 0 : perspectiveMorph)
    }

    /// Effective sky perspective. Compass mode is intrinsically observer/AR,
    /// so it forces `.northIn` regardless of the toggle (they're mutually
    /// exclusive — engaging compass also clears `isNorthOut`).
    var skyPerspective: SkyPerspective {
        (isNorthOut && !compassMode) ? .northOut : .northIn
    }

    /// Toggle NorthOUT on/off. The view observes `isNorthOut` to reframe the
    /// camera for the new perspective.
    /// Flip NorthIN ↔ NorthOUT.
    ///
    /// Compass mode and NorthOUT are mutually exclusive perspectives — one
    /// is heading-up from where you stand, the other is a fixed
    /// pole-centred map — so taking the projection switches compass OFF
    /// rather than leaving the two to fight over the rotation. Disengaging
    /// first freezes the live heading into `canvasRotation`, so the sky
    /// doesn't snap before it morphs; the morph clock then animates the
    /// projection change from that pose.
    func toggleSkyPerspective() {
        if compassMode { disengageCompassMode() }
        isNorthOut.toggle()
    }

    /// Launch/home scale for NorthOUT (the pole-centred view). Framed so the
    /// tropic of Cancer matches the on-screen size of the NorthIN horizon:
    /// NorthIN frames its horizon (ρ = 2) at `defaultScale`, and in the
    /// pole-centred projection a Dec circle δ sits at ρ = 2·tan((δ+90°)/2),
    /// so the tropic (δ = +ε) is at ρ_tropic — scale down by 2/ρ_tropic.
    /// ▼ TWEAK the NorthOUT framing here ▼
    var northOutDefaultScale: Double {
        let eps       = Projection.obliquity.radians
        let tropicRho = 2 * tan((eps + .pi / 2) / 2)
        // Frame the tropic a touch INSIDE the horizon radius (1.65 vs 2) so
        // the ecliptic bodies — Sun/Moon — clear the crown ring at rest
        // instead of hiding behind it. This also lowers the NorthOUT zoom
        // floor (min == default here). ▼ TWEAK: lower = more zoomed out ▼
        return defaultScale * 1.65 / tropicRho
    }

    /// The direction of the zenith in equatorial coordinates at the rendered observation time.
    /// The Local Sidereal Time rotates the sky so that the meridian lines up with the observer.
    var observerZenith: SIMD3<Double> {
        let lst = Precession.lst(for: renderedObservationDate, longitude: origin.longitude)
        return Angle.spherePoint(latitude: origin.latitude, longitude: lst)
    }

    /// Rotation that carries equatorial vectors into the EARTH-FIXED frame
    /// the projection anchors live in: `originVector` / `planeVector` are
    /// geographic globe vectors (latitude, LONGITUDE), so the sky must spin
    /// over them by GMST alone — longitude enters through the anchor, not
    /// the rotation. A star culminating at the observer (RA = GMST + lon)
    /// then lands exactly on the anchor's meridian: RA − GMST = lon. ✓
    ///
    /// The old `-lst(date, lon)` counted longitude TWICE (once in LST, once
    /// in the anchor), skewing sky-vs-horizon by exactly `lon` — invisible
    /// at European longitudes (4–14° ≈ minutes of sky), catastrophic at
    /// Sydney's 151°E, where the whole sky sat ~10 hours off the horizon.
    var localSiderealOffset: Angle {
        -Precession.gmst(for: renderedObservationDate)
    }

    /// Greenwich Mean Sidereal Time offset, used for coordinate grids that are
    /// fixed to the celestial sphere rather than the local meridian.
    var precessedSiderealOffset: Angle {
        -Precession.gmstSiderealOffset(for: renderedObservationDate)
    }

    /// Launch / anchor scale — the canvas zoom the app starts at and
    /// the rubber-band "home" detent. Computed from canvas size so
    /// the projected horizon disc fits within the *shorter* device
    /// side with a small padding margin on each side.
    ///
    /// The horizon great circle has radius 2 in projection units
    /// (see `Projection.project`), so the on-screen disc diameter
    /// is `4 · scale`. Solving for "diameter = shorterSide − 2·pad"
    /// gives `scale = (shorterSide − 2·pad) / 4`.
    ///
    /// Falls back to `AstroConstants.defaultScale` while `canvasSize`
    /// is still zero — the very-first frame after launch. The
    /// canvasSize didSet in AppState.swift re-applies `defaultScale`
    /// the moment the real size arrives, so the launch view always
    /// lands at the canvas-derived value, not the fallback.
    var defaultScale: Double { defaultScale(for: canvasSize) }

    /// Size-explicit form of `defaultScale`, for callers that know the
    /// screen size before the clock canvas has published `canvasSize` —
    /// the SkyLab camera seeds its home / zoom floor from this at launch
    /// (see `seedCameraHome` in MainView😇).
    func defaultScale(for size: CGSize) -> Double {
        let pad: Double = 24
        let shorter = Swift.min(size.width, size.height)
        guard shorter > 0 else { return AstroConstants.defaultScale }
        return Swift.max(1, (shorter - 2 * pad) / 4)
    }

    /// Default offset derived from canvas height — falls back to AstroConstants while canvasSize is unknown.
    var defaultOffset: CGPoint {
        guard canvasSize.height > 0 else {
            return CGPoint(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY)
        }
        return CGPoint(x: 0, y: 0)
//        return CGPoint(x: -canvasSize.height / 8, y: 0)
    }

    /// Move the observer to a new geographic position. Defaults to also
    /// resetting the view plane to the antipodal point so the horizon
    /// stays sensible; pass `updatePlane: false` to nudge origin without
    /// touching the projection (used by the travel-mode two-finger
    /// origin-nudge gesture so the user previews a position without the
    /// projection morphing under them).
    ///
    /// Latitude is clamped just shy of ±90° so `planeVector` never lands
    /// at exactly (0, 0, ±1). That singularity makes `SIMD3.baseVectors()`
    /// fall through to its arbitrary `(1, 0, 0)` fallback, which is
    /// opposite the continuous limit from any neighbouring latitude —
    /// the resulting basis flip rotates every UL-projected layer by π
    /// the instant the latitude leaves the pole. 89.999° is
    /// pixel-indistinguishable from 90° on screen.
    func setOrigin(lat: Angle, lon: Angle,
                   updatePlane: Bool = true,
                   invalidatesCache: Bool = true) {
        let limit       = Angle.degrees(89.999)
        let clampedLat  = Angle.radians(max(-limit.radians,
                                            min(limit.radians, lat.radians)))
        origin.latitude  = clampedLat
        origin.longitude = lon
        // `invalidatesCache: false` lets per-frame origin tweens
        // (`advanceOriginTransition`, two-finger spring-back) avoid
        // thrashing the star cache — instead the caller invalidates
        // once at the end of the transition if the origin actually moved.
        if invalidatesCache { invalidateStarCache() }
        if updatePlane {
            plane.latitude  = Angle.radians(-clampedLat.radians)
            plane.longitude = lon + Angle.pi
        }
    }
}
