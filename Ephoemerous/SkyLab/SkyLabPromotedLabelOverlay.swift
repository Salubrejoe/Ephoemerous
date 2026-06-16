import SwiftUI
import UIKit
import simd

// MARK: - SkyLabPromotedLabelOverlay
// The selected object's POI label, FORCED visible at any zoom and laid out
// the Apple-Maps / production way: the badge SPRINGS UP off the star point
// (leaving a precise-location dot behind) and the name slides in CENTERED
// BELOW it — not the passive label's trailing-right name.
//
// One counter-scaled unit anchored on the star: the container's centre is
// the precise location (so the dot sits exactly on the point and stays put
// under the 1/pinch counter-scale); the badge is lifted above it, the name
// dropped below. A single `promo` spring (0→1 on appear) drives the lift,
// the badge enlargement, and the dot/name fade — the underdamped spring is
// the "pop". The selected star's passive label is suppressed upstream, so
// there's no double badge.
struct SkyLabPromotedLabelOverlay: View {

    let camera:    SkyLabCamera
    let selection: SkyLabSelection?
    let pinch:     CGFloat

    var body: some View {
        ZStack {
            if let sel = selection,
               let sc  = camera.screen(equatorial: sel.star.equatorialVector) {
                SkyLabPromotedPin(star: sel.star)
                    .scaleEffect(1 / pinch)
                    .position(sc)
                    .id(sel.star.id)                 // re-spring on a new star
                    .transition(.opacity)            // soft demotion
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - SkyLabPromotedPin
private struct SkyLabPromotedPin: View {

    let star: EStar

    /// 0 = flat (badge on the point), 1 = fully promoted pin. Springs up
    /// on appear — the underdamped overshoot is the Apple-Maps pop.
    @State private var promo: Double = 0

    /// Fixed local canvas; centre == the precise location (the star). Wide
    /// enough for a long name, tall enough for the lifted badge.
    private let box = CGSize(width: 220, height: 140)

    private var style: EArtist.POICategoryStyle {
        EArtist.shared.poiStyle(for: .followedStar(star))
    }

    var body: some View {
        let a        = EArtist.shared
        let badge    = style.badgeSize
        let lift     = promo * a.poiSelectLiftFactor * badge          // badge rises
        let scale    = 1 + promo * (a.poiSelectScale - 1)             // badge enlarges
        let nameDrop = a.poiSelectNameDrop
        let r        = a.poiSelectDotRadius
        let cx       = box.width / 2
        let cy       = box.height / 2

        ZStack {
            // Precise-location dot — the spot the badge lifted off, the
            // name hangs under. Fades in with the promotion.
            Circle()
                .fill(style.gradientBottom)
                .frame(width: r * 2, height: r * 2)
                .shadow(color: .black.opacity(0.35), radius: 1.5)
                .opacity(promo)
                .position(x: cx, y: cy)

            // Badge — reuse the POI badge styling (name off), lifted and
            // enlarged. scaleEffect anchors on its own centre, so it grows
            // in place at the lifted point.
            POILabelView(category:    .followedStar(star),
                         glyph:       .sfSymbol("star.fill"),
                         text:        "",
                         badgeReveal: 1,
                         nameReveal:  0)
                .scaleEffect(scale)
                .position(x: cx, y: cy - lift)

            // Name — centred below the dot, primary ink, real outline
            // casing (same OutlinedText the flat label uses).
            OutlinedText(text:      star.displayName,
                         fill:      .primary,
                         stroke:    style.border,
                         lineWidth: 2.5,
                         font:      Self.nameFont)
                .fixedSize()
                .opacity(promo)
                .position(x: cx, y: cy + nameDrop + Self.nameHalfHeight)
        }
        .frame(width: box.width, height: box.height)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                promo = 1
            }
        }
    }

    /// Footnote serif bold (CoreText needs a concrete UIFont) — matches the
    /// flat label's name font.
    private static let nameFont: UIFont = {
        let base = UIFont.preferredFont(forTextStyle: .footnote)
        var desc = base.fontDescriptor
        desc = desc.withDesign(.serif) ?? desc
        desc = desc.withSymbolicTraits(.traitBold) ?? desc
        return UIFont(descriptor: desc, size: base.pointSize)
    }()

    /// Rough half-height of the name, so `.position` lands its TOP at
    /// `cy + nameDrop` (the text hangs just below the precise dot).
    private static let nameHalfHeight: CGFloat = nameFont.lineHeight / 2
}
