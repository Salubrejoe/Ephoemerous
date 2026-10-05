import SwiftUI
import LoreKit

// MARK: - ConstellationDetailView
// A constellation's place card (see `PlaceSheet`). It isn't a point — it's
// a drawing, a story and a region. The drawing is the header itself: the
// figure, its stars named and tappable (`HeroFigureMarks`). Then the tiles:
//
//   [         STORY       (wide)       ]   how it got there
//   [ RISE & SET     ][    SEASON      ]   the figure's centre · evenings
//   [         DEPTH       (wide)       ]   its stars at their real distances
//   [ BRIGHTEST      ][    SIZE        ]   its lead star · IAU area, rank
//   [         STARS       (wide)       ]   the roster
//
// Stars open by push (a back chevron home), or — in the iPad's floating
// panel, with no stack — by selection (`StarLink`).
struct ConstellationDetailView: View {
    @Environment(AppState.self) var state
    let constellation: Constellation

    /// What it depicts and its IAU abbreviation — "Hero · Ori".
    private var subtitle: String {
        let entity = Artist.shared.constellationEntity(of: constellation).localizedName
        return "\(entity) · \(constellation.rawValue)"
    }

    var body: some View {
        PlaceSheet(object:   .constellation(constellation),
                   title:    constellation.localizedName,
                   subtitle: subtitle,
                   heroScale: Artist.shared.constellationHeroScale) {
            tiles
        } actions: {
            PlaceActions(object: .constellation(constellation))
        }
        .navigationDestination(for: Star.self) { s in
            StarDetailView(star: s, showsBackChevron: true)
        }
    }

    private var tiles: some View {
        let a      = Artist.shared
        let date   = state.observationDate
        let cal    = Calendar.current
        let object = SkyObject.constellation(constellation)
        let status = SkyStatus.cached(object: object, date: date, observer: state.placeObserver)
        let path   = StarDayPath(object: object, around: date, observer: state.placeObserver)
        let stars  = constellation.catalogueStars
        return VStack(spacing: a.detailGridSpacing) {
            ConstellationStoryTile(constellation: constellation)
            DetailGridLayout(rows: [2, 1, 2]) {
                RiseSetTile(status: status, path: path)
                ConstellationSeasonTile(
                    altitudes: constellation.eveningAltitudes(year: cal.component(.year, from: date),
                                                              from: state.placeObserver),
                    month:     cal.component(.month, from: date))
                ConstellationDepthTile(constellation: constellation)
                if let brightest = stars.first {
                    ConstellationBrightestTile(star: brightest)
                } else {
                    Color.clear
                }
                ConstellationSizeTile(constellation: constellation)
            }
            ConstellationStarsTile(stars: Array(stars.prefix(12)))
        }
    }
}

extension Artist {
    /// The constellation card's header picture — its figure, named — runs
    /// this much taller than the other cards'. ▼ TWEAK ▼
    var constellationHeroScale: CGFloat { 1.9 }
}

#if DEBUG
#Preview {
    NavigationStack { ConstellationDetailView(constellation: .Ori) }
        .environment(AppState())
}
#endif
