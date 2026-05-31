import SwiftUI
import simd
import CoreLocation
import LoreKit

// MARK: - SkyAimWashLayer
// "The aim drives the sky." A broad blue radial wash centred on where the
// phone is pointed, CLIPPED to the horizon dome so it reads as the night
// sky's own blue lifting toward your aim — not a disc floating on top.
//
// Drawn EARLY (right after the grid, before the star catalog) so the wash
// sits behind every star, planet and label: it tints the background, it
// doesn't fog the foreground. Reuses the exact aim pipeline as the
// user-location puck — `EMotionService.aim` → `aimDisplayAltitude` /
// `aimFadeOpacity` → `screenPoint` — so the wash and the puck always
// agree on where "pointed" is.
//
// Gated on `isAtDeviceLocation` (aim is meaningless after a pan) and on
// a live `EMotionService.aim` (no gyro in the Simulator → no wash). The
// gate short-circuits before reading `aim`, so a panned-away canvas takes
// no motion dependency and stays idle.
struct SkyAimWashLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        guard dc.state.isAtDeviceLocation,
              let aim = EMotionService.shared.aim
        else { return }

        let altitude = artist.aimDisplayAltitude(deviceAltitudeRadians: aim.altitude)
        let fade     = artist.aimFadeOpacity(displayAltitudeRadians: altitude)
        guard fade > 0.01,
              let p = dc.screenPoint(azimuth: aim.azimuth, altitude: altitude)
        else { return }

        // The horizon dome, screen-space, with the same scallop bump
        // HorizonLayer strokes — so the wash stops exactly at the visible
        // rim. Bail if the projection didn't yield a usable ring.
        guard let dome = horizonDomePath(in: dc) else { return }

        let skyDisc  = CGFloat(2 * dc.renderedScale)
        let accuracy = ELocationService.shared.heading.map { max(0, $0.headingAccuracy) } ?? 0
        let radius   = artist.aimBlobRadius(skyDiscRadius: skyDisc,
                                            accuracyDegrees: accuracy)

        artist.drawAimBlob(at:       p,
                           radius:   radius,
                           opacity:  fade,
                           color:    artist.skyAimColor,
                           clipDome: dome,
                           in:       &dc)
    }

    /// Screen-space path of the bumped horizon rim (alt = 0), matching
    /// `HorizonLayer`'s scalloped silhouette so the wash clips to the same
    /// edge the user sees. `nil` if too few projection samples survive
    /// (e.g. mid-transition degenerate viewpoint).
    private func horizonDomePath(in dc: EGraphicContext) -> Path? {
        let pts = EProjection.sampleCurve(viewpoint: dc.viewpoint) { t in
            dc.viewpoint.skyPoint(altitude: .horizon, at: t)
        }.compactMap { $0 }
        guard pts.count >= 8 else { return nil }

        let screen = artist.bumpedHorizonRim(pts).compactMap { $0 }.map { dc.toScreen($0) }
        guard screen.count >= 8 else { return nil }

        var path = Path()
        path.move(to: screen[0])
        for q in screen.dropFirst() { path.addLine(to: q) }
        path.closeSubpath()
        return path
    }
}
