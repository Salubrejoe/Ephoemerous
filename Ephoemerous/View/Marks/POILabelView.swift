import SwiftUI
import UIKit
import CoreText
import LoreKit
import WidgetKit

// MARK: - POILabelView
// Apple-Maps-style POI label as a STANDALONE, reusable SwiftUI view — the
// native counterpart of the Canvas `drawPOILabel`. Driven by a
// `POICategory`, so every tracked body (sun / moon / planets / stars /
// constellations) gets the same component, faithful to the production
// palette via `Artist.poiStyle(for:)`.
//
// Layout anchor is the BADGE: the name floats to its right as a
// non-layout overlay, so the view's size == the badge and a caller can
// `.position(...)` it precisely on the sky point. Circle badge for now
// (squircles come later).
//
// Pieces, bottom → top, mirroring the Canvas treatment:
//   • radial gradient fill — bright `gradientTop` centre → deep
//     `gradientBottom` rim (a little glowing orb)
//   • casing ring in `border` (the light outline that reads against a
//     busy sky) + a soft drop shadow for lift
//   • the name, cased (8-way outline) in the gradient's OUTER colour
struct POILabelView: View {

    /// Tinted / "Clear" Home Screen themes don't show our colours — the
    /// system paints every non-transparent pixel with a light vibrant
    /// material. The casing (a 90%-opaque BLACK ring, doing legibility
    /// work against a dark sky) therefore renders as a 90% WHITE slab and
    /// makes the label *less* readable, not more. So in those modes the
    /// casing and the drop shadow are dropped and the mark carries itself.
    /// Reads `.fullColor` outside a widget, so the app is unaffected.
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    private var isMasked: Bool { widgetRenderingMode != .fullColor }

    enum LabelStyle {
        case star, planetoids
    }

    let category: POICategory
    let text:     String
    
    let labelStyle: LabelStyle
    /// Badge + name reveals, 0…1 — each fades + unblurs in as the zoom
    /// crosses its tier (`badgeIn` / `textIn`). Caller computes them via
    /// `tierReveal(scale:threshold:)`. 0 = absent, 1 = full crisp.
    var badgeReveal: Double = 1
    var nameReveal:  Double = 1
    /// Inverse of any `.scaleEffect` a caller wraps this view in — e.g. the
    /// promoted pin enlarges the whole badge up to ~1.9× (2.3× mid-pop).
    /// `.scaleEffect` scales EVERY pixel uniformly, casing stroke included,
    /// so left at 1 the 1.7pt border would render up to ~4pt: the orb grows
    /// but the outline turns into a bold halo. Pass `1 / callerScale` here
    /// and the stroke pre-shrinks so the two scalings cancel — only the
    /// orb enlarges, the casing weight holds constant. Default 1 (no
    /// caller scaling) leaves every other call site untouched.
    var borderScaleCompensation: CGFloat = 1
    /// 0…1 reveal for the COMPANION PIP — a second, smaller orb tucked at
    /// the badge's lower-trailing edge, marking a double you could actually
    /// split. Not "this is a binary": 83% of the stars we label are multiple
    /// systems, so that would fire on nearly everything (see
    /// `StarMultiplicity.isShowpiece`). Callers ride it in with the NAME
    /// tier, not the badge tier — at badge tier the mark is a few points
    /// across and a pip would just fur its edge. 0 = absent.
    var companionReveal: Double = 0

    /// Gap (pt) between the badge's trailing edge and the name.
    private let nameGap: CGFloat = 6
    /// Max blur (pt) at reveal 0 — the mark resolves out of a soft haze.
    private static let nameBlur:  CGFloat = 4
    private static let badgeBlur: CGFloat = 3

    private var style: Artist.POICategoryStyle { Artist.shared.poiStyle(for: category) }
    
    init(
        category: POICategory,
        text: String,
        labelStyle: LabelStyle = .planetoids,
        badgeReveal: Double = 1,
        nameReveal: Double = 1,
        borderScaleCompensation: CGFloat = 1,
        companionReveal: Double = 0
    ) {
        self.category = category
        self.text = text
        self.labelStyle = labelStyle
        self.badgeReveal = badgeReveal
        self.nameReveal = nameReveal
        self.borderScaleCompensation = borderScaleCompensation
        self.companionReveal = companionReveal
    }

    var body: some View {
        badge
            // Badge blooms in with opacity + blur at its tier — applied
            // BEFORE the name overlay so the name keeps its own reveal.
            .opacity(badgeReveal)
            .blur(radius: (1 - badgeReveal) * Self.badgeBlur)
            .overlay(alignment: .leading) {
                if nameReveal > 0.01 {
                    // Real glyph-outline casing (see `OutlinedText`); fill
                    // in the gradient's OUTER colour, same as the Canvas
                    // flat label. Blooms in with opacity + blur as the
                    // zoom crosses the tier — cheap on a few native labels.
                    OutlinedText(text:      text,
                                 fill:      style.textColor,
                                 stroke:    style.border,
                                 lineWidth: 2.5,
                                 font:      Self.nameFont)
                        .opacity(nameReveal)
                        .blur(radius: (1 - nameReveal) * Self.nameBlur)
                        // Overlay aligns the name's leading to the badge's
                        // leading; push it right past the badge so the text
                        // trails the symbol and never overlaps it.
                        .offset(x: style.badgeSize + nameGap)
                }
            }
    }

