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

    let camera:     SkyLabCamera
    let stars:      [EStar]
    let pinch:      CGFloat
    let scale:      CGFloat
    let category:   (EStar) -> POICategory
    /// The selected star is drawn by the promoted overlay instead — skip it
    /// here so its badge isn't drawn twice.
    var selectedID: UUID? = nil

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                POILabelView(category:    category(mark.star),
                             glyph:       .sfSymbol("star.fill"),
                             text:        mark.star.displayName,
                             badgeReveal: mark.badgeReveal,
                             nameReveal:  mark.nameReveal)
                    .scaleEffect(1 / pinch)
                    .position(mark.sc)
            }
        }
    }

    private struct Mark: Identifiable {
        let star:        EStar
        let sc:          CGPoint
        let badgeReveal: Double
        let nameReveal:  Double
        var id: UUID { star.id }
    }

    private var marks: [Mark] {
        let w = camera.size.width, h = camera.size.height
        return stars.compactMap { star in
            guard star.id != selectedID else { return nil }         // promoted elsewhere
            let style = EArtist.shared.poiStyle(for: category(star))
            guard scale >= style.badgeIn else { return nil }        // badge tier gate
            guard let sc = camera.screen(equatorial: star.equatorialVector) else { return nil }
            guard sc.x > -40, sc.x < w + 40, sc.y > -40, sc.y < h + 40 else { return nil }
            return Mark(star: star, sc: sc,
                        badgeReveal: POILabelView.tierReveal(scale: scale, threshold: style.badgeIn),
                        nameReveal:  POILabelView.tierReveal(scale: scale, threshold: style.textIn))
        }
    }
}
