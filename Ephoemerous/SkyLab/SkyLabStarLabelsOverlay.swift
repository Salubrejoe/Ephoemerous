import SwiftUI
import simd

// MARK: - SkyLabStarLabelsOverlay
// Generic star-label overlay — proper-named stars (`.namedStar`) and
// favourite stars (`.followedStar`) both ride it, differing only by the
// `category` closure. Each star is gated by its category's production
// zoom TIER: the badge appears past `badgeIn`, the name past `textIn`,
// and below that the star is dropped — so the count stays tiny and the
// reveal cascades with zoom. Culled to the oversized canvas, counter-
// scaled `1/pinch` to hold constant screen size.
struct SkyLabStarLabelsOverlay: View {

    let camera:   SkyLabCamera
    let stars:    [EStar]
    let pinch:    CGFloat
    let scale:    CGFloat
    let category: (EStar) -> POICategory

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                POILabelView(category:  category(mark.star),
                             glyph:     .sfSymbol("star.fill"),
                             text:      mark.star.displayName,
                             showsName: mark.showsName)
                    .scaleEffect(1 / pinch)
                    .position(mark.sc)
            }
        }
    }

    private struct Mark: Identifiable {
        let star:      EStar
        let sc:        CGPoint
        let showsName: Bool
        var id: UUID { star.id }
    }

    private var marks: [Mark] {
        let w = camera.size.width, h = camera.size.height
        return stars.compactMap { star in
            let style = EArtist.shared.poiStyle(for: category(star))
            guard scale >= style.badgeIn else { return nil }        // tier gate
            guard let sc = camera.screen(equatorial: star.equatorialVector) else { return nil }
            guard sc.x > -40, sc.x < w + 40, sc.y > -40, sc.y < h + 40 else { return nil }
            return Mark(star: star, sc: sc, showsName: scale >= style.textIn)
        }
    }
}
