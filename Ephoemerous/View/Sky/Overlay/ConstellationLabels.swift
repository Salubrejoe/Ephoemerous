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
    /// Names fade outside the calm middle of the screen (the selected one
    /// is exempt).
    var comfort: LabelComfortZone = .everywhere
    /// Names that would land on a mark give way — see `StarLabelLayout`.
    var layout: StarLabelLayout = .none

    /// Tracking grows with the letters (see `Artist+TypeScale`).
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Constellation text tier.
    private static let textIn: Double =
        Artist.shared.poiStyle(for: .constellation).textIn

    private static let blur: CGFloat = 4

    var body: some View {
        let a = Artist.shared
        ZStack {
            ForEach(marks) { mark in
                Text(mark.name.uppercased())
                    .font(.system(a.regionTextStyle, design: .default, weight: a.regionWeight))
                    .tracking(a.regionTracking * a.typeScale(dynamicTypeSize))
                    .foregroundStyle(mark.selected ? a.ink : a.inkSecondary)
                    .shadow(color: a.canvasBackground, radius: a.regionHalo)
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
            guard selected || !layout.hiddenConstellations.contains(cons.rawValue) else { return nil }
            let q = Precession.equatorialVector(ra: anchor.ra, dec: anchor.dec)
            guard let sc = camera.screen(equatorial: q) else { return nil }
            guard sc.x > -60, sc.x < w + 60, sc.y > -60, sc.y < h + 60 else { return nil }
            let calm = selected ? 1 : comfort.nameVisibility(at: sc)
            guard calm > 0.01 || selected else { return nil }
            return Mark(id: cons.rawValue, name: cons.localizedName,
                        sc: sc, reveal: reveal * calm, selected: selected)
        }
    }
}

#if DEBUG
#Preview("Constellation names") {
    PreviewSky.night {
        ConstellationLabels(camera: PreviewSky.camera,
                            pinch: 1, scale: 220, rotation: .zero,
                            selectedID: nil)
    }
}
#endif
