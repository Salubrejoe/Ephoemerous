import SwiftUI
import simd
import LoreKit

// MARK: - EAppState + Space
// Observer geometry: converts the stored origin/plane angles into
// the 3-D vectors and sidereal offsets the projection pipeline needs.
extension EAppState {

    /// Unit vector pointing from the Earth's centre toward the observer's zenith.
    var originVector: SIMD3<Double> {
        Angle.spherePoint(latitude: origin.latitude, longitude: origin.longitude)
    }

    /// Unit vector normal to the view plane (used in north-south projection mode).
    var planeVector: SIMD3<Double> {
        Angle.spherePoint(latitude: plane.latitude, longitude: plane.longitude)
    }

    /// Per-frame snapshot of the projection vectors. Resolved once in
    /// `CelestialCanva` and threaded through `EGraphicContext` so the
    /// per-point `EProjection.project` calls never re-read observable
    /// origin / plane state. See `EProjection.Viewpoint`.
    var viewpoint: EProjection.Viewpoint {
        // Compass forces NorthIN; otherwise the eased `perspectiveMorph`
        // drives the projection (0 = NorthIN, 1 = NorthOUT).
        EProjection.Viewpoint(originVector: originVector,
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
    func toggleSkyPerspective() { isNorthOut.toggle() }

    /// Launch/home scale for NorthOUT (the pole-centred view). Framed so the
    /// tropic of Cancer matches the on-screen size of the NorthIN horizon:
    /// NorthIN frames its horizon (ρ = 2) at `defaultScale`, and in the
    /// pole-centred projection a Dec circle δ sits at ρ = 2·tan((δ+90°)/2),
    /// so the tropic (δ = +ε) is at ρ_tropic — scale down by 2/ρ_tropic.
    /// ▼ TWEAK the NorthOUT framing here ▼
    var northOutDefaultScale: Double {
        let eps       = EProjection.obliquity.radians
        let tropicRho = 2 * tan((eps + .pi / 2) / 2)
        return defaultScale * 2 / tropicRho
    }

    /// The direction of the zenith in equatorial coordinates at the rendered observation time.
    /// The Local Sidereal Time rotates the sky so that the meridian lines up with the observer.
    var observerZenith: SIMD3<Double> {
        let lst = EPrecession.lst(for: renderedObservationDate, longitude: origin.longitude)
        return Angle.spherePoint(latitude: origin.latitude, longitude: lst)
    }

    /// Rotation angle that aligns the equatorial coordinate grid with the local sidereal time.
    /// Canvas layers apply this as a rotation offset so stars drift westward over time.
    var localSiderealOffset: Angle {
        -EPrecession.lst(for: renderedObservationDate, longitude: origin.longitude)
    }

    /// Greenwich Mean Sidereal Time offset, used for coordinate grids that are
    /// fixed to the celestial sphere rather than the local meridian.
    var precessedSiderealOffset: Angle {
        -EPrecession.gmstSiderealOffset(for: renderedObservationDate)
    }

    /// Launch / anchor scale — the canvas zoom the app starts at and
    /// the rubber-band "home" detent. Computed from canvas size so
    /// the projected horizon disc fits within the *shorter* device
    /// side with a small padding margin on each side.
    ///
    /// The horizon great circle has radius 2 in projection units
    /// (see `EProjection.project`), so the on-screen disc diameter
    /// is `4 · scale`. Solving for "diameter = shorterSide − 2·pad"
    /// gives `scale = (shorterSide − 2·pad) / 4`.
    ///
    /// Falls back to `AstroConstants.defaultScale` while `canvasSize`
    /// is still zero — the very-first frame after launch. The
    /// canvasSize didSet in EAppState.swift re-applies `defaultScale`
    /// the moment the real size arrives, so the launch view always
    /// lands at the canvas-derived value, not the fallback.
    var defaultScale: Double {
        let pad: Double = 24
        let shorter = Swift.min(canvasSize.width, canvasSize.height)
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
