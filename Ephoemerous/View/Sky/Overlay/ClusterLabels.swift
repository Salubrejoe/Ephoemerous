import SwiftUI

// MARK: - ClusterLabels
// Open clusters as REGIONS, not points — the Pleiades is two degrees of
// sky, the Hyades five. So a cluster is named the way a constellation is,
// in small spaced capitals, here in the cluster tint so it reads as a
// place inside a constellation.
//
// The name is pinned to a point on the sky inside the cluster, picked by
// eye in a clear patch (`DeepSkyObject.nameVector`), so it rides with the
// stars at every zoom. It always shows, and so do the stars: their badges
// never give way to it, only a star's NAME that would land on it does
// (see `StarLabelLayout`).
// Counter-scaled and counter-rotated like every label.
struct ClusterLabels: View {

    let camera:   SkyCamera
    let pinch:    CGFloat
    let scale:    CGFloat
    var rotation: Angle = .zero
    var comfort:  LabelComfortZone = .everywhere
    var layout:   StarLabelLayout = .none

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let blur: CGFloat = 4

    var body: some View {
        let a    = Artist.shared
        // The tint's mid tone — the light end read as plain white.
        let tint = a.deepSkyGradient(.cluster).bottom
        ZStack {
            ForEach(marks) { mark in
                Text(mark.obj.label.uppercased())
                    .font(.system(a.regionTextStyle, design: .default, weight: a.regionWeight))
                    .tracking(a.regionTracking * a.typeScale(dynamicTypeSize))
                    .foregroundStyle(tint)
                    .shadow(color: a.canvasBackground, radius: a.regionHalo)
                    .opacity(mark.reveal)
                    .blur(radius: (1 - mark.reveal) * Self.blur)
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(mark.sc)
            }
        }
        .allowsHitTesting(false)
    }

    private struct Mark: Identifiable {
        let obj:    DeepSkyObject
        let sc:     CGPoint
        let reveal: Double
        var id: String { obj.id }
    }

    private var marks: [Mark] {
        DeepSkyCatalog.objects.compactMap { obj in
            guard layout.clusters.contains(obj.id),
                  let sc = camera.screen(equatorial: obj.nameVector) else { return nil }
            let reveal = POILabelView.tierReveal(scale: scale,
                                                 threshold: Artist.shared.clusterNameIn(magnitude: obj.mag))
            return Mark(obj: obj, sc: sc, reveal: reveal * comfort.nameVisibility(at: sc))
        }
    }
}
