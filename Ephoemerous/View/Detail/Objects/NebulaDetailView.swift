import SwiftUI
import LoreKit

// MARK: - NebulaDetailView
// A named nebula's place card (see `PlaceSheet`): the Maps-style header
// with the nebula's own badge pinned on the sky, a Find / Constellation
// row, then the grid —
//
//   [        DISTANCE  (wide)        ]   the cluster card's line, its badge on it
//   [ RISE & SET   ][  BRIGHTNESS    ]
//   [     SIZE     ][   POSITION     ]   on the sky, in full Moons
//   [        NEBULAE  (roster)       ]   the other eight, each opening its card
//
// No Pin yet: the favourites store only knows stars, constellations and the
// solar system. The words live in `NebulaFacts`.
struct NebulaDetailView: View {
    @Environment(AppState.self) var state
    @Environment(\.dismiss) var dismiss
    let nebula: NamedNebula
    let object: DeepSkyObject
    /// `true` when pushed from another nebula's roster — the header's
    /// leading corner becomes the way back instead of Share.
    var showsBackChevron: Bool = false

    /// "Planetary nebula · M57", "Emission nebula · NGC 3372".
    private var subtitle: String { "\(nebula.kindName) · \(object.designation)" }

    var body: some View {
        PlaceSheet(object:   .deepSky(object),
                   title:    object.label,
                   subtitle: subtitle,
                   leading:  showsBackChevron ? .button(.chevronBackward, { dismiss() }) : .share) {
            tiles
        } actions: {
            PlaceActionRow {
                FindAction()
                if let c = object.constellation {
                    ConstellationAction(constellation: c)
                }
            }
        }
        .navigationDestination(for: DeepSkyObject.self) { d in
            if let n = d.namedNebula { NebulaDetailView(nebula: n, object: d, showsBackChevron: true) }
        }
        .navigationDestination(for: Constellation.self) { c in
            ConstellationDetailView(constellation: c, showsBackChevron: true)
        }
        .onAppear { state.recordViewed(.deepSky(object)) }
    }

    private var tiles: some View {
        let a      = Artist.shared
        let date   = state.observationDate
        let sky    = SkyObject.deepSky(object)
        let status = SkyStatus.cached(object: sky, date: date, observer: state.placeObserver)
        let path   = StarDayPath(object: sky, around: date, observer: state.placeObserver)
        return VStack(spacing: a.detailGridSpacing) {
            DetailGridLayout(rows: [1, 2, 2]) {
                ClusterDistanceTile(cluster: object)
                RiseSetTile(status: status, path: path)
                BrightnessTile(magnitude: object.mag ?? 6)
                ClusterSizeTile(arcminutes: object.major)
                PositionTile(raHours: object.ra / 15, decDegrees: object.dec)
            }
            NebulaNeighboursTile(neighbours: NamedNebula.allCases
                .filter { $0 != nebula }
                .compactMap(\.object)
                .sorted { ($0.lightYears ?? .infinity) < ($1.lightYears ?? .infinity) })
        }
    }
}

// MARK: - Nebulae (roster)
// The other eight, nearest first, each opening its own card.
struct NebulaNeighboursTile: View {

    let neighbours: [DeepSkyObject]

    var body: some View {
        DetailCard(title: String(localized: "Nebulae"), symbol: "list.bullet") {
            VStack(spacing: 0) {
                ForEach(Array(neighbours.enumerated()), id: \.element) { i, obj in
                    if i > 0 { Divider().opacity(0.4) }
                    DeepSkyLink(object: obj) {
                        HStack(spacing: 12) {
                            POILabelView(category: obj.poiCategory, text: "", nameReveal: 0)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(obj.label).font(.body)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(obj.namedNebula?.kindName ?? obj.kindName)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            if let ly = obj.lightYears {
                                Text(SkyObject.lightYears(ly))
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                    }
                }
            }
        }
    }
}
