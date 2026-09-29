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

    /// Screen point for a spacecraft, or nil when it projects behind the
    /// viewer or there's no trustworthy data for that moment.
    ///
    /// `skyDate` is the moment the sky is drawn for. Pass `liveDate` (the
    /// wall clock) while the observation is "now": the craft is then placed
    /// where it really is against the HORIZON at that instant, even though
    /// the stars stay frozen at `skyDate` — the horizon is what you use to
    /// find it outside. Earth-fixed, a live direction is `R(−gmst(live))·d`;
    /// the camera applies `R(sidereal)`, so pre-rotating by
    /// `−sidereal − gmst(live)` lands it exactly there.
    func screen(_ craft: Spacecraft, skyDate: Date, liveDate: Date? = nil) -> CGPoint? {
        let when = liveDate ?? skyDate
        guard var dir = SpacecraftTracker.shared.direction(of: craft, at: when, from: spacecraftObserver)
        else { return nil }
        if liveDate != nil {
            dir = SatelliteSky.rotateZ(dir, by: -sidereal.radians - SatelliteSky.gmst(when))
        }
        return screen(equatorial: dir)
    }
}
