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
struct StarLabels: View {

    let camera:     SkyCamera
    let stars:      [Star]
    let pinch:      CGFloat
    let scale:      CGFloat
    /// Live map rotation — counter-rotated per label so the badge stays
    /// screen-upright while the sky spins (Apple-Maps), pivoting on the
    /// symbol centre. Committed rotation only moves positions, so the live
    /// delta is all we cancel.
    let rotation:   Angle
    let category:   (Star) -> POICategory
    /// The selected star is drawn by the promoted overlay instead — skip it
    /// here so its badge isn't drawn twice.
    var selectedID: String? = nil

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                POILabelView(category:    category(mark.star),
                             text:        mark.star.displayName,
                             labelStyle:    .star,
                             badgeReveal: mark.badgeReveal,
                             nameReveal:  mark.nameReveal,
                             // Rides in with the NAME, not the badge — see
                             // POILabelView.companionReveal.
                             companionReveal: mark.companionReveal)
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(mark.sc)
            }
        }
    }

    private struct Mark: Identifiable {
        let star:        Star
        let sc:          CGPoint
        let badgeReveal: Double
        let nameReveal:  Double
        /// Non-zero only for a double worth splitting — most multiples
        /// don't qualify (`StarMultiplicity.isShowpiece`).
        let companionReveal: Double
        var id: String { star.id }
    }

    private var marks: [Mark] {
        let w = camera.size.width, h = camera.size.height
        return stars.compactMap { star in
            guard star.id != selectedID else { return nil }         // promoted elsewhere
            let style = Artist.shared.poiStyle(for: category(star))
            guard scale >= style.badgeIn else { return nil }        // badge tier gate
            guard let sc = camera.screen(equatorial: star.equatorialVector) else { return nil }
            guard sc.x > -40, sc.x < w + 40, sc.y > -40, sc.y < h + 40 else { return nil }
            let nameReveal = POILabelView.tierReveal(scale: scale, threshold: style.textIn)
            let isDouble   = star.multiplicity?.isShowpiece == true
            return Mark(star: star, sc: sc,
                        badgeReveal: POILabelView.tierReveal(scale: scale, threshold: style.badgeIn),
                        nameReveal:  nameReveal,
                        companionReveal: isDouble ? nameReveal : 0)
        }
    }
}

#if DEBUG
#Preview("Named stars") {
    PreviewSky.night {
        StarLabels(camera: PreviewSky.camera,
                   stars: PreviewSky.brightStars,
                   pinch: 1, scale: 320, rotation: .zero,
                   category: { .namedStar($0) },
                   selectedID: nil)
    }
}
#endif
