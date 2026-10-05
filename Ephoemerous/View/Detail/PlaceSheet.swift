import SwiftUI
import LoreKit

// MARK: - PlaceSheet
// One scaffold for every place card — star, Sun, Moon, planet, spacecraft —
// so they can't drift apart: the Maps-style `PlaceHeader`, then the grid of
// frosted tiles in a scroll that eases the header back as it goes, the
// actions at its foot, and the map's night fading in behind as the sheet
// rises (`DetailBackdrop`). Folded to its header detent, only the header.
//
// Each sheet supplies just its tiles (in a `DetailGridLayout`) and actions.
struct PlaceSheet<Tiles: View, Actions: View>: View {

    @Environment(AppState.self)     private var state
    @Environment(\.detailCollapsed) private var collapsed

    let object:   SkyObject
    let title:    String
    let subtitle: String
    var leading:  PlaceHeader.Leading = .share
    var heroScale: CGFloat = 1
    @ViewBuilder let tiles:   () -> Tiles
    @ViewBuilder let actions: () -> Actions

    @State private var scrollPosition = ScrollPosition()
    /// One fold per pull: armed again once the grid is back at rest.
    @State private var pullArmed = true

    var body: some View {
        VStack(spacing: 0) {
            PlaceHeader(object:    object,
                        title:     title,
                        subtitle:  subtitle,
                        leading:   leading,
                        onDismiss: { state.dismissDetail() })
            if !collapsed {
                ScrollView {
                    VStack(spacing: 0) {
                        PlaceHero(object: object, scale: heroScale)
                        VStack(spacing: Artist.shared.detailGridSpacing * 2) {
                            tiles()
                            actions()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
                .scrollIndicators(.hidden)
                // Tiles recede OUT of the scroll area as they leave (see
                // DetailCard) — clipping its top edge sliced them flat.
                .scrollClipDisabled()
                .scrollPosition($scrollPosition)
                // Pull down past the top of the grid → fold the card to its
                // title, as a sheet's drag would. The iPad panel otherwise
                // only drags by its header band, and a swipe on the body
                // just scrolled. Reads the overscroll; writes state ONCE per
                // pull, so it can't fight the scroll the way a live-resizing
                // header did.
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { _, y in
                    if y < -Artist.shared.placePullToFold, pullArmed {
                        pullArmed = false
                        state.detailCollapseRequest &+= 1
                    } else if y >= 0, !pullArmed {
                        pullArmed = true
                    }
                }
                #if DEBUG
                // Screenshot seeding: `-detailScroll <pt>` opens the grid
                // already scrolled (the simulator can't drag).
                .task {
                    let args = ProcessInfo.processInfo.arguments
                    if let i = args.firstIndex(of: "-detailScroll"), i + 1 < args.count,
                       let y = Double(args[i + 1]) {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { scrollPosition.scrollTo(y: y) }
                    }
                }
                #endif
            }
            Spacer(minLength: 0)
        }
        // The night fades in as the sheet rises — none at its resting
        // third, the full sky at full screen.
        .background {
            if !collapsed {
                DetailBackdrop().opacity(Double(state.detailSheetExpansion))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension AppState {
    /// Where the observer stands, in the satellite maths' terms — every
    /// place card's rise/set and spacecraft facts read from it.
    var placeObserver: SatelliteSky.Observer {
        SatelliteSky.Observer(latitude:  origin.latitude.radians,
                              longitude: origin.longitude.radians)
    }
}
