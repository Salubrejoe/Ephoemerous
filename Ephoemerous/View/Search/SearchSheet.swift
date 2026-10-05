import SwiftUI
import LoreKit

// MARK: - SearchSheet
// Apple-Maps-flavoured search surface that opens from the bottom-
// right search icon in MainView. Layout:
//
//   ┌────────────────────────────────────────────────────────┐
//   │  🔍 Search a star, constellation…         ⓧ       ✕   │
//   ├────────────────────────────────────────────────────────┤
//   │  AT REST — category chips, then that category's list   │
//   │  [Favorites] [Stars] [Constellations] [Planets] …      │
//   │   UP NOW                                               │
//   │   ☆ Betelgeuse      Red supergiant in Orion      38°   │
//   │   BELOW THE HORIZON                                    │
//   │   ✧ Crux            4 stars                            │
//   ├────────────────────────────────────────────────────────┤
//   │  FIELD LIVE, still empty — recents, as plain text      │
//   │     Betelgeuse                                         │
//   ├────────────────────────────────────────────────────────┤
//   │  TEXT TYPED — results across everything, by species    │
//   │   • Sun                                                │
//   └────────────────────────────────────────────────────────┘
//
// At rest the sheet browses: a row of chips picks a category, so nothing
// ever requires typing, and every list leads with what's above the
// horizon right now (see `SkyCatalog`). A query ignores the chips and
// searches everything — filtering inside a chip would make "Vega" vanish
// because you happened to be on Planets. Recents surface only under a
// live, empty cursor, the moment they're useful.
//
// Tapping any row — remembered, recent or result — focuses the
// canvas on that object and dismisses the sheet; the existing
// `detailDestination` flow then brings up the matching detail card.
struct SearchSheet: View {

    @Environment(AppState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool
    @State private var detent: PresentationDetent = Self.barDetent
    /// The chosen browse chip; nil until the user picks one, so the
    /// sheet opens on `SkyCatalog.defaultChip`.
    @State private var chosenChip: BrowseChip? = nil

    /// PANEL mode (iPad, regular width): the host `FloatingPanel` owns the
    /// stage, so this view drives that binding instead of its own detent
    /// and skips every `presentation*` modifier — those belong to a sheet
    /// and are inert (or fight the host) outside one.
    ///
    /// nil = sheet mode, the compact path, byte-for-byte as before.
    var panelStage: Binding<PanelStage>? = nil

    private var isPanel: Bool { panelStage != nil }

    /// The current rest position, whichever presentation owns it.
    private var stage: PanelStage {
        if let panelStage { return panelStage.wrappedValue }
        switch detent {
        case Self.barDetent: return .bar
        case .medium:        return .medium
        default:             return .large
        }
    }

    /// Close the panel back to its resting bar: drop the keyboard, clear
    /// the query (a parked bar holding a stale search would show results
    /// it has no room to draw), and park the stage.
    private func closeSearch() {
        searchFocused = false
        searchText    = ""
        withAnimation(.snappy(duration: 0.32)) { setStage(.bar) }
    }

    /// Vertical swipe on the search bar → raise or park the panel.
    private var panelSwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let d = value.translation.height
                guard abs(d) > 30 else { return }
                withAnimation(.snappy(duration: 0.32)) {
                    setStage(d < 0 ? .large : .bar)
                }
            }
    }

    private func setStage(_ new: PanelStage) {
        if let panelStage { panelStage.wrappedValue = new; return }
        switch new {
        case .bar:    detent = Self.barDetent
        case .medium: detent = .medium
        case .large:  detent = .large
        }
    }

    /// Full-screen Hertzsprung–Russell diagram. Presented from THIS
    /// sheet (not MainView) because the search sheet is always up — a
    /// cover hung off the root would fight the active presentation.
    @State private var showHRDiagram = false

    /// Resting "search bar only" detent — the persistent always-present
    /// state, just tall enough for the field + grabber. Drag up (or focus
    /// the field) to reveal favourites, then results.
    private static let barDetent: PresentationDetent = .height(72)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Pure search — the camera controls moved to the
                // bottom-trailing capsule (CameraClusterCapsule), so the
                // bar has exactly one job.
                searchHeader

                // Dismiss — only once the surface is OPEN. Parked, the
                // bar is the app's resting state and there is nothing to
                // close, so the X earns its place only above the bar
                // detent; tapping it drops the keyboard, clears the
                // query and parks the sheet back down.
                //
                // The sheet gets the same button the iPad panel has: a
                // persistent sheet still needs a way OUT that isn't a
                // drag, and the two surfaces should close the same way.
                // Same 44pt glass circle the detail header dismisses
                // with, so every card in the app closes alike.
                if stage != .bar {
                    CircleIconButton(symbol: .xmark) { closeSearch() }
                        .transition(.scale.combined(with: .opacity))
                }

                // Hertzsprung–Russell diagram — full-screen star chart.
