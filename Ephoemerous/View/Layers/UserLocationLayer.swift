import SwiftUI
import CoreLocation

// MARK: - UserLocationLayer
// Draws the whole "you are here" cluster — heading cone fan + globe
// puck — directly on the procedural canvas, anchored at the zenith
// (`dc.toScreen(.zero)`) so it tracks the projection every frame.
//
// Visibility gate: when the observer origin doesn't match the
// device's actual fix (the user has panned the map elsewhere), the
// whole cluster is omitted. `state.isAtDeviceLocation` is the single
// source of truth. Drawn last in `CelestialCanva.layers`, so the
// puck sits on top of everything.
struct UserLocationLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        // The user has moved the observer elsewhere → a "you are
        // here" mark would be misleading. Bail.
        guard dc.state.isAtDeviceLocation else { return }

        // Zenith — the projection origin — lives at screen centre
        // shifted by the user's pan offset.
        let sc = dc.toScreen(.zero)

        // Heading cone behind the puck — needs a calibrated compass;
        // no reading, no cone (the puck still draws).
        if let h = ELocationService.shared.heading, h.headingAccuracy >= 0 {
            // Prefer `trueHeading` (geographic north); fall back to
            // magnetic if true is invalid (no fix yet).
            let heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
            artist.drawHeadingCone(at:       sc,
                                   heading:  heading,
                                   accuracy: h.headingAccuracy,
                                   in:       &dc)
        }

        // Globe puck on top — longitude-keyed so it wears the
        // continent the observer actually sits on.
        let symbol = artist.userLocationGlobeSymbol(
            forLongitude: dc.state.origin.longitude.degrees)
        artist.drawSquircleGlobePuck(at: sc, symbol: symbol, in: &dc)
    }
}
