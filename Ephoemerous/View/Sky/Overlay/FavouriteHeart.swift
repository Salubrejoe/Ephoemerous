import SwiftUI
import simd
import LoreKit

// MARK: - SkyLabFavouritesOverlay
// The favourite SIGNAL on stars. A marker may only appear ATTACHED to a
// visible mark — an orphan heart floating beside an invisible star reads
// as debris. So the signal is tiered like everything else:
//
//   • below the badge tier — the favourite IS its tier-0 mark: the tiny
//     spectral pentagon dot (StarsCanvas skips favourites, so this is the
//     star's only rendering down here — slightly warmer than the plain
//     field, no heart).
//   • at/above the badge tier — the corner heart joins the badge, in ONE
//     muted tint: the same pink as the search sheet's REMEMBERED section,
//     so "favourite" speaks one colour everywhere (the old spectral
//     rainbow made sentiment read as confetti).
//
// Native, constant screen size (counter-scaled), positioned via the
// shared camera.
struct FavouriteHeart: View {

    let camera: SkyCamera
    let stars:  [Star]
    let pinch:  CGFloat
    /// Live (clamped) zoom — gates the heart on the followed-star badge
    /// tier so the heart only ever rides a visible badge.
    let scale:  CGFloat
    /// Live map rotation — counter-rotated so the heart stays upright while
    /// the sky spins (Apple-Maps).
    var rotation: Angle = .zero
    /// Selected star is shown by the promoted pin instead — skip its heart
    /// so a highlighted favourite isn't drawn twice (pin + heart).
    var selectedID: String? = nil

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                if mark.badged {
                    FavouriteHeartMark(size: 9,
                                       borderScaleCompensation: pinch)
                        .rotationEffect(-rotation, anchor: .center)
                        .scaleEffect(1 / pinch)
                        // Top-leading of the star so it reads as a corner
                        // mark on the badge.
                        .position(x: mark.sc.x - 5, y: mark.sc.y - 5)
                } else {
                    // Tier-0 pentagon dot in the star's spectral rim colour —
                    // the followed-star mark the style system already defines.
                    Squircle(corners: 5, bulge: Artist.shared.poiBadgeBulge)
                        .fill(mark.dotColor)
                        .frame(width: mark.dotRadius * 2, height: mark.dotRadius * 2)
                        .scaleEffect(1 / pinch)
                        .position(mark.sc)
                }
            }
        }
    }

    private struct Mark: Identifiable {
        let id:        String
        let sc:        CGPoint
        let badged:    Bool
        let dotColor:  Color
        let dotRadius: CGFloat
    }

    private var marks: [Mark] {
        let w = camera.size.width, h = camera.size.height
        return stars.compactMap { star in
            guard star.id != selectedID else { return nil }    // shown as the promoted pin
            guard let sc = camera.screen(equatorial: star.equatorialVector) else { return nil }
            guard sc.x > -20, sc.x < w + 20, sc.y > -20, sc.y < h + 20 else { return nil }
            let style = Artist.shared.poiStyle(for: .followedStar(star))
            return Mark(id:        star.id,
                        sc:        sc,
                        badged:    scale >= style.badgeIn,
                        dotColor:  style.gradientBottom,
                        dotRadius: style.dotRadius)
        }
    }
}

#if DEBUG
#Preview("Remembered hearts") {
    PreviewSky.night {
        FavouriteHeart(camera: PreviewSky.camera,
                       stars: PreviewSky.brightStars,
                       pinch: 1, scale: 320, rotation: .zero,
                       selectedID: nil)
    }
}
#endif