//                hrButton
            }
                .animation(.snappy(duration: 0.28), value: stage)
                // PANEL: the card's own handle supplies the top air, so the
                // field needs none, and 14 a side nests the 44pt capsule in
                // the card's corner (22 + 14 ≈ 37, the parked radius).
                //
                // SHEET: the phone's insets, untouched. It has no handle of
                // ours above the field — the SYSTEM draws the grabber — so
                // dropping the top padding here shoved the field under it
                // and left the trailing edge hanging.
                .padding(.leading,  isPanel ? 16 : 12)
                .padding(.trailing, isPanel ? 16 : 14)
                .padding(.top,      isPanel ?  0 : 18)
                .padding(.bottom,   isPanel ? 16 : 18)

            if searchText.isEmpty && stage != .bar {
                browseContent
            } else {
                resultsList
            }
        }
        // Persistent Apple-Maps-style bottom sheet: never fully
        // dismissed (it's the home of search) — swiping down parks it at
        // the bar-only detent instead. Selecting an object is what hides
        // it: `detailDestination` flips non-nil and MainView's derived
        // binding dismisses this in favour of the detail sheet.
        .modifier(SheetPresentation(active: !isPanel, detent: $detent))
        // Focusing the field (keyboard up) expands the surface so results
        // aren't buried under the keyboard at the bar stage.
        .onChange(of: searchFocused) { _, focused in
            if focused, stage == .bar { setStage(.large) }
        }
        // Typing from a parked surface should also lift it.
        .onChange(of: searchText) { _, text in
            if !text.isEmpty, stage == .bar { setStage(.medium) }
        }
        .fullScreenCover(isPresented: $showHRDiagram) {
            HRDiagramView()
        }
        .alert("Return to your location?",
               isPresented: Bindable(state)._compassReturnHomePrompt) {
            Button("Cancel", role: .cancel) { }
            Button("Switch to Here") { state.confirmReturnHomeAndEngageCompass() }
        } message: {
            Text(String(localized: "Compass mode orients the sky from where you're standing. Move the map back to your location?"))
        }
    }

    // MARK: Header

    // Persistent sheet → no dismiss X. The capsule fills the width; the
    // trailing clear-button appears only while there's text to clear.
    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(symbol: .search)
            TextField(String(localized: "Search the sky"), text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchFocused = false
                } label: {
                    Image(symbol: .xmarkCircleFill)
                }
                .buttonStyle(.plain)
            }
            
            
        }
