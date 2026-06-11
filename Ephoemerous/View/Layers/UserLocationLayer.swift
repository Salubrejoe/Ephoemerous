import SwiftUI
import CoreLocation

// MARK: - UserLocationLayer
// Draws the whole "you are here" cluster — aim indicator + globe puck —
// directly on the procedural canvas. The puck is anchored at the zenith
// (`dc.toScreen(.zero)`); the aim indicator shows where the phone is
// pointed: a device-motion blob roaming to the real stars it aims at,
// or — with no gyro — the legacy heading cone fanning from the zenith.
//
// Visibility gate: when the observer origin doesn't match the device's
// actual fix (the user has panned the map elsewhere), the whole cluster
// is omitted. `state.isAtDeviceLocation` is the single source of truth,
// and it short-circuits BEFORE reading `EMotionService.aim`, so a
// panned-away canvas never takes a motion dependency and stays idle.
// Drawn last in `CelestialCanva.layers`, so the puck sits on top.
struct UserLocationLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        // The user has moved the observer elsewhere → a "you are
        // here" mark would be misleading. Bail.
        guard dc.state.isAtDeviceLocation else { return }

        // Zenith — the projection origin — lives at screen centre
        // shifted by the user's pan offset. The puck lives here.
        let sc = dc.toScreen(.zero)

        // Aim indicator behind the puck (blob if motion is live, else
        // the heading cone, else nothing).
        drawAim(in: &dc, zenith: sc)

        // Globe puck on top — longitude-keyed so it wears the
        // continent the observer actually sits on.
        let symbol = artist.userLocationGlobeSymbol(
            forLongitude: dc.state.origin.longitude.degrees)
        artist.drawSquircleGlobePuck(at: sc, symbol: symbol, in: &dc)
    }

    /// Where-am-I-pointing mark. Prefers the device-motion cone — a
    /// wedge from the puck whose direction is the phone's azimuth and
    /// whose length tracks pitch (reaching the horizon when the phone lies
    /// flat, shrinking to the puck when it stands vertical). Falls back to
    /// the fixed heading cone when there's no gyro (Simulator) or no
    /// attitude sample yet.
    private func drawAim(in dc: inout EGraphicContext, zenith sc: CGPoint) {
        // Compass heading uncertainty drives the fan WIDTH for either
        // cone; negative means the magnetometer isn't calibrated yet.
        let compass = ELocationService.shared.heading
        let accuracy = (compass?.headingAccuracy ?? -1) >= 0
            ? compass!.headingAccuracy
            : artist.userPuckConeMinHalfAngle

        // Live device motion → the real direction cone.
        if let aim = EMotionService.shared.aim {
            artist.drawAimCone(at:       sc,
                               azimuth:  aim.azimuth,
                               altitude: aim.altitude,
                               accuracy: accuracy,
                               in:       &dc)
            return
        }

        // Fallback: fixed-length heading cone (needs a calibrated compass).
        if let h = compass, h.headingAccuracy >= 0 {
            // Prefer `trueHeading` (geographic north); fall back to
            // magnetic if true is invalid (no fix yet).
            let heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
            artist.drawHeadingCone(at:       sc,
                                   heading:  heading,
                                   accuracy: h.headingAccuracy,
                                   in:       &dc)
        }
    }
}
