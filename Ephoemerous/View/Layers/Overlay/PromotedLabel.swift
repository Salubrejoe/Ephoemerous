import SwiftUI
import UIKit
import simd

// MARK: - SkyLabPromotedLabelOverlay
// The selected object's POI label, FORCED visible at any zoom and laid out
// the Apple-Maps / production way: the badge SPRINGS UP off the point
// (leaving a precise-location dot behind) and the name slides in CENTERED
// BELOW it. Handles the badge-style objects — star / sun / moon / planet;
// a selected CONSTELLATION promotes as an emphasised name in its own layer
// (no badge, like production), so this overlay skips it.
//
// One counter-scaled unit anchored on the object: the container's centre
// is the precise location (so the dot sits exactly on the point and stays
// put under the 1/pinch counter-scale); the badge is lifted above it, the
// name dropped below. A single `promo` spring (0→1 on appear) drives the
// lift, the badge enlargement, and the dot/name fade.
struct PromotedLabel: View {

    let camera:    SkyCamera
    let selection: ESkyObject?
    let date:      Date
    let pinch:     CGFloat
    /// Live map rotation — counter-rotated so the pin stays screen-upright
    /// while the sky spins (Apple-Maps), pivoting on its location dot.
    var rotation:  Angle = .zero

    private var labelStyle: POILabelView.LabelStyle {
        switch selection {
        case .star(_):
                .star
        case .sun:
                .star
        case .moon:
                .planetoids
        case .planet(_):
                .planetoids
        case .constellation(_):
                .planetoids
        case nil:
                .planetoids
        }
    }
    
    var body: some View {
        ZStack {
            if let obj = selection,
               let poi = SkyLabObjects.poiMark(obj, date: date),
               let sc  = SkyLabObjects.screen(obj, camera: camera, date: date) {
                SkyLabPromotedPin(category: poi.category,
                                  name:     poi.name,
                                  labelStyle: labelStyle)
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(sc)
                    .id(obj.id)                      // re-spring on a new object
                    .transition(.opacity)            // soft demotion
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - SkyLabPromotedPin
private struct SkyLabPromotedPin: View {

    let category:   POICategory
    let name:       String
    let labelStyle: POILabelView.LabelStyle

    /// 0 = flat (badge on the point), 1 = fully promoted pin. Springs up
    /// on appear — the underdamped overshoot is the Apple-Maps pop.
    @State private var promo: Double = 0

    /// Fixed local canvas; centre == the precise location (the object).
    private let box = CGSize(width: 220, height: 140)

    private var style: EArtist.POICategoryStyle { EArtist.shared.poiStyle(for: category) }

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
            POILabelView(category:    category,
                         text:        "",
                         labelStyle: labelStyle,
                         badgeReveal: 1,
                         nameReveal:  0)
                .scaleEffect(scale)
                .position(x: cx, y: cy - lift)

            // Name — centred below the dot, primary ink, real outline
            // casing (same OutlinedText the flat label uses).
            OutlinedText(text:      name,
                         fill:      .primary,
                         stroke:    style.border,
                         lineWidth: 1.5,
                         font:      Self.nameFont)
                .fixedSize()
                .opacity(promo)
                .position(x: cx, y: cy + nameDrop + Self.nameHalfHeight)
        }
        .frame(width: box.width, height: box.height)
        .onAppear {
            withAnimation(.bouncy) {
                promo = 1
            }
        }
    }

    /// Footnote serif bold (CoreText needs a concrete UIFont) — matches the
    /// flat label's name font.
    private static let nameFont: UIFont = {
        let base = UIFont.preferredFont(forTextStyle: .headline)
        var desc = base.fontDescriptor
        desc = desc.withDesign(.serif) ?? desc
        desc = desc.withSymbolicTraits(.traitBold) ?? desc
        return UIFont(descriptor: desc, size: base.pointSize)
    }()

    /// Rough half-height of the name, so `.position` lands its TOP at
    /// `cy + nameDrop` (the text hangs just below the precise dot).
    private static let nameHalfHeight: CGFloat = nameFont.lineHeight / 2
}
