import SwiftUI
import simd
import LoreKit

// MARK: - HorizonLabelsLayer
// Antique-cartography labels curving along the *bumpy* projected
// horizon — the same scalloped squircle that `HorizonLayer` strokes
// as the rim. Samples a constant-altitude great/small circle, projects,
// then applies the same `Squircle.lameRadius` bump that
// `EArtist.bumpedHorizonRim` does, so each character rides the actual
// visible curve rather than the smooth circle underneath.
//
// The viewpoint's `baseVectors` puts `e1` at celestial north and
// `e2` at celestial west, so on the horizon parameter:
//   t = 0    — celestial north
//   t = 0.25 — celestial west
//   t = 0.5  — celestial south
//   t = 0.75 — celestial east
//
// Two families of label ride this:
//
//   • The cardinal pair — EASTERN / WESTERN HORIZON — pinned to due
//     east / west on the alt = 0 rim.
//   • The sun's dawn / dusk roster — SUNRISE · CIVIL · NAUTICAL ·
//     ASTRONOMICAL on the east, the mirror set on the west — placed
//     where the sun *actually* crosses each twilight band on the
//     observation date. Each word sits on the very ring `HorizonLayer`
//     strokes for that altitude (`.horizon` / `.civil` / `.naval` /
//     `.astronomical`), at the sun's rise / set azimuth for the day.
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

    /// Inset from the curve toward the zenith, in pt. Pulls each
    /// character into the sky region so the text reads as floating
    /// inside the band, not riding on the bumps themselves.
    private let inwardInsetPt: CGFloat = 7

    /// Horizon-parameter `t` for the cardinal labels.
    private let eastT: Double = 0.75
    private let westT: Double = 0.25

    /// Cardinal words, localised once at init — `draw` runs every canvas
    /// frame and a `String(localized:)` table lookup per label per frame
    /// is pure waste.
    private let easternWord = String(localized: "EASTERN HORIZON")
    private let westernWord = String(localized: "WESTERN HORIZON")

    // MARK: Dawn / dusk roster
    //
    // Each band names a sun altitude — the same values `Angle.sunsets`
    // feeds `HorizonLayer`'s twilight rings — paired with the word that
    // rides it on the rising (east) and setting (west) side. Ordered
    // horizon-outward so it reads SUNRISE → ASTRONOMICAL down the sky,
    // though draw order is immaterial: each word lives on its own ring.
    private struct TwilightBand {
        let altitude: Angle
        let rising:   String   // dawn / eastern word
        let setting:  String   // dusk / western word
    }
    // Words are localised here, where they're still literals, so the
    // String Catalog extractor picks them up (a variable handed to
    // `String(localized:)` at the draw site would not be extracted).
    private let twilightBands: [TwilightBand] = [
        .init(altitude: .horizon,
              rising:  String(localized: "SUNRISE"),
              setting: String(localized: "SUNSET")),
        .init(altitude: .civil,
              rising:  String(localized: "CIVIL"),
              setting: String(localized: "CIVIL")),
        .init(altitude: .naval,
              rising:  String(localized: "NAUTICAL"),
              setting: String(localized: "NAUTICAL")),
        .init(altitude: .astronomical,
              rising:  String(localized: "ASTRONOMICAL"),
              setting: String(localized: "ASTRONOMICAL")),
    ]

    // MARK: Scale-aware sizing
    //
    // `scale` typically lives in [25, 500], default ~215. Font is a
    // clamped linear ramp; the per-character Δt is derived per band from
    // a *screen-pt* target spacing that grows slightly slower than the
    // font. That widens the kerning-to-font ratio at small scales —
    // letters get more breathing room precisely when they shrink.
    // Both ramps are quantized to 0.5-pt steps. During a pinch the scale
    // varies continuously, and an unquantized font size mints a NEW font
    // variant every frame — CoreText / SwiftUI cache glyph layouts per
    // (glyph, size), so a long zoom grows those caches without bound →
    // memory pressure → multi-second main-thread stall. Half-point steps
    // are imperceptible and bound the variants to ~a dozen.
    private func fontPt(scale: Double) -> CGFloat {
        let raw = max(7.5, min(13.0, 5.5 + scale * 0.025))
        return CGFloat((raw * 2).rounded() / 2)
    }
    private func spacingPt(scale: Double) -> CGFloat {
        let raw = max(6.0, min(11.0, 4.5 + scale * 0.020))
        return CGFloat((raw * 2).rounded() / 2)
    }

    func draw(in dc: inout EGraphicContext) {
        let fontPt    = fontPt(scale: dc.renderedScale)
        let spacingPt = spacingPt(scale: dc.renderedScale)
        // Resolve the label colour to concrete RGBA once — each label is
        // drawn glyph-by-glyph (~90 chars/frame), so this keeps the asset
        // resolution off the per-character path.
        let color = dc.resolve(artist.horizonFillColor)
        // Per-frame resolved-glyph cache: every label this frame shares one
        // (font, colour) style, and the words reuse a small alphabet — so
        // each distinct character is laid out ONCE per frame instead of
        // once per occurrence (~90 → ~20 Text resolutions).
        var glyphs: [Character: GraphicsContext.ResolvedText] = [:]

        // Cardinal rim labels.
        drawCurvedLabel(easternWord,
                        centreT:   eastT,
                        altitude:  .horizon,
                        fontPt:    fontPt,
                        spacingPt: spacingPt,
                        color:     color,
                        glyphs:    &glyphs,
                        in: &dc)
        drawCurvedLabel(westernWord,
                        centreT:   westT,
                        altitude:  .horizon,
                        fontPt:    fontPt,
                        spacingPt: spacingPt,
                        color:     color,
                        glyphs:    &glyphs,
                        in: &dc)

        // Sun dawn / dusk labels — positioned from the observation date.
        let phi = dc.state.origin.latitude.radians
        let dec = sunDeclination(on: dc.renderedObservationDate)
        for band in twilightBands {
            // Where the sun reaches this altitude on the rising side; the
            // setting side mirrors across due south. `nil` ⇒ the sun
            // never crosses this band today (polar day / night) — skip it.
            guard let riseAz = sunRiseAzimuth(altitude: band.altitude.radians,
                                              dec: dec,
                                              lat: phi)
            else { continue }

            drawCurvedLabel(band.rising,
                            centreT:   azimuthToT(riseAz),
                            altitude:  band.altitude,
                            fontPt:    fontPt,
                            spacingPt: spacingPt,
                            color:     color,
                            glyphs:    &glyphs,
                            in: &dc)
            drawCurvedLabel(band.setting,
                            centreT:   azimuthToT(2 * .pi - riseAz),
                            altitude:  band.altitude,
                            fontPt:    fontPt,
                            spacingPt: spacingPt,
                            color:     color,
                            glyphs:    &glyphs,
                            in: &dc)
        }
    }

    // MARK: - Sun geometry

    /// The sun's declination (radians) on `date`, via the same
    /// Meeus-low-precision series the sun layer rides (cached).
    private func sunDeclination(on date: Date) -> Double {
        let lambda = ESunPosition.eclipticLongitude(for: date)
        return ESunPosition.equatorialCoords(lambda: lambda).dec.radians
    }

    /// Azimuth (radians, clockwise from north) at which the sun reaches
    /// `altitude` on the *rising* — eastern — side, for the sun's
    /// declination `dec` and observer latitude `lat`. The setting side
    /// is the mirror `2π − A`.
    ///
    /// Returns `nil` when the sun never crosses that altitude on the day
    /// (polar day keeps the deep-twilight bands forever sunlit; polar
    /// night keeps them forever dark) — the caller drops the label.
    private func sunRiseAzimuth(altitude h: Double,
                                dec: Double,
                                lat phi: Double) -> Double? {
        // Crossing test — the hour angle solving alt = h must exist:
        //   cos H = (sin h − sin φ·sin δ) / (cos φ·cos δ)
        let cosH = (sin(h) - sin(phi) * sin(dec))
                 / (cos(phi) * cos(dec))
        guard cosH >= -1, cosH <= 1 else { return nil }

        // Azimuth from north:
        //   cos A = (sin δ − sin φ·sin h) / (cos φ·cos h)
        // A ∈ [0, π] is the eastern (rising) azimuth directly.
        let cosA = (sin(dec) - sin(phi) * sin(h))
                 / (cos(phi) * cos(h))
        return acos(max(-1, min(1, cosA)))
    }

    /// Horizon parameter `t` for an azimuth (radians, clockwise from
    /// north). From `skyPoint`'s basis — `e1` north, `e2` west, azimuth
    /// running north→east — the two parametrisations satisfy
    /// `t·2π = −azimuth`; wrap the result into `0..<1`.
    private func azimuthToT(_ azimuth: Double) -> Double {
        let t = -azimuth / (2 * .pi)
        return t - floor(t)
    }

    // MARK: - Per-character placement

    private func drawCurvedLabel(_ text: String,
                                 centreT:   Double,
                                 altitude:  Angle,
                                 fontPt:    CGFloat,
                                 spacingPt: CGFloat,
                                 color:     Color,
                                 glyphs:    inout [Character: GraphicsContext.ResolvedText],
                                 in dc: inout EGraphicContext) {
        let chars = Array(text)
        let n     = chars.count
        guard n > 1 else { return }

        // Δt for the target screen spacing on *this* band. 1 unit of `t`
        // = 2π rad on the sky; the projected constant-altitude circle has
        // radius `ρ·scale` screen-pt, so a Δt arc step is 2π·ρ·scale·Δt
        // long. Invert to hit `spacingPt`. (ρ = 2 on the horizon, larger
        // on the below-horizon twilight bands — they need a smaller Δt to
        // keep the same kerning.)
        let rho    = projectionRadius(altitude: altitude)
        let deltaT = Double(spacingPt) / (2.0 * .pi * rho * dc.renderedScale)

        let halfSpan = deltaT * Double(n - 1) / 2.0

        // Whole-label viewport cull. Zoomed in, the rim (and its words) is
        // usually far off-screen — skip the ~3 projections + glyph draw per
        // character before doing any of it. The label's characters all sit
        // within ~half the word's arc length of its centre, so testing the
        // centre against the canvas rect expanded by that span is exact
        // enough, with a small safety margin.
        let halfSpanPt = Double(spacingPt) * Double(n - 1) / 2
        guard let centre = bumpedPoint(at: centreT, altitude: altitude, in: dc),
              CGRect(origin: .zero, size: dc.size)
                  .insetBy(dx: -(halfSpanPt + 40), dy: -(halfSpanPt + 40))
                  .contains(centre)
        else { return }

        // The stereographic image of a constant-altitude circle is
        // centred on the projection origin, i.e. the zenith. We re-use it
        // both as the "inward" target for character rotation and as the
        // bump centroid (instead of averaging hundreds of samples per
        // frame the way HorizonLayer does).
        let zenith = dc.toScreen(.zero)

        for (i, char) in chars.enumerated() {
            let tHere = centreT - halfSpan + deltaT * Double(i)
            let tPrev = tHere - deltaT
            let tNext = tHere + deltaT

            // Bumped band points at each parameter — same squircle
            // treatment HorizonLayer applies to its rings.
            guard let pHere = bumpedPoint(at: tHere, altitude: altitude, in: dc),
                  let pPrev = bumpedPoint(at: tPrev, altitude: altitude, in: dc),
                  let pNext = bumpedPoint(at: tNext, altitude: altitude, in: dc)
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
            // floats in the sky just off the bumpy ring.
            let pos = CGPoint(
                x: pHere.x + CGFloat(inwardX) / CGFloat(inwardLen) * inwardInsetPt,
                y: pHere.y + CGFloat(inwardY) / CGFloat(inwardLen) * inwardInsetPt
            )

            // Per-glyph cull — a label can straddle the viewport edge.
            guard pos.x > -24, pos.x < dc.size.width  + 24,
                  pos.y > -24, pos.y < dc.size.height + 24 else { continue }

            // Resolve each distinct character once per frame (shared via
            // `glyphs` across every label this layer draws), then draw it
            // through a transformed COPY of the context. A copy is a cheap
            // value — unlike `drawLayer`, which pushes a full offscreen
            // transparency layer per call (~90/frame at 120 fps was real
            // allocation churn).
            let resolved = glyphs[char] ?? {
                let r = dc.ctx.resolve(
                    Text(String(char))
                        .font(.system(size: fontPt, weight: .semibold))
                        .foregroundStyle(color)
                )
                glyphs[char] = r
                return r
            }()
            var g = dc.ctx
            g.translateBy(x: pos.x, y: pos.y)
            g.rotate(by: .radians(rotation))
            g.draw(resolved, at: .zero, anchor: .center)
        }
    }

    /// Stereographic screen radius (projection units) of the
    /// constant-`altitude` circle. The observer-centred projection maps
    /// altitude → radius as `ρ = 2·cos a / (1 + sin a)`: 2 on the
    /// horizon, growing as the band drops below it.
    private func projectionRadius(altitude: Angle) -> Double {
        let a = altitude.radians
        return 2.0 * cos(a) / (1.0 + sin(a))
    }

    /// Project the sky point at parameter `t` on the constant-`altitude`
    /// circle, apply the same `Squircle.lameRadius` bump
    /// `EArtist.bumpedHorizonRim` uses, then map to screen.
    ///
    /// Crucially the bump is applied in **projection space, before
    /// `toScreen`** — exactly the order the rings use. `toScreen` then
    /// rotates the already-bumped point by `canvasRotation`, so the
    /// scallop phase stays locked to the *sky* frame and matches the
    /// rings' bumps at any rotation. (The previous version bumped in
    /// screen space, *after* `toScreen`, which pinned the phase to the
    /// screen — fine at 0° but drifting out of sync the moment the
    /// canvas was rotated, since the rings' bumps spun with the sky and
    /// the labels' didn't.)
    ///
    /// Centroid of every constant-altitude circle ≈ the projection
    /// origin, so the radial angle is taken straight from `.zero` — the
    /// projection-space equivalent of the mean centroid the rings
    /// compute.
    private func bumpedPoint(at t: Double,
                             altitude: Angle,
                             in dc: EGraphicContext) -> CGPoint? {
        let sky = dc.viewpoint.skyPoint(altitude: altitude, at: t)
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
