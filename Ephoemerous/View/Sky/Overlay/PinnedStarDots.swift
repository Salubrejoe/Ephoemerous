import SwiftUI
import simd
import LoreKit

// MARK: - PinnedStarDots
// The pinned stars' tier-0 mark. A pinned star always has a mark attached to
// a visible badge — so below the badge tier it IS its tiny spectral pentagon
// dot (StarsCanvas skips pinned stars, so this is the star's only rendering
// down here — slightly warmer than the plain field). At and above the badge
// tier the always-on badge (`StarLabels`) says it all: a pinned star is the
// one that never leaves the map, so it needs no extra glyph.
//
// Native, constant screen size (counter-scaled), positioned via the
// shared camera.
struct PinnedStarDots: View {

    let camera: SkyCamera
    let stars:  [Star]
    let pinch:  CGFloat
    /// Live (clamped) zoom — gates the dot on the followed-star badge tier.
    let scale:  CGFloat
    var rotation: Angle = .zero
    /// Selected star is shown by the promoted pin instead — skip its dot.
    var selectedID: String? = nil

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                // Tier-0 pentagon dot in the star's spectral rim colour —
                // the followed-star mark the style system already defines.
                if !mark.badged {
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
#Preview("Pinned stars") {
    PreviewSky.night {
        PinnedStarDots(camera: PreviewSky.camera,
                       stars: PreviewSky.brightStars,
                       pinch: 1, scale: 320, rotation: .zero,
                       selectedID: nil)
    }
}
#endif
