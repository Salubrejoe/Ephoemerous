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

    /// Move the observer to a new geographic position.
    /// In non-origin projection modes the view plane is automatically reset
    /// to the antipodal point so the horizon stays sensible.
    func setOrigin(lat: Angle, lon: Angle) {
        origin.latitude  = lat
        origin.longitude = lon
        invalidateStarCache()
        if projectionMode != .origin {
            plane.latitude  = -lat
            plane.longitude = lon + Angle.pi
        }
    }
}