    /// Smoothstep 0→1 as `scale` rises from `threshold` to `threshold·1.18`
    /// — the zoom-driven tier fade (no timer; ramps as the user pinches).
    /// `threshold 0` (Sun/Moon badge) → always 1.
    static func tierReveal(scale: CGFloat, threshold: Double) -> Double {
        guard threshold > 0 else { return 1 }
        let band = threshold * 0.18
        let x = max(0, min(1, (Double(scale) - threshold) / band))
        return x * x * (3 - 2 * x)
    }

    /// Footnote serif bold, as a `UIFont` (CoreText needs a concrete font
    /// to lay out glyph paths). `preferredFont` keeps Dynamic Type.
    private static let nameFont: UIFont = {
        let base = UIFont.preferredFont(forTextStyle: .footnote)
        var desc = base.fontDescriptor
        desc = desc.withDesign(.serif) ?? desc
        desc = desc.withSymbolicTraits(.traitBold) ?? desc
        return UIFont(descriptor: desc, size: base.pointSize)
    }()
    
    
    
    // MARK: Badge
    
    private var badge: some View {
        let d  = style.badgeSize
        // Pre-shrunk so a caller's `.scaleEffect` renders it back at the
        // true casing weight — see `borderScaleCompensation`.
        let bw = Artist.shared.poiTextBorderWidth * borderScaleCompensation
        let bulge = labelStyle == .planetoids ? 2.0 : 5.0
        
        return ZStack {
            
            Squircle(corners: 5, bulge: bulge)
                .fill(
                    
                    LinearGradient(colors: [
                        style.gradientTop,
                        style.gradientBottom
                    ], startPoint: .bottom, endPoint: .top)
                )
        }
        .frame(width: d, height: d)
        // Casing ring — the light outline doing the legibility work.
        .overlay(
//            Circle()
            Squircle(corners: 5, bulge: bulge)
                .stroke(isMasked ? .clear : style.border, lineWidth: bw)
        )
        // Companion pip — the same orb in miniature, at the lower-trailing
        // edge. It reads as what an eyepiece shows: one star, then a second
        // beside it. Lower-TRAILING because the favourite heart takes the
        // upper-leading corner (see FavouriteHeart), so a star can be both
        // remembered and double without the two marks colliding.
        // ▼ TWEAK the pip's size and how far it sits out ▼
        .overlay(alignment: .bottomTrailing) {
            if companionReveal > 0.01 {
                let pip = d * 0.55        // ▼ TWEAK the companion's size ▼
                Squircle(corners: 5, bulge: bulge)
                    .fill(LinearGradient(colors: [style.gradientTop, style.gradientBottom],
                                         startPoint: .bottom, endPoint: .top))
                    .overlay(
                        Squircle(corners: 5, bulge: bulge)
                            .stroke(isMasked ? .clear : style.border, lineWidth: bw * 0.8)
                    )
                    .frame(width: pip, height: pip)
                    .offset(x: pip * 0.52, y: pip * 0.34)
                    .opacity(companionReveal)
                    .blur(radius: (1 - companionReveal) * Self.badgeBlur * 0.5)
            }
        }
        // Soft drop shadow for lift (one view → cheap, unlike the Canvas
        // per-glyph blur). No glow under a masking host — it just fattens
        // the white blob.
        .shadow(color: isMasked ? .clear : style.gradientTop.opacity(0.35),
                radius: isMasked ? 0 : 2.5, y: isMasked ? 0 : 0.5)
    }
}

#if DEBUG
// The badge grammar at a glance: every species, name revealed.
// Self-contained on purpose — this file also compiles into the widget and
// watch targets, which don't carry the app's preview scaffolding.
#Preview("POI species") {
    let star = Star.mockStars[0]
    return ZStack {
        Artist.shared.canvasBackground
        VStack(alignment: .leading, spacing: 22) {
            POILabelView(category: .sun,   text: "Sun",   labelStyle: .star)
            POILabelView(category: .moon,  text: "Moon",  labelStyle: .planetoids)
            POILabelView(category: .planet(.mars), text: "Mars", labelStyle: .planetoids)
            POILabelView(category: .followedStar(star),
                         text: star.displayName, labelStyle: .star)
            // A showpiece double wears the companion pip.
            POILabelView(category: .namedStar(star),
                         text: "Albireo", labelStyle: .star, companionReveal: 1)
        }
    }
    .frame(width: 320, height: 320)
    .environment(\.colorScheme, .dark)
}
#endif
