import SwiftUI

// MARK: - DesignatedStarMarks
// At the very deepest zoom every star with a Bayer letter or Flamsteed
// number becomes tappable (`designatedStarTapIn`) — so each one wears a
// mark to tap: the star's own badge, symbol only. The name waits for the
// tap, like deep sky. Only in the calm middle of the screen, and only past
// the threshold; below it the layer is empty.
struct DesignatedStarMarks: View {

    let camera:     SkyCamera
    let pinch:      CGFloat
    let scale:      CGFloat
    let rotation:   Angle
    /// The selected star is drawn by the promoted pin instead.
    var selectedID: String? = nil
    /// Pinned stars already wear their badge (`StarLabels`).
    var favouriteIDs: Set<String> = []
    var comfort:    LabelComfortZone = .everywhere

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                POILabelView(category:    .namedStar(mark.star),
                             text:        "",
                             labelStyle:  .star,
                             badgeReveal: mark.reveal,
                             nameReveal:  0)
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(mark.sc)
            }
        }
        .allowsHitTesting(false)
    }

    private struct Mark: Identifiable {
        let star:   Star
        let sc:     CGPoint
        let reveal: Double
        var id: String { star.id }
    }

    private var marks: [Mark] {
        let threshold = Artist.shared.designatedStarTapIn
        let reveal    = POILabelView.tierReveal(scale: scale, threshold: threshold)
        guard reveal > 0.01 else { return [] }
        let w = camera.size.width, h = camera.size.height
        return SkyFrame.designatedStars.compactMap { star in
            guard star.id != selectedID, !favouriteIDs.contains(star.id),
                  let sc = camera.screen(equatorial: star.equatorialVector),
                  sc.x > -40, sc.x < w + 40, sc.y > -40, sc.y < h + 40
            else { return nil }
            let calm = comfort.nameVisibility(at: sc)
            guard calm > 0.01 else { return nil }
            return Mark(star: star, sc: sc, reveal: reveal * calm)
        }
    }
}
