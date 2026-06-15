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
struct SkyLabConstellationLabelsOverlay: View {

    let camera: SkyLabCamera
    let pinch:  CGFloat
    let scale:  CGFloat

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
                OutlinedText(text:      mark.name.uppercased(),
                             fill:      .secondary,            // quiet cartographic name
                             stroke:    .systemBackground,   // dark knockout vs stars
                             lineWidth: 2.5,
                             font:      Self.font)
                    .opacity(mark.reveal)
                    .blur(radius: (1 - mark.reveal) * Self.blur)
                    .scaleEffect(1 / pinch)
                    .position(mark.sc)
            }
        }
    }

    private struct Mark: Identifiable {
        let id:     String
        let name:   String
        let sc:     CGPoint
        let reveal: Double
    }

    private var marks: [Mark] {
        // One shared reveal; below the tier the whole layer is empty.
        let reveal = POILabelView.tierReveal(scale: scale, threshold: Self.textIn)
        guard reveal > 0.01 else { return [] }

        let w = camera.size.width, h = camera.size.height
        return ConstellationLines.shared.labelAnchors.compactMap { cons, anchor in
            let q = EPrecession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
            guard let sc = camera.screen(equatorial: q) else { return nil }
            guard sc.x > -60, sc.x < w + 60, sc.y > -60, sc.y < h + 60 else { return nil }
            return Mark(id: cons.rawValue, name: cons.localizedName, sc: sc, reveal: reveal)
        }
    }
}
