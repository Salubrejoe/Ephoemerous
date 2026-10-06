import SwiftUI
import LoreKit

// MARK: - PlaceSheet
// One scaffold for every place card — star, Sun, Moon, planet, spacecraft —
// so they can't drift apart: the Maps-style `PlaceHeader`, then the grid of
// frosted tiles in a scroll that eases the header back as it goes, the
// action row at its head, and the map's night fading in behind as the sheet
// rises (`DetailBackdrop`). Folded to its header detent, only the header.
//
// Each sheet supplies just its tiles (in a `DetailGridLayout`) and its
// action row (`PlaceActionRow`), which heads the grid.
struct PlaceSheet<Tiles: View, Actions: View>: View {

    @Environment(AppState.self)     private var state
    @Environment(\.detailCollapsed) private var collapsed
    @Environment(\.detailInPanel)   private var inPanel

    let object:   SkyObject
    let title:    String
    let subtitle: String
    var leading:  PlaceHeader.Leading = .share
    var heroScale: CGFloat = 1
    @ViewBuilder let tiles:   () -> Tiles
    @ViewBuilder let actions: () -> Actions

    @State private var scrollPosition = ScrollPosition()
    /// The scroll offset, observed only by the sticky row and its mask.
    @State private var scroll = PlaceScroll()
    /// How tall the action row is (0 for a card with none) — the scroll
    /// content leaves that much room under the picture.
    @State private var rowHeight: CGFloat = 0
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
                let heroH = Artist.shared.placeHeroBlockHeight(reveal: state.detailSheetExpansion,
                                                              scale:  heroScale)
                // The action row floats over the scroll view (see
                // `StickyPlaceActions`); the scroll content just leaves it a
                // gap under the picture.
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(spacing: 0) {
                            PlaceHero(object: object, scale: heroScale)
                            Color.clear.frame(height: rowHeight)
                            tiles()
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                .padding(.bottom, 24)
                        }
                    }
                    .scrollIndicators(.hidden)
                    // Tiles recede OUT of the scroll area as they leave (see
                    // DetailCard); `StickyMask` is what keeps them off the
                    // header and the row.
                    .scrollClipDisabled()
                    .scrollPosition($scrollPosition)
                    .mask { StickyMask(scroll: scroll, heroHeight: heroH, rowHeight: rowHeight) }
                    // Pull down past the top of the grid → fold the card to its
                    // title, as a sheet's drag would. The iPad panel otherwise
                    // only drags by its header band, and a swipe on the body
                    // just scrolled. Reads the overscroll; writes state ONCE per
                    // pull, so it can't fight the scroll the way a live-resizing
                    // header did.
                    .onScrollGeometryChange(for: CGFloat.self) { geo in
                        geo.contentOffset.y + geo.contentInsets.top
                    } action: { _, y in
                        scroll.y = y
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

                    StickyPlaceActions(scroll: scroll, heroHeight: heroH, rowHeight: $rowHeight) {
                        actions()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        // The night fades in as the sheet rises — none at its resting
        // third, the full sky at full screen.
        // None on the iPad: its card is plain glass over the live map, and
        // painting the night inside it hid the very sky it floats on.
        .background {
            if !collapsed && !inPanel {
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
