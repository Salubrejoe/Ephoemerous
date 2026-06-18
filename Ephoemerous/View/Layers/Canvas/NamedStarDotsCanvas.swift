import SwiftUI
import simd
import LoreKit

// MARK: - SkyLabNamedStarDotsCanvas
// The THIRD label tier for proper-named stars — production's tier-0 dot.
// A minuscule spectral-class pentagon (the followed/named badge silhouette,
// shrunk to `dotRadius`) that appears once the zoom passes `namedStarDotIn`
// (≈220 — above the constellation-name tier, below the named-star badge
// tier) and crossfades OUT into the badge as the zoom crosses each star's
// own `badgeIn`. Below `namedStarDotIn` nothing draws, so it can't ambush a
// pinch at low zoom.
//
// A Canvas (frozen via `.equatable()`) — there can be hundreds of these at
// once, so the per-glyph native-overlay cost the badges pay isn't worth it
// for a 2.5pt fill. The crossfade still tracks the LIVE zoom by keying the
// equality on a coarse scale bucket (positions stay committed + ride the
// parent transform; only the opacity needs to step).
struct NamedStarDotsCanvas: View, Equatable {

    let camera:     SkyCamera
    let stars:      [EStar]      // proper-named, favourites excluded
    let scale:      CGFloat      // live (clamped) scale
    let selectedID: UUID?        // promoted star is drawn by the pin instead

    static func == (l: Self, r: Self) -> Bool {
        l.camera == r.camera
            && l.bucket == r.bucket
            && l.selectedID == r.selectedID
    }
    /// ~4-unit scale buckets — fine enough for a smooth crossfade, coarse
    /// enough not to redraw every pinch frame.
    private var bucket: Int { Int(scale / 4) }

    var body: some View {
        Canvas { ctx, _ in
            let a = EArtist.shared
            guard scale >= a.namedStarDotIn else { return }   // hard tier gate

            let w = camera.size.width, h = camera.size.height
            for star in stars {
                guard star.id != selectedID else { continue }
                let style = a.poiStyle(for: .namedStar(star))
                // Fade in across `namedStarDotIn`, crossfade out across this
                // star's `badgeIn` (per-magnitude, so brighter ones hand off
                // to their badge first).
                let appear  = POILabelView.tierReveal(scale: scale, threshold: a.namedStarDotIn)
                let badge   = POILabelView.tierReveal(scale: scale, threshold: style.badgeIn)
                let opacity = appear * (1 - badge)
                guard opacity > 0.01 else { continue }

                guard let sc = camera.screen(equatorial: star.equatorialVector) else { continue }
                guard sc.x > -20, sc.x < w + 20, sc.y > -20, sc.y < h + 20 else { continue }

                let r    = style.dotRadius
                let rect = CGRect(x: sc.x - r, y: sc.y - r, width: 2 * r, height: 2 * r)
                let path: Path
                switch style.dotShape {
                case .circle:
                    path = Path(ellipseIn: rect)
                case .squircle(let corners, let bulge):
                    path = Squircle(corners: corners, bulge: bulge).path(in: rect)
                }

                var c = ctx
                c.opacity = opacity
                c.fill(path, with: .color(style.gradientBottom))
            }
        }
    }
}
