import SwiftUI
import CoreLocation

// MARK: - UserLocationLayer
// Draws the heading cone fan behind the "you are here" puck. The
// puck disc + ring themselves live in a SwiftUI overlay
// (`UserLocationPuck` → `SquircleGlobePuck`) mounted in
// `CelestialCanva` on top of the procedural canvas — see that file
// for the layout.
//
// Visibility gate: when the observer origin doesn't match the
// device's actual fix (the user has panned the map elsewhere), the
// whole "you are here" cluster — cone AND puck — is omitted.
// `state.isAtDeviceLocation` is the single source of truth; the
// SwiftUI overlay reads it too, so the two surfaces stay in sync.
struct UserLocationLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        // No fix, or the user has moved the observer elsewhere →
        // nothing to anchor a heading cone to. Bail before touching
        // CoreLocation.
        guard dc.state.isAtDeviceLocation else { return }

        // Heading cone needs a calibrated compass. No reading, no
        // cone — the puck overlay still renders on its own.
        guard let h = ELocationService.shared.heading,
              h.headingAccuracy >= 0 else { return }

        // Zenith — the projection origin — lives at screen centre
        // shifted by the user's pan offset.
        let sc = dc.toScreen(.zero)

        // Prefer `trueHeading` (referenced to geographic north);
        // fall back to magnetic if true is invalid (no fix yet).
        let heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        artist.drawHeadingCone(at:       sc,
                               heading:  heading,
                               accuracy: h.headingAccuracy,
                               in:       &dc)
    }
}
