import SwiftUI
import simd

// MARK: - SkyCamera + Spacecraft
// A spacecraft's place in the sky depends on where you stand — the ISS
// shifts by tens of degrees between two cities — so projecting one needs
// the observer, not just the sky rotation. The camera already carries it:
// `originVector` is the observer's earth-fixed zenith (latitude, longitude),
// the same vector `observerLatitude` reads. Taking the observer from the
// camera keeps spacecraft glued to whatever origin the sky is drawn for,
// mid-transition included.
extension SkyCamera {

    var spacecraftObserver: SatelliteSky.Observer {
        let o = viewpoint.originVector
        return SatelliteSky.Observer(latitude:  asin(max(-1, min(1, o.z))),
                                     longitude: atan2(o.y, o.x))
    }

    /// Screen point for a spacecraft at `date`, or nil when it projects
    /// behind the viewer or there's no trustworthy data for that moment.
    func screen(_ craft: Spacecraft, at date: Date) -> CGPoint? {
        guard let dir = SpacecraftTracker.shared.direction(of: craft, at: date, from: spacecraftObserver)
        else { return nil }
        return screen(equatorial: dir)
    }
}
