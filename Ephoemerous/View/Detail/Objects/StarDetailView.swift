import SwiftUI
import LoreKit

// MARK: - StarDetailView
// The star's place card (see `PlaceSheet`): the Maps-style header with its
// designation, then the grid —
//
//   [        DISTANCE  (wide)        ]
//   [ RISE & SET   ][  BRIGHTNESS    ]
//   [          TYPE  (wide)          ]
//   [  POSITION    ][ PROPER MOTION  ]
//
// — and Remember / Find in the sky at its foot.
struct StarDetailView: View {
    @Environment(AppState.self) var state
    @Environment(\.dismiss) var dismiss
    let star: Star
    /// `true` when pushed from the constellation roster — the header's
    /// leading corner becomes the way back instead of Share.
    var showsBackChevron: Bool = false

    var body: some View {
        PlaceSheet(object:   .star(star),
                   title:    star.displayName,
                   subtitle: star.designation,
                   leading:  showsBackChevron ? .button(.chevronBackward, { dismiss() }) : .share) {
            tiles
        } actions: {
            PlaceActions(object: .star(star))
        }
        .onAppear {
            // Universal Recents entry — covers the push-from-constellation
            // path that doesn't go through `focus(on:)`.
            state.recordViewed(.star(star))
        }
    }

    private var tiles: some View {
        let date   = state.observationDate
        let year   = Calendar.current.component(.year, from: date)
        let status = SkyStatus.cached(object: .star(star), date: date, observer: state.placeObserver)
        let path   = StarDayPath(object: .star(star), around: date, observer: state.placeObserver)
        return DetailGridLayout(rows: [1, 2, 1, 2]) {
            StarDistanceTile(star: star, year: year)
            RiseSetTile(status: status, path: path)
            BrightnessTile(magnitude: star.magnitude)
            StarTypeTile(star: star)
            PositionTile(raHours: star.rightAscension.degrees / 15, decDegrees: star.declination.degrees)
            StarProperMotionTile(star: star)
        }
    }
}

#if DEBUG
#Preview("Star") {
    NavigationStack {
        StarDetailView(star: Star.mockStars[0])
    }
    .environment(AppState())
}
#endif
