import SwiftUI
import simd
import LoreKit

// MARK: - HorizonLabelsLayer
// Antique-cartography labels curving along the *bumpy* projected
// horizon — the same scalloped squircle that `HorizonLayer` strokes
// as the rim. Samples the alt = 0 great circle, projects, then
// applies the same `Squircle.lameRadius` bump that
// `EArtist.bumpedHorizonRim` does, so each character rides the
// actual visible curve rather than the smooth circle underneath.
//
// The viewpoint's `baseVectors` puts `e1` at celestial north and
// `e2` at celestial west, so on the horizon parameter:
//   t = 0    — celestial north
//   t = 0.25 — celestial west
//   t = 0.5  — celestial south
//   t = 0.75 — celestial east
//
// Each character is rotated so its "up" axis points toward the
// zenith (the projection origin, screen-space `dc.toScreen(.zero)`).
// That handles every observer latitude in one go and means the
// labels stay readable as the user pans the sky.
//
// Letter sizing + spacing are scale-aware. Both grow with the
// rendered scale, but **spacing grows slower than font**, so the
// kerning-to-glyph ratio is wider at small scales — letters get
// "more room while getting smaller", which is the antique-atlas
// reading the user asked for.
//
// No appMode gate: this rides the same projected horizon the user
// always sees.
struct HorizonLabelsLayer: EGridLayer {
    // MARK: Tuning

    /// Inset from the horizon toward the zenith, in pt. Pulls each
    /// character into the sky region so the text reads as floating
    /// inside the horizon, not riding on the bumps themselves.
    private let inwardInsetPt: CGFloat = 7

    /// Horizon-parameter `t` for each cardinal direction.
    private let eastT: Double = 0.75
    private let westT: Double = 0.25

    // MARK: Scale-aware sizing
    //
    // `scale` typically lives in [25, 500], default ~215. Font is a
    // clamped linear ramp; per-character Δt is derived from a
    // *screen-pt* target spacing that grows slightly slower than the
    // font. That widens the kerning-to-font ratio at small scales —
    // letters get more breathing room precisely when they shrink.
    private func tuning(scale: Double) -> (fontPt: CGFloat, deltaT: Double) {
        let fontPt    = max(7.5, min(13.0, 5.5 + scale * 0.025))
        let spacingPt = max(6.0, min(11.0, 4.5 + scale * 0.020))
        // 1 unit of `t` = 2π rad on the sky; the projected horizon
        // is a circle of radius ≈ 2·scale, so a Δt arc step is
        // 4π·scale·Δt screen-pt long. Invert to hit the target.
        let deltaT    = spacingPt / (4.0 * .pi * scale)
        return (CGFloat(fontPt), deltaT)
    }

    func draw(in dc: inout EGraphicContext) {
        let (fontPt, deltaT) = tuning(scale: dc.renderedScale)
        drawCurvedLabel("EASTERN HORIZON",
                        centreT: eastT,
                        fontPt:  fontPt,
                        deltaT:  deltaT,
                        in: &dc)
        drawCurvedLabel("WESTERN HORIZON",
                        centreT: westT,
                        fontPt:  fontPt,
                        deltaT:  deltaT,
                        in: &dc)
    }

    // MARK: - Per-character placement

    private func drawCurvedLabel(_ text: String,
                                 centreT: Double,
                                 fontPt: CGFloat,
                                 deltaT: Double,
                                 in dc: inout EGraphicContext) {
        let chars = Array(text)
        let n     = chars.count
        guard n > 1 else { return }

        let halfSpan = deltaT * Double(n - 1) / 2.0
        // The stereographic image of the alt = 0 great circle is
        // centred on the projection origin, i.e. the zenith. We
        // re-use it both as the "inward" target for character
        // rotation and as the bump centroid (instead of averaging
        // hundreds of samples per frame the way HorizonLayer does).
        let zenith = dc.toScreen(.zero)

        for (i, char) in chars.enumerated() {
            let tHere = centreT - halfSpan + deltaT * Double(i)
            let tPrev = tHere - deltaT
            let tNext = tHere + deltaT

            // Bumped horizon points at each parameter — same
            // squircle treatment HorizonLayer applies to its rim.
            guard let pHere = bumpedHorizonPoint(at: tHere, in: dc),
                  let pPrev = bumpedHorizonPoint(at: tPrev, in: dc),
                  let pNext = bumpedHorizonPoint(at: tNext, in: dc)
            else { continue }

            // Tangent direction along the bumpy curve at this t —
            // central-difference between the two neighbours.
            let tangentAngle = atan2(pNext.y - pPrev.y,
                                     pNext.x - pPrev.x)

            // Direction from the character's anchor to the zenith.
            let inwardX = zenith.x - pHere.x
            let inwardY = zenith.y - pHere.y
            let inwardLen = sqrt(inwardX * inwardX + inwardY * inwardY)
            guard inwardLen > 0.01 else { continue }

            // Rotation: start at the tangent, then flip 180° if the
            // resulting local +Y axis points outward instead of
            // inward. After rotating by α, local +Y is
            // `(-sin α, cos α)`; we want dot(up, inward) ≥ 0.
            var rotation = tangentAngle
            let upX = -sin(rotation)
            let upY =  cos(rotation)
            if upX * inwardX + upY * inwardY < 0 {
                rotation += .pi
            }

            // Push the anchor inward toward the zenith so the glyph
            // floats in the sky just off the bumpy rim.
            let pos = CGPoint(
                x: pHere.x + CGFloat(inwardX) / CGFloat(inwardLen) * inwardInsetPt,
                y: pHere.y + CGFloat(inwardY) / CGFloat(inwardLen) * inwardInsetPt
            )

            dc.ctx.drawLayer { layer in
                layer.translateBy(x: pos.x, y: pos.y)
                layer.rotate(by: .radians(rotation))
                layer.draw(
                    Text(String(char))
                        .font(.system(size: fontPt, weight: .semibold))
                        .foregroundStyle(artist.horizonFillColor)
                        .kerning(0.4),
                    at:     .zero,
                    anchor: .center
                )
            }
        }
    }

    /// Project the horizon point at parameter `t`, apply the same
    /// `Squircle.lameRadius` bump `EArtist.bumpedHorizonRim` uses, then
    /// map to screen.
    ///
    /// Crucially the bump is applied in **projection space, before
    /// `toScreen`** — exactly the order the rim uses. `toScreen` then
    /// rotates the already-bumped point by `canvasRotation`, so the
    /// scallop phase stays locked to the *sky* frame and matches the
    /// rim's bumps at any rotation. (The previous version bumped in
    /// screen space, *after* `toScreen`, which pinned the phase to the
    /// screen — fine at 0° but drifting out of sync the moment the
    /// canvas was rotated, since the rim's bumps spun with the sky and
    /// the labels' didn't.)
    ///
    /// Centroid of the alt = 0 circle ≈ the projection origin, so the
    /// radial angle is taken straight from `.zero` — the projection-
    /// space equivalent of the mean centroid the rim computes.
    private func bumpedHorizonPoint(at t: Double,
                                    in dc: EGraphicContext) -> CGPoint? {
        let sky = dc.viewpoint.skyPoint(altitude: .horizon, at: t)
        guard let proj = EProjection.project(sky, viewpoint: dc.viewpoint)
        else { return nil }
        let θ = atan2(proj.y, proj.x)
        let k = Squircle.lameRadius(
            angle:   θ,
            corners: CGFloat(artist.horizonBumpCorners),
            bulge:   artist.horizonBumpBulge
        )
        return dc.toScreen(CGPoint(x: proj.x * k, y: proj.y * k))
    }
}