//        .font(.callout)
        .padding(.horizontal, 18)
        // The panel's 44 is load-bearing — it is what nests the capsule in
        // the card's corner. The sheet keeps the 47 it always had.
        // `.containerRelative` had no container shape to resolve against
        // inside the panel and fell back to a rectangle, which is why the
        // field was never a capsule there.
        .frame(height: isPanel ? 44 : 47)
        .glassEffect(.regular.interactive(), in: .capsule)
        // Swipe the BAR to open the panel, tap it to type. Both, on the
        // same pixels: `simultaneousGesture` leaves the field's own tap
        // intact rather than consuming it, and the 12pt minimum keeps a
        // slightly-imprecise tap from reading as a swipe. Panel only — in
        // a sheet the system's detent drag owns this.
        .simultaneousGesture(panelSwipe, isEnabled: isPanel)
    }

    // MARK: Browse — what the sheet shows before a query

    // Chips choose a category; the list below leads with what's up now.
    // Recents take over only while the field is live and still empty.
    @ViewBuilder
    private var browseContent: some View {
        if searchFocused {
            recentSuggestions
        } else {
            VStack(spacing: 0) {
                chipRow
                browseList
            }
        }
    }

    /// Everything the browse lists know, for this moment and this place.
    private var catalog: SkyCatalog {
        SkyCatalog(date:       state.observationDate,
                   observer:   SatelliteSky.Observer(latitude:  state.origin.latitude.radians,
                                                     longitude: state.origin.longitude.radians),
                   favourites: state.favourites)
    }

    private var activeChip: BrowseChip { chosenChip ?? catalog.defaultChip }

    /// A scrolling row of capsule chips on material; the selected one is
    /// solid white with dark ink.
    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BrowseChip.allCases) { chip in
                    chipButton(chip)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .scrollClipDisabled()
    }

    private func chipButton(_ chip: BrowseChip) -> some View {
        let selected = chip == activeChip
        return Button { chosenChip = chip } label: {
            Text(chip.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.black : Color.primary)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background {
                    if selected { Capsule().fill(.white) }
                    else        { Capsule().fill(.regularMaterial) }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: selected)
    }

    /// The active chip's list: Up now, then Below the horizon.
    @ViewBuilder
    private var browseList: some View {
        let listing = catalog.listing(for: activeChip)
        if listing.isEmpty {
            browseEmptyNote(String(localized: "No favorites yet. Tap the heart on a star or a constellation to keep it here."))
            Spacer(minLength: 0)
        } else {
            List {
                if !listing.upNow.isEmpty {
                    Section {
                        ForEach(listing.upNow) { browseRow($0) }
                    } header: {
                        sectionTitle(String(localized: "Up now"), first: true)
                    }
                }
                if !listing.below.isEmpty {
                    Section {
                        ForEach(listing.below) { browseRow($0) }
                    } header: {
                        sectionTitle(String(localized: "Below the horizon"), first: listing.upNow.isEmpty)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // No list-owned air at the top or under headers: the chips'
            // bottom padding + the first title's inset set the gap, so it
            // matches the one between the search bar and the chips.
            .contentMargins(.top, 0, for: .scrollContent)
            .environment(\.defaultMinListHeaderHeight, 0)
            .id(activeChip)                     // each chip starts at the top
        }
    }

    /// Section title on the rows' own 16pt inset. The first sits close
    /// under the chips; a later one gets air above so it reads as a new
    /// group rather than a run-on.
    private func sectionTitle(_ text: String, first: Bool) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.secondary)
            .listRowInsets(.init(top: first ? 4 : 18, leading: 16, bottom: 6, trailing: 16))
    }

    private func browseRow(_ entry: SkyCatalog.Entry) -> some View {
        Button { open(entry.object) } label: {
            browseRowBody(for: entry)
        }
        .buttonStyle(.plain)
        .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowBackground(Color.clear)
    }

    /// Recents under a live, empty field — simple text, nothing else.
    /// No badge, no separators: this is a suggestion list the eye should
    /// skim past on its way to typing. An empty one draws NOTHING — a "no
    /// recents yet" note under a cursor is noise at the exact moment the
    /// user is already busy.
    @ViewBuilder
    private var recentSuggestions: some View {
        if !state.recentObjects.isEmpty {
            List(state.recentObjects) { obj in
                Button { open(obj) } label: {
                    Text(obj.displayName)
                        .font(.callout)
                        .fontDesign(.serif)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    /// One empty-state voice for the browse surface.
    private func browseEmptyNote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top,        4)
    }

    /// One browse row — badge, serif name, a line that says what the thing
    /// IS ("Red supergiant in Orion", "7 stars", a spacecraft's next pass),
    /// and, when it's up, how high: the figure you need to go and find it.
    private func browseRowBody(for entry: SkyCatalog.Entry) -> some View {
        HStack(spacing: 12) {
            resultIcon(for: entry.object)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.object.displayName)
                    .font(.callout)
                    .fontDesign(.serif)            // sky-object name → serif
                    .foregroundStyle(.primary)
                Text(catalog.subtitle(for: entry.object))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 8)
            if let degrees = entry.altitudeDegrees {
                Text(verbatim: "\(degrees)°")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }

    // MARK: Results

    private var resultsList: some View {
        List {
            if !solarResults.isEmpty {
                Section("Solar system") {
                    ForEach(solarResults) { obj in
                        resultRow(for: obj)
                    }
                }
            }
            if !spacecraftResults.isEmpty {
                Section("Spacecraft") {
                    ForEach(spacecraftResults) { obj in
                        resultRow(for: obj)
                    }
                }
            }
            if !constellationResults.isEmpty {
                Section("Constellations") {
                    ForEach(constellationResults) { obj in
                        resultRow(for: obj)
                    }
                }
            }
            if !starResults.isEmpty {
                Section("Stars") {
                    ForEach(starResults) { obj in
                        resultRow(for: obj)
                    }
                }
            }
            if solarResults.isEmpty
                && spacecraftResults.isEmpty
                && constellationResults.isEmpty
                && starResults.isEmpty {
                Section {
                    Text("No matches for \"\(searchText)\".")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func resultRow(for obj: SkyObject) -> some View {
        Button { open(obj) } label: {
            HStack(spacing: 12) {
                resultIcon(for: obj)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(obj.displayName)
                        .font(.callout)
                        .fontDesign(.serif)            // sky-object name → serif
                        .foregroundStyle(.primary)
                    Text(typeLabel(obj))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func resultIcon(for obj: SkyObject) -> some View {
        switch obj {
        case .star(let s):
            POILabelView(category: .followedStar(s), text: "", labelStyle: .star)
//            POIBadgeView(category: .followedStar(s), size: 22)
        case .sun:
            POILabelView(category: .sun, text: "", labelStyle: .star)
//            POIBadgeView(category: .sun, size: 22)
        case .moon:
            POILabelView(category: .moon, text: "",
                         phase: MoonPosition.phase(for: state.observationDate,
                                                       latitude: state.origin.latitude))
//            POIBadgeView(category: .moon, size: 22)
        case .planet(let p):
            POILabelView(category: .planet(p), text: "",
                         phase: BadgePhase.of(.planet(p), date: state.observationDate,
                                              latitude: state.origin.latitude))
//            POIBadgeView(category: .planet(p), size: 22)
        case .spacecraft(let c):
            POILabelView(category: .spacecraft(c), text: "")
        case .constellation(let c):
            Artist.shared.constellationFigure(c)
                .foregroundStyle(.secondary)
        }
    }

    private func typeLabel(_ obj: SkyObject) -> String {
        switch obj {
        case .star(let s):          return String(localized: "Star · \(s.constellation.localizedName)")
        case .sun:                  return String(localized: "Solar system · Star")
        case .moon:                 return String(localized: "Solar system · Moon")
        case .planet:               return String(localized: "Solar system · Planet")
        case .constellation:        return String(localized: "Constellation")
        case .spacecraft:           return String(localized: "Spacecraft")
        }
    }

    // MARK: Search execution

    private var query: String { searchText.lowercased() }

    private var solarResults: [SkyObject] {
        let all: [SkyObject] = [.sun, .moon] + Planet.all.map { .planet($0) }
        return all.filter { $0.searchTokens.contains(query) }
    }

    private var spacecraftResults: [SkyObject] {
        Spacecraft.allCases
            .map    { SkyObject.spacecraft($0) }
            .filter { $0.searchTokens.contains(query) }
    }

    private var constellationResults: [SkyObject] {
        Constellation.allCases
            .filter { $0 != .none }
            .map    { SkyObject.constellation($0) }
            .filter { $0.searchTokens.contains(query) }
            .sorted { $0.displayName < $1.displayName }
    }

    /// Hard cap the star list because there are ~hundreds of named
    /// stars and the list would otherwise wreck the sheet's
    /// scroll feel for a query like "a".
    private var starResults: [SkyObject] {
        let matches = StarDatabase.shared.listableStars
            .filter { $0.name != "Unknown" }
            .map    { SkyObject.star($0) }
            .filter { $0.searchTokens.contains(query) }
        return Array(matches.prefix(50))
    }

    // MARK: Actions

    /// Focus the canvas on `obj` (sets `detailDestination` and pans the
    /// camera). Setting `detailDestination` is what swaps this persistent
    /// search sheet out for the detail sheet — MainView's derived binding
    /// hides search the moment a selection exists. We just drop keyboard
    /// focus and reset the field so search returns clean on dismiss.
    private func open(_ obj: SkyObject) {
        searchFocused = false
        searchText = ""
        state.focus(on: obj)
    }
}

#if DEBUG
#Preview {
    SearchSheet()
        .environment(AppState())
}
#endif

// MARK: - SheetPresentation
// The sheet-only modifiers, applied as a group so panel mode can decline
// them wholesale. `presentationDetents` on a view that isn't a sheet's
// root is inert at best; keeping them behind one flag is clearer than a
// scatter of `if` in the body.
private struct SheetPresentation: ViewModifier {
    let active: Bool
    @Binding var detent: PresentationDetent

    func body(content: Content) -> some View {
        if active {
            content
                .presentationDetents([.height(72), .medium, .large], selection: $detent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled(true)
        } else {
            content
        }
    }
}
