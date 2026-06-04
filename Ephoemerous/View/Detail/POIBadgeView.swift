import SwiftUI
import LoreKit

// MARK: - POIBadgeView
// SwiftUI rendering of the same Apple-Maps-style POI badge the canvas
// draws via `EArtist.drawPOILabel(...)`. Used in detail-sheet headers
// so the icon under the title matches the badge the user just tapped
// on the canvas (e.g. a spectral pentagon for a star, a heptagon for
// a planet) — no more generic `star.fill` next to the canvas's
// proper gradient pentagon.
//
// All sizing + palette comes from `EArtist.poiStyle(for:)` so a future
// tweak (corner count, gradient retone) lands in both places at once.
// Glyphs are kept in sync manually below — `glyph(for:)` mirrors the
// `glyph:` arguments each canvas layer passes to `drawPOILabel`.
struct POIBadgeView: View {
    let category: POICategory
    var size: CGFloat = 22

    private var artist: EArtist               { EArtist.shared }
    private var style:  EArtist.POICategoryStyle { artist.poiStyle(for: category) }

    var body: some View {
        ZStack {
            Squircle(corners: style.badgeCorners,
                     bulge:   artist.poiBadgeBulge)
                .fill(
                    LinearGradient(
                        colors:     [style.gradientTop, style.gradientBottom],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )
                .overlay {
                    Squircle(corners: style.badgeCorners,
                             bulge:   artist.poiBadgeBulge)
                        .stroke(style.border, lineWidth: 0.5)
                }
                .frame(width: size, height: size)
            glyphView
        }
        .shadow(color: Color(.systemBackground), radius: 1, x: 0, y: 0)
    }

    @ViewBuilder
    private var glyphView: some View {
        switch glyph(for: category) {
        case .sfSymbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(style.symbolColor)
        case .unicode(let str):
            // Unicode astronomical glyphs render a touch smaller
            // than SF Symbols at the same point size — same +2pt
            // bump the canvas uses inside `drawPOILabel`.
            Text(str)
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(style.symbolColor)
        }
    }

    /// Same SF Symbol / Unicode glyph each canvas layer passes to
    /// `drawPOILabel(...)`. Keep in sync if a layer changes its
    /// glyph argument.
    private func glyph(for category: POICategory) -> POIGlyph {
        switch category {
        case .sun:                          return .symbol(.sunMax)
        case .moon:                         return .symbol(.moon)
        case .followedStar, .namedStar:     return .symbol(.starFill)
        case .planet(let p):                return .unicode(p.astronomicalGlyph)
        case .constellation:
            // Constellations no longer carry a canvas badge — this
            // path is here for completeness if a future detail view
            // wants to surface the old entity-glyph treatment.
            return .symbol(.sparkles)
        }
    }
}
