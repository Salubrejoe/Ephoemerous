

import SwiftUI
import simd
import LoreKit
import CoreLocation


struct EarthGridLayer: EGridLayer {

    func draw(in dc: inout EGraphicContext) {
        // Resolve the grid colour to concrete RGBA once for the whole
        // frame — drawn ~24× (meridians + parallels), so without this each
        // stroke would re-resolve the "grid" asset on the main thread.
        let gridColor = dc.resolve(artist.gridColor)

        // Project every grid curve ONCE, then reuse for both the base pass
        // and the cone-highlight pass below — the highlight re-strokes the
        // exact same curves (recoloured, clipped), so they register
        // perfectly and the projection trig isn't run twice.
        let meridians = meridianCurves(in: dc)
        let parallels = parallelCurves(in: dc)

        // Base graticule.
        for pts in meridians { stroke(pts, color: gridColor, width: artist.gridWidth, in: dc) }
        for pts in parallels { stroke(pts, color: gridColor, width: artist.gridWidth, in: dc) }

        // The aim "cone", expressed as the graticule lighting up: clip to
        // the device-aim wedge and redraw the SAME curves in the cone tint,
        // a touch thicker. No fill, no glow — the grid itself colours in,
        // with a crisp clipped edge that matches the app's cartographic feel.
        drawAimConeHighlight(meridians: meridians, parallels: parallels, in: &dc)

        drawPoleLabels(in:  &dc)
        drawHourLabels(in:  &dc)
    }

    // MARK: - Aim-cone highlight

    private func drawAimConeHighlight(meridians: [[CGPoint?]],
                                      parallels: [[CGPoint?]],
                                      in dc: inout EGraphicContext) {
        // Same gate as the puck: only from the user's real location, and
        // only with a live device-motion aim. The location check comes
        // FIRST so a panned-away canvas never takes a motion dependency.
        guard dc.state.isAtDeviceLocation,
              let aim = EMotionService.shared.aim else { return }

        let sc       = dc.toScreen(.zero)            // zenith / puck
        let compass  = ELocationService.shared.heading
        let accuracy = (compass?.headingAccuracy ?? -1) >= 0
            ? compass!.headingAccuracy
            : artist.userPuckConeMinHalfAngle

        guard let wedge = artist.aimConeWedge(at: sc,
                                              azimuth:  aim.azimuth,
                                              altitude: aim.altitude,
                                              accuracy: accuracy,
                                              in: dc)
        else { return }

        let hiColor = dc.resolve(artist.aimConeGridColor)
        let feather = artist.aimConeFeather
        let width   = artist.aimConeGridWidth

        // Draw the highlight into its own layer, then crop it to the wedge
        // with a SOFT mask: a blurred fill composited `.destinationIn`, so
        // the coloured grid fades out over `feather` points at every edge
        // instead of hard-stopping at a clip. Same lines as the base grid,
        // just recoloured + feathered.
        dc.ctx.drawLayer { layer in
            var sub = dc
            sub.ctx = layer
            for pts in meridians { stroke(pts, color: hiColor, width: width, in: sub) }
            for pts in parallels { stroke(pts, color: hiColor, width: width, in: sub) }

            var mask = layer
            mask.blendMode = .destinationIn
            mask.addFilter(.blur(radius: feather))
            mask.fill(wedge.path, with: .color(.white))
        }
    }

    /// Stroke one projected curve on a throwaway copy of the context so the
    /// caller's context (and any clip it carries) is left untouched.
    private func stroke(_ pts: [CGPoint?], color: Color, width: CGFloat,
                        in dc: EGraphicContext) {
        var local = dc
        local.strokeCurve(pts, color: color, width: width)
    }

    // MARK: - Curve generation

    /// Parallels of constant declination, sidereally rotated, sampled into
    /// screen-space polylines.
    private func parallelCurves(in dc: EGraphicContext) -> [[CGPoint?]] {
        Angle.parallels.map { decl in
            EProjection.sampleCurve(viewpoint: dc.viewpoint) { t in
                EPrecession.equatorialVector(ra: .radians(t * .twoPi), dec: decl)
                    .sidereallyRotated(by: dc.localSiderealOffset)
            }
        }
    }

    /// Meridians (RA hour lines, every hour) sampled into screen-space
    /// polylines.
    private func meridianCurves(in dc: EGraphicContext) -> [[CGPoint?]] {
        stride(from: 0.0, to: 12.0, by: 1.0).map { h in
            let ra = h / 24.0 * Double.twoPi
            return EProjection.sampleCurve(viewpoint: dc.viewpoint) { t in
                EPrecession.equatorialVector(ra: .radians(ra),
                                             dec: .radians((t - 0.5) * 2 * Double.pi))
                    .sidereallyRotated(by: dc.localSiderealOffset)
            }
        }
    }

    // MARK: - Celestial-pole labels (N / S)
    //
    // The meridian fan converges at dec = ±89.99°; "N" / "S" pin to those
    // convergence points. The poles are invariant under sidereal rotation
    // about z, so the rotation is a no-op for them — we apply it anyway
    // for symmetry with the rest of the grid math. In clock mode (observer
    // at NP) the celestial north pole projects to the chrome centre, so
    // "N" lands dead-centre; the south pole still projects to a finite
    // (often off-canvas) point and is culled by `onScreen`.
    func drawPoleLabels(in dc: inout EGraphicContext) {
        let poles: [(dec: Angle, text: String)] = [
            (.degrees( 89.99), "N"),
            (.degrees(-89.99), "S"),
        ]
        for (dec, text) in poles {
            guard let sc = projectedScreenPoint(ra: .zero, dec: dec, in: dc),
                  dc.onScreen(sc, margin: 12)
            else { continue }
            artist.drawGridLabel(text, at: sc, weight: .semibold, in: &dc)
        }
    }

    // MARK: - RA hour numerals (0h / 6h / 12h / 18h)
    //
    // Dropped onto the celestial equator (dec = 0) so they ride the
    // dec=0 parallel as the sky rotates sidereally. Only the four
    // principal hours to keep the grid uncluttered. Any hour whose
    // projection lands off-canvas is culled.
    func drawHourLabels(in dc: inout EGraphicContext) {
        for h in [0.0, 6.0, 12.0, 18.0] {
            let ra = Angle.radians(h / 24.0 * Double.twoPi)
            guard let sc = projectedScreenPoint(ra: ra, dec: .zero, in: dc),
                  dc.onScreen(sc, margin: 12)
            else { continue }
            artist.drawGridLabel("\(Int(h))h", at: sc, in: &dc)
        }
    }

    /// Sidereally-rotated equatorial → screen projection. Shared
    /// by both label loops — they only differ in (ra, dec) tuples.
    private func projectedScreenPoint(ra:  Angle,
                                      dec: Angle,
                                      in dc: EGraphicContext) -> CGPoint? {
        let q = EPrecession
            .equatorialVector(ra: ra, dec: dec)
            .sidereallyRotated(by: dc.localSiderealOffset)
        guard let p = EProjection.project(q, viewpoint: dc.viewpoint) else { return nil }
        return dc.toScreen(p)
    }
}
