import SwiftUI
import simd
import LoreKit

// MARK: - MeridianLabelsLayer
// Antique-cartography labels curving along the four principal sky
// meridians — the *colures* — exactly the cartographic treatment
// `HorizonLabelsLayer` gives the horizon rim, but riding a line of
// constant right ascension instead of constant altitude.
//
// Each label names the equinox / solstice its meridian passes through
// and is centred on that point:
//   RA  0h, dec  0      — VERNAL EQUINOX   (First Point of Aries)
//   RA  6h, dec +ε      — SUMMER SOLSTICE  (ε = obliquity)
//   RA 12h, dec  0      — AUTUMNAL EQUINOX
//   RA 18h, dec −ε      — WINTER SOLSTICE
//
// The text rides the *same* projected meridian `EarthGridLayer` strokes
// — same `(ra, dec)` → `sidereallyRotated` → `project` pipeline — so each
// word sits on its grid line and tracks pan / zoom / rotation / sidereal
// time for free. Characters step in declination along the meridian and
// each is rotated so its "up" axis points toward the zenith (the
// projection origin), the same readability rule the horizon labels use,
// so the words stay legible at every observer latitude.
//
// Letter sizing matches the horizon labels; the per-character Δdec is
// derived from a *screen-pt* target spacing measured locally on the
// meridian, since a meridian's projected scale varies along its length
// far more than the horizon circle's does.
struct MeridianLabelsLayer: EGridLayer {
    // MARK: Tuning

    /// One colure label: the meridian it rides (`ra`), the declination
    /// its named point sits at (`centreDec`, radians), and the word.
    private struct Colure {
        let ra:        Angle
        let centreDec: Double
        let text:      String
    }

    /// Stored, not computed — `draw` runs every canvas frame, and a
    /// computed table would re-run four `String(localized:)` lookups
    /// per frame. (The layer itself is built once: see the `static let
    /// layers` note in `CelestialCanva`.)
    private let colures: [Colure] = {
        let eps = AstroConstants.obliquity.radians
        return [
            .init(ra: Angle(hours: 0),  centreDec:  0,   text: String(localized: "VERNAL EQUINOX")),
            .init(ra: Angle(hours: 6),  centreDec:  eps, text: String(localized: "SUMMER SOLSTICE")),
            .init(ra: Angle(hours: 12), centreDec:  0,   text: String(localized: "AUTUMNAL EQUINOX")),
            .init(ra: Angle(hours: 18), centreDec: -eps, text: String(localized: "WINTER SOLSTICE")),
        ]
    }()

    // MARK: Scale-aware sizing
    //
    // Same ramps as `HorizonLabelsLayer`: font + spacing both grow with
    // the rendered scale, spacing slower than font, so the kerning-to-
    // glyph ratio widens at small scales — the antique-atlas reading.
    // Quantized to 0.5-pt steps so a continuous pinch doesn't mint a new
    // font variant every frame (see the cache-growth note over there).
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
        // drawn glyph-by-glyph, so this keeps asset resolution off the
        // per-character path (Thread Performance Checker). Grid voice:
        // these ride the grid meridians, so they share its tint.
        let color = dc.resolve(artist.gridColor)
        // Per-frame resolved-glyph cache, shared by all four labels —
        // see HorizonLabelsLayer.
        var glyphs: [Character: GraphicsContext.ResolvedText] = [:]

