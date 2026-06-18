import SwiftUI
import simd
import LoreKit

// MARK: - SkyLabConstellationLabelsOverlay
// Constellation NAMES — like the celestial canvas, these are just the
// name centred on the figure's label anchor (no badge, unlike the POI
// labels). They sit at the constellation TIER (textIn ≈ 190 — between
// favourite-stars and proper-named stars), and reveal with the SAME
// zoom-driven opacity + blur as every other label, so the whole sky
// phases in and out as one.
//
// All constellations share one threshold (no per-figure tier bump), so
// the reveal is computed ONCE and the layer early-outs entirely below
// it — nothing rendered until you're in constellation-name territory.
struct ConstellationLabels: View {

    let camera: SkyCamera
    let pinch:  CGFloat
    let scale:  CGFloat
    /// Live map rotation — counter-rotated per name so it stays
    /// screen-upright while the sky spins (Apple-Maps).
    var rotation: Angle = .zero
    /// Selected constellation (rawValue) — emphasised in place (primary +
    /// crisp), the production `isSelected` treatment. No badge, no pin.
    var selectedID: String? = nil

    /// Footnote serif bold, matching the POI label names.
    private static let font: UIFont = {
        let base = UIFont.preferredFont(forTextStyle: .footnote)
        var d = base.fontDescriptor
        d = d.withDesign(.rounded) ?? d
        d = d.withSymbolicTraits(.traitBold) ?? d
        return UIFont(descriptor: d, size: base.pointSize)
    }()

    /// Constellation text tier (shared by all kinds — kind only changes
    /// the gradient, not the thresholds).
    private static let textIn: Double =
        EArtist.shared.poiStyle(for: .constellation(.myth(.none))).textIn

    private static let blur: CGFloat = 4

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                
                Text(mark.name.uppercased())
                    .foregroundStyle(mark.selected ? .primary : .tertiary)
                    .font(.footnote)
                    .fontDesign(.serif)
                    .contentShape(.capsule)
                
                    .opacity(mark.selected ? 1 : mark.reveal)
                    .blur(radius: mark.selected ? 0 : (1 - mark.reveal) * Self.blur)
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(mark.sc)
            }
        }
    }

    private struct Mark: Identifiable {
        let id:       String
        let name:     String
        let sc:       CGPoint
        let reveal:   Double
        let selected: Bool
    }

    private var marks: [Mark] {
        // One shared reveal; below the tier the whole layer is empty —
        // EXCEPT the selected constellation, which stays visible (forced).
        let reveal = POILabelView.tierReveal(scale: scale, threshold: Self.textIn)
        guard reveal > 0.01 || selectedID != nil else { return [] }

        let w = camera.size.width, h = camera.size.height
        return ConstellationLines.shared.labelAnchors.compactMap { cons, anchor in
            let selected = cons.rawValue == selectedID
            guard reveal > 0.01 || selected else { return nil }
            let q = EPrecession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
            guard let sc = camera.screen(equatorial: q) else { return nil }
            guard sc.x > -60, sc.x < w + 60, sc.y > -60, sc.y < h + 60 else { return nil }
            return Mark(id: cons.rawValue, name: cons.localizedName,
                        sc: sc, reveal: reveal, selected: selected)
        }
    }
}
