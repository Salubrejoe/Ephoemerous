import SwiftUI
import LoreKit

// MARK: - POI label text casing
//
// Apple Maps gives every label two distinct treatments, and the
// distinction is the whole trick: a crisp *casing* (a tight
// outline in a contrasting colour, doing the legibility work
// against a busy background) AND a soft *drop shadow* (offset +
// blurred, doing the depth/lift work). One shadow can't be both —
// a radius big enough to read as a halo is too soft to read as an
// outline. So we draw them separately: a real shadow filter for
// lift, plus a faked stroke for the casing.
//
// SwiftUI's GraphicsContext can't stroke text, so the casing is
// faked the classic way — draw the glyph several times in a ring
// of small offsets (the border), then the fill on top.
extension EArtist {

    /// Soft drop shadow under label *text* — distinct from the
    /// badge's `poiShadow` halo. Subtle and a touch lowered so the
    /// text lifts without smearing; the casing does the legibility,
    /// this does the depth.
    var poiTextShadow: GraphicsContext.Filter {
        .shadow(color: .black.opacity(0.5),
                radius: 2.8, x: 0, y: 0.5)
    }

    /// Master switch for the per-label text + badge drop shadows. OFF:
    /// each is a Gaussian blur filter rendered per on-screen label per
    /// frame — the dominant POI-label cost. The casing alone keeps labels
    /// legible; turn back on only if the lift is worth the frames.
    var poiTextShadowEnabled: Bool { false }

    /// Colour of the crisp casing around label text. `.primary` gives
    /// the punchy light-outline-on-colour look from the Apple Maps
    /// reference; switch to `.systemBackground` if you'd rather the
    /// casing recede into the sky than stand proud of it.
    var poiTextBorderColor: Color { .systemBackground }

    /// Casing half-width, in points. The glyph is redrawn in a ring
    /// this far out, so ~1pt reads as a clean hairline at footnote
    /// size; push toward 1.5 for a chunkier sticker edge.
    // (poiTextBorderWidth moved to EArtist.swift)

    /// Eight offsets (NSEW + diagonals) forming the casing ring. Four
    /// would leave gaps at the corners; past eight costs draws for no
    /// visible gain at label sizes. Diagonals are scaled by cos 45° so
    /// every copy sits the same distance out — a circle, not a square.
    var poiTextBorderOffsets: [CGSize] {
        let d = poiTextBorderWidth
        let s = d * 0.70710678
        return [
            CGSize(width:  d, height:  0), CGSize(width: -d, height:  0),
            CGSize(width:  0, height:  d), CGSize(width:  0, height: -d),
            CGSize(width:  s, height:  s), CGSize(width:  s, height: -s),
            CGSize(width: -s, height:  s), CGSize(width: -s, height: -s)
        ]
    }

    /// Draws label text the Apple-Maps way: a soft drop shadow for
    /// depth, a crisp casing for legibility, then the visible `filled`
    /// shading on top.
    ///
    /// `cased` is the same string styled in the casing colour, passed
    /// in rather than derived so callers that build concatenated Text
    /// (e.g. the constellation ♥ prefix) keep control of styling. Both
    /// `filled` and `cased` should already carry the font.
    ///
    /// `ctx` is taken by value — drawing routes to the shared canvas,
    /// while transform / opacity / filters stay local to each copy, so
    /// the shadow filter never leaks onto the casing or fill.
    func drawCasedLabel(filled: Text,
                        cased:  Text,
                        at point: CGPoint,
                        anchor: UnitPoint,
                        in ctx: GraphicsContext) {
        let serFilled = filled.fontDesign(.serif)
        let serCased  = cased.fontDesign(.serif)

        // 1 — PERF: the soft drop shadow is a per-label Gaussian BLUR
        //     FILTER (offscreen alloc + convolution + composite) — the
        //     most expensive primitive on the canvas, and it ran on every
        //     on-screen label every frame (the POI-label stutter the user
        //     bisected). The 8-copy casing below already carries the
        //     legibility against a busy sky; the shadow was only
        //     lift/depth polish. Disabled by default — flip
        //     `poiTextShadowEnabled` to restore it.
        if poiTextShadowEnabled {
            var shadow = ctx
            shadow.addFilter(poiTextShadow)
            shadow.draw(serCased, at: point, anchor: anchor)
        }

        // 2 — crisp casing: the glyph redrawn in a ring around the
        //     anchor. Resolve once, redraw eight times.
        let resolved = ctx.resolve(serCased)
        for off in poiTextBorderOffsets {
            ctx.draw(resolved,
                     at: CGPoint(x: point.x + off.width,
                                 y: point.y + off.height),
                     anchor: anchor)
        }

        // 3 — visible fill on top.
        ctx.draw(serFilled, at: point, anchor: anchor)
    }
}
