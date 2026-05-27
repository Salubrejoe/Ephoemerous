import SwiftUI
import LoreKit

// MARK: - POI label previews
// Visual sandbox for iterating on `drawPOILabel(…)`. Each card draws
// one POI category via the same Canvas → `drawPOILabel` pipeline the
// real layers use, so palette / corners / sizing / shadow changes
// surface here exactly as they would on the celestial canvas.
//
// Categories covered:
//   • .sun                                — `Sun`
//   • .moon                               — `Moon` (first-quarter glyph)
//   • .planet(.mars)                      — `Mars`
//   • .followedStar(betelgeusePreviewStar) — `Betelgeuse` (M class red)
//   • .constellation(.circumpolar, dec:75) — `Ursa Minor`

/// A single POI label rendered inside a Canvas at a fixed
/// `renderedScale` high enough to land at tier 2 (badge + text).
/// Tweaking the scale here lets you preview tier transitions
/// (drop below `textIn` for tier 1, drop below `badgeIn` for tier 0
/// = dot).
private struct POILabelPreviewCard: View {

    let title:    String
    let glyph:    POIGlyph
    let text:     String
    let category: POICategory
    var scale:    Double = 150

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Canvas { ctx, size in
                var dc = previewGraphicsContext(ctx: ctx, size: size, scale: scale)
                EArtist.shared.drawPOILabel(
                    at:       CGPoint(x: 30, y: size.height / 2),
                    glyph:    glyph,
                    text:     text,
                    category: category,
                    drawDot:  true,
                    in:       &dc
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .padding(.vertical, 4)
    }
}

/// EGraphicContext stub for previews. `drawPOILabel` reads only
/// `renderedScale` + `size` + `ctx` so the rest can be any sensible
/// default — the projection viewpoint is never consulted at the
/// badge level.
private func previewGraphicsContext(
    ctx:   GraphicsContext,
    size:  CGSize,
    scale: Double
) -> EGraphicContext {
    EGraphicContext(
        ctx:                     ctx,
        size:                    size,
        state:                   EAppState(),
        renderedScale:           scale,
        renderedOffset:          .zero,
        renderedObservationDate: .now,
        localSiderealOffset:     .zero,
        animationTime:           0,
        viewpoint:               EProjection.Viewpoint(
                                    originVector: .north,
                                    planeVector:  .south)
    )
}

/// Hand-built EStar so the followed-star preview doesn't need
/// `StarDatabase` loaded. Coordinates are Betelgeuse's actual
/// position; spectralClass = M drives the deep-red badge gradient.
private let betelgeusePreviewStar: EStar = EStar(
    from: StarData(
        name:                  "Alp Ori",
        rightAscensionHours:   "5",  rightAscensionMinutes: "55", rightAscensionSeconds: "10",
        declinationSign:       "+",  declinationDegrees:    "7",  declinationMinutes:    "24", declinationSeconds: "25",
        magnitude:             "0.42",
        spectralClass:         "M",
        pmRA:                  "-3.2", pmDE: "2.3"
    )
)

#Preview("POI labels (tier 2)") {
    VStack(spacing: 0) {
        POILabelPreviewCard(
            title:    "Sun",
            glyph:    .sfSymbol("sun.max.fill"),
            text:     "Sun",
            category: .sun
        )
        Divider()
        POILabelPreviewCard(
            title:    "Moon",
            glyph:    .sfSymbol("moonphase.first.quarter"),
            text:     "Moon",
            category: .moon
        )
        Divider()
        POILabelPreviewCard(
            title:    "Mars",
            glyph:    .unicode("♂"),
            text:     "Mars",
            category: .planet(.mars)
        )
        Divider()
        POILabelPreviewCard(
            title:    "Betelgeuse",
            glyph:    .sfSymbol("star.fill"),
            text:     "Betelgeuse",
            category: .followedStar(betelgeusePreviewStar)
        )
        Divider()
        POILabelPreviewCard(
            title:    "Ursa Minor",
            glyph:    .sfSymbol("sparkles"),
            text:     "Ursa Minor",
            category: .constellation(.entity(.zeus))
        )
    }
    .padding()
    .background(EArtist.shared.canvasBackground)
}

#Preview("POI labels (tier 1 — badge only)") {
    VStack(spacing: 0) {
        POILabelPreviewCard(
            title:    "Sun",
            glyph:    .sfSymbol("sun.max.fill"),
            text:     "Sun",
            category: .sun,
            scale:    50    // < textIn (80) — badge only
        )
        Divider()
        POILabelPreviewCard(
            title:    "Mars",
            glyph:    .unicode("♂"),
            text:     "Mars",
            category: .planet(.mars),
            scale:    80    // ≥ badgeIn (60), < textIn (100)
        )
        Divider()
        POILabelPreviewCard(
            title:    "Betelgeuse",
            glyph:    .sfSymbol("star.fill"),
            text:     "Betelgeuse",
            category: .followedStar(betelgeusePreviewStar),
            scale:    80    // ≥ badgeIn (70), < textIn (100)
        )
        Divider()
        POILabelPreviewCard(
            title:    "Ursa Minor",
            glyph:    .sfSymbol("sparkles"),
            text:     "Ursa Minor",
            category: .constellation(.entity(.zeus)),
            scale:    100   // ≥ badgeIn (80), < textIn (130)
        )
    }
    .padding()
    .background(EArtist.shared.canvasBackground)
}
