import SwiftUI
import LoreKit

// MARK: - MilkyWayDetailView
// Our own galaxy's place card (see `PlaceSheet`), opened from its badge at
// Sagittarius A*. The header pins that badge on the sky; then the grid —
//
//   [        CENTRE  (wide)          ]   the galaxy face-on, the Sun on it
//   [ RISE & SET   ][   POSITION     ]   of the centre, from here
//   [        ACROSS  (wide)          ]   its width beside Andromeda's
//   [        GALAXY  (facts)         ]   class, stars, standing
//   [        LOCAL GROUP  (roster)   ]   the six we look out at
//
// No Brightness or Size: the centre is behind the dust, and the galaxy
// is all around us. The numbers live in `GalaxyFacts`.
struct MilkyWayDetailView: View {
    @Environment(AppState.self) var state
    @Environment(\.dismiss) var dismiss
    let object: DeepSkyObject
    var showsBackChevron: Bool = false

    var body: some View {
        PlaceSheet(object:   .deepSky(object),
                   title:    object.label,
                   onBack:   showsBackChevron ? { dismiss() } : nil) {
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
            if let g = d.galaxy { GalaxyDetailView(galaxy: g, object: d, showsBackChevron: true) }
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
            DetailGridLayout(rows: [1, 2, 1]) {
                GalacticCentreTile()
                RiseSetTile(status: status, path: path)
                PositionTile(raHours: object.ra / 15, decDegrees: object.dec)
                GalaxyAcrossTile(galaxy: .milkyWay)
            }
            FactsTile(title:  String(localized: "Galaxy"),
                      symbol: "hurricane",
                      stats:  LocalGalaxy.milkyWay.stats)
            GalaxyNeighboursTile(neighbours: LocalGalaxy.neighbours
                .sorted { $0.distanceLy < $1.distanceLy })
        }
    }
}

// MARK: - Centre (wide)
// The galaxy as nobody has seen it, face-on, with the Sun a bead two-thirds
// of the way out — and how far that bead is from the middle you're pointing
// at.
private struct GalacticCentreTile: View {

    var body: some View {
        DetailCard(title: String(localized: "Centre"), symbol: "scope") {
            GeometryReader { geo in
                let side  = geo.size.height
                let badge = Artist.shared.poiStyle(for: LocalGalaxy.milkyWay.category).badgeSize
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(SkyObject.lightYears(LocalGalaxy.milkyWay.distanceLy))
                            .font(.title.weight(.medium))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                        Text("From the Sun, the white bead, to the black hole at the middle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    POILabelView(category:   LocalGalaxy.milkyWay.category,
                                 text:       "",
                                 nameReveal: 0,
                                 richDetail: true,
                                 sizeScale:  side / badge)
                        .frame(width: side, height: side)
                }
            }
            .frame(minHeight: 120)
        }
    }
}