        for colure in colures {
            drawCurvedLabel(colure.text,
                            ra:        colure.ra,
                            centreDec: colure.centreDec,
                            fontPt:    fontPt,
                            spacingPt: spacingPt,
                            color:     color,
                            glyphs:    &glyphs,
                            in: &dc)
        }
    }

    // MARK: - Per-character placement

    private func drawCurvedLabel(_ text: String,
                                 ra:        Angle,
                                 centreDec: Double,
                                 fontPt:    CGFloat,
                                 spacingPt: CGFloat,
                                 color:     Color,
                                 glyphs:    inout [Character: GraphicsContext.ResolvedText],
                                 in dc: inout EGraphicContext) {
        let chars = Array(text)
        let n     = chars.count
        guard n > 1 else { return }

        // Δdec for the target screen spacing, measured *locally*: project
        // two points a small dec apart at the label's centre and read off
        // the screen-pt-per-radian, then invert to hit `spacingPt`. A
        // meridian's projected scale changes along its length, so unlike
        // the horizon circle we can't assume a fixed radius.
        let probe = 0.5 * .pi / 180.0   // 0.5° in radians
        guard let a = meridianPoint(ra: ra, dec: centreDec - probe, in: dc),
              let b = meridianPoint(ra: ra, dec: centreDec + probe, in: dc)
        else { return }
        let perRad = hypot(b.x - a.x, b.y - a.y) / (2 * probe)
        guard perRad > 0.001 else { return }
        let deltaDec = Double(spacingPt) / perRad

        let halfSpan = deltaDec * Double(n - 1) / 2.0

        // Whole-label viewport cull — the characters all sit within ~half
        // the word's arc length of its centre (the probe midpoint), so if
        // that centre is outside the canvas by more than the span + margin,
        // nothing of the label can be visible. Skips the ~3 projections +
        // glyph draw per character for off-screen colures, which is most of
        // them when zoomed in.
        let halfSpanPt = Double(spacingPt) * Double(n - 1) / 2
        let centre = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        guard CGRect(origin: .zero, size: dc.size)
                  .insetBy(dx: -(halfSpanPt + 40), dy: -(halfSpanPt + 40))
                  .contains(centre)
        else { return }
        // The projection origin is the zenith — re-used as the "inward"
        // target so the word turns its readable side toward the centre of
        // the sky, matching the horizon labels.
        let zenith = dc.toScreen(.zero)

        // ONE flip decision for the whole label, taken at its centre.
        // A meridian runs roughly pole-to-pole, so for the lower half the
        // tangent's "up" faces away from the zenith and the glyphs must be
        // turned 180°. But a 180° turn alone renders the word mirrored
        // (read right-to-left, e.g. VERNAL EQUINOX → XONIUQE LANREV) — the
        // glyph reading axis now points *against* the increasing-dec march
        // of the characters. Reversing the character order cancels that, so
        // the word reads forward either way. Deciding once (not per glyph)
        // also stops a label from breaking mid-string near the flip
        // boundary.
        let flip = meridianLabelFlipped(ra: ra,
                                        centreDec: centreDec,
                                        probe: deltaDec,
                                        zenith: zenith,
                                        in: dc)
        let ordered = flip ? Array(chars.reversed()) : chars

        // Nudge the whole word to one side of the meridian line rather than
        // sitting astride it. The offset is along each glyph's local +Y
        // (perpendicular to the tangent) which — thanks to the flip — always
        // faces the zenith, so the text consistently floats on the same side
        // of the line. Scaled to the font so the gap tracks the glyph size.
        let sideInset = fontPt * 0.9

        for (i, char) in ordered.enumerated() {
            let decHere = centreDec - halfSpan + deltaDec * Double(i)
            let decPrev = decHere - deltaDec
            let decNext = decHere + deltaDec

            guard let pHere = meridianPoint(ra: ra, dec: decHere, in: dc),
                  let pPrev = meridianPoint(ra: ra, dec: decPrev, in: dc),
                  let pNext = meridianPoint(ra: ra, dec: decNext, in: dc)
            else { continue }

            // Tangent along the meridian — central difference between the
            // two declination neighbours — plus the label-wide flip.
            let tangentAngle = atan2(pNext.y - pPrev.y,
                                     pNext.x - pPrev.x)
            let rotation = tangentAngle + (flip ? .pi : 0)

            // Push the anchor off the line along the glyph's up axis
            // (perpendicular to the tangent, zenith-facing after the flip).
            let pos = CGPoint(
                x: pHere.x - CGFloat(sin(rotation)) * sideInset,
                y: pHere.y + CGFloat(cos(rotation)) * sideInset
            )

            // Per-glyph cull — a label can straddle the viewport edge.
            guard pos.x > -24, pos.x < dc.size.width  + 24,
                  pos.y > -24, pos.y < dc.size.height + 24 else { continue }

            // Resolve each distinct character once per frame and draw it
            // through a transformed COPY of the context — `drawLayer`
            // pushes an offscreen transparency layer per call, which at a
            // glyph per call per frame was real allocation churn. See
            // HorizonLabelsLayer for the matching pattern.
            let resolved = glyphs[char] ?? {
                let r = dc.ctx.resolve(
                    Text(String(char))
                        .font(.system(size: fontPt, weight: .light))
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

    /// Whether the label at `(ra, centreDec)` needs the 180° turn: true
    /// when the meridian tangent's local +Y axis points *away* from the
    /// zenith at the label's centre. After rotating by the tangent α,
    /// local +Y is `(-sin α, cos α)`; we flip when `dot(up, inward) < 0`.
    private func meridianLabelFlipped(ra: Angle,
                                      centreDec: Double,
                                      probe: Double,
                                      zenith: CGPoint,
                                      in dc: EGraphicContext) -> Bool {
        guard let pHere = meridianPoint(ra: ra, dec: centreDec, in: dc),
              let pPrev = meridianPoint(ra: ra, dec: centreDec - probe, in: dc),
              let pNext = meridianPoint(ra: ra, dec: centreDec + probe, in: dc)
        else { return false }
        let tangent = atan2(pNext.y - pPrev.y, pNext.x - pPrev.x)
        let upX = -sin(tangent)
        let upY =  cos(tangent)
        let inwardX = zenith.x - pHere.x
        let inwardY = zenith.y - pHere.y
        return upX * inwardX + upY * inwardY < 0
    }

    /// Sidereally-rotated equatorial point at `(ra, dec)` projected to
    /// screen — the same pipeline `EarthGridLayer` strokes its meridians
    /// with, so the text lands exactly on the drawn grid line. `nil` when
    /// the point projects behind the viewer.
    private func meridianPoint(ra: Angle,
                               dec: Double,
                               in dc: EGraphicContext) -> CGPoint? {
        let q = EPrecession
            .equatorialVector(ra: ra, dec: .radians(dec))
            .sidereallyRotated(by: dc.localSiderealOffset)
        guard let p = EProjection.project(q, viewpoint: dc.viewpoint) else { return nil }
        return dc.toScreen(p)
    }
}
