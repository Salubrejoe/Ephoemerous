import SwiftUI

// MARK: - DeepSkyLabels
// POI badges for nebulae and the Local Group galaxies we can see. Open
// clusters are regions, named like constellations (see `ClusterLabels`). Deep sky keeps quiet:
//   • late — badges arrive only well past the named stars (see
//     `poiTier(for: .deepSky)`), the Messier objects before the rest;
//   • badge only — the name waits for a tap;
//   • in the calm middle — outside the comfort zone the badge fades too;
//   • placed with the stars — they give way to every star mark (see
//     `StarLabelLayout`).
// Culled to the oversized canvas, counter-scaled `1/pinch` and
// counter-rotated like every other label.
struct DeepSkyLabels: View {

    let camera:   SkyCamera
    let pinch:    CGFloat
    let scale:    CGFloat
    let rotation: Angle
    var comfort:  LabelComfortZone = .everywhere
    /// Who gives way — deep sky is placed in the stars' own pass.
    var layout:   StarLabelLayout = .none

    var body: some View {
        ZStack {
            ForEach(marks) { mark in
                POILabelView(category:    mark.obj.poiCategory,
                             text:        mark.obj.label,
                             badgeReveal: mark.reveal,
                             nameReveal:  0)
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(mark.sc)
            }
        }
    }

    private struct Mark: Identifiable {
        let obj:    DeepSkyObject
        let sc:     CGPoint
        let reveal: Double
        var id: String { obj.id }
    }

    /// Only what the shared layout found room for (`StarLabelLayout`).
    private var marks: [Mark] {
        DeepSkyCatalog.objects.compactMap { obj in
            guard layout.deepSky.contains(obj.id),
                  let sc = camera.screen(equatorial: obj.equatorialVector) else { return nil }
            let style = Artist.shared.poiStyle(for: obj.poiCategory)
            return Mark(obj: obj, sc: sc,
                        reveal: POILabelView.tierReveal(scale: scale, threshold: style.badgeIn)
                              * comfort.nameVisibility(at: sc))
        }
    }
}
