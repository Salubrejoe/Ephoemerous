#if DEBUG
import SwiftUI

// MARK: - BadgeGallery
// A DEBUG bench for badge design: the planets for reference, then every
// Local Group galaxy at sky size, magnified, and as the promoted pin draws
// it. Launch with `-badgeGallery`; a simulator capture shows the real
// rendering, which a mockup can't.
struct BadgeGallery: View {

    private let galaxies = LocalGalaxy.allCases
    private let planets: [Planet] = [.venus, .mars, .jupiter, .saturn]

    var body: some View {
        ZStack {
            Artist.shared.skyColor.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 36) {
                row("Planets — sky size") {
                    ForEach(planets, id: \.name) { p in
                        POILabelView(category: .planet(p), text: p.name)
                            .frame(width: 90, alignment: .leading)
                    }
                }
                row("Galaxies — sky size") {
                    ForEach(galaxies, id: \.self) { g in
                        badge(g).frame(width: 90, alignment: .leading)
                    }
                    POILabelView(category: .deepSky(.galaxy, messier: true), text: "old",
                                 nameReveal: 1)
                }
                row("Galaxies — sky size, ×4") {
                    ForEach(galaxies, id: \.self) { g in
                        badge(g, nameReveal: 0, sizeScale: 4).frame(width: 90)
                    }
                }
                row("Galaxies — promoted pin") {
                    ForEach(galaxies, id: \.self) { g in
                        badge(g, nameReveal: 0, richDetail: true, sizeScale: 2.8).frame(width: 90)
                    }
                }
                row("Planets — promoted pin") {
                    ForEach(planets, id: \.name) { p in
                        POILabelView(category: .planet(p), text: "", nameReveal: 0,
                                     richDetail: true, sizeScale: 2.8)
                            .frame(width: 90)
                    }
                }
            }
            .padding(40)
        }
    }

    private func badge(_ g: LocalGalaxy, nameReveal: Double = 1, richDetail: Bool = false,
                       sizeScale: CGFloat = 1) -> some View {
        let obj = DeepSkyCatalog.objects.first { $0.id == g.rawValue }
        return POILabelView(category:   obj?.poiCategory ?? .deepSky(.galaxy, messier: true, galaxy: g),
                            text:       obj?.label ?? g.rawValue,
                            nameReveal: nameReveal,
                            richDetail: richDetail,
                            sizeScale:  sizeScale)
    }

    private func row(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 24) { content() }
        }
    }
}
#endif
