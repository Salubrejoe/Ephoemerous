import SwiftUI
import CoreLocation

// MARK: - UserLocationLayer
// Draws the "you are here" puck on top of the celestial canvas.
// The puck sits at the projection's zenith — the centre of the
// observer's local sky, which on screen is the canvas centre
// modulated by `renderedOffset`. The heading cone (when the
// compass is calibrated) fans out in the direction the device
// is pointing, with its half-angle following CoreLocation's
// reported `headingAccuracy`.
//
// All styling lives on `EArtist+UserLocation.swift`. This layer
// is just data routing.
struct UserLocationLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        // Zenith — the projection origin — lives at screen centre
        // shifted by the user's pan offset.
        let sc = dc.toScreen(.zero)

        // Heading cone first so the disc sits on top of its apex.
        if let h = ELocationService.shared.heading,
           h.headingAccuracy >= 0 {
            // Prefer `trueHeading` (referenced to geographic
            // north); fall back to magnetic if true is invalid
            // (no location fix yet).
            let heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
            artist.drawHeadingCone(at:       sc,
                                   heading:  heading,
                                   accuracy: h.headingAccuracy,
                                   in:       &dc)
        }

        artist.drawUserLocationPuck(at: sc, in: &dc)
    }
}
