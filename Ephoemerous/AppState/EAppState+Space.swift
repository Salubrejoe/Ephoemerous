import SwiftUI
import simd

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

    /// Default scale derived from canvas height — falls back to AstroConstants while canvasSize is unknown.
    var defaultScale: Double {
        canvasSize.height > 0 ? canvasSize.height / 20 : AstroConstants.defaultScale
    }

    /// Scale used when tracking a celestial object (zoomed in relative to default).
    var trackingScale: Double {
        canvasSize.height > 0 ? canvasSize.height / 6 : AstroConstants.defaultScale
    }

    /// Default offset derived from canvas height — falls back to AstroConstants while canvasSize is unknown.
    var defaultOffset: CGPoint {
        guard canvasSize.height > 0 else {
            return CGPoint(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY)
        }
        return CGPoint(x: -canvasSize.height / 8, y: 0)
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
    func setOrigin(lat: Angle, lon: Angle, updatePlane: Bool = true) {
        let limit       = Angle.degrees(89.999)
        let clampedLat  = Angle.radians(max(-limit.radians,
                                            min(limit.radians, lat.radians)))
        origin.latitude  = clampedLat
        origin.longitude = lon
        invalidateStarCache()
        if updatePlane {
            plane.latitude  = Angle.radians(-clampedLat.radians)
            plane.longitude = lon + Angle.pi
        }
    }
}
