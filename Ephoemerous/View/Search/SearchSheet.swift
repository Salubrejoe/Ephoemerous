import SwiftUI
import LoreKit

// MARK: - SearchSheet
// Apple-Maps-flavoured search surface that opens from the bottom-
// right search icon in MainView. Layout:
//
//   ┌────────────────────────────────────────────────────────┐
//   │  🔍 Search a star, constellation…         ⓧ       ✕   │
//   ├────────────────────────────────────────────────────────┤
//   │  AT REST — the remembered set, A–Z, badge + portrait   │
//   │   ☆ Betelgeuse      Red supergiant in Orion            │
//   │   ✧ Ursa Minor      7 stars                            │
//   ├────────────────────────────────────────────────────────┤
//   │  FIELD LIVE, still empty — recents, as plain text      │
//   │     Betelgeuse                                         │
//   │     Cassiopeia                                         │
//   ├────────────────────────────────────────────────────────┤
//   │  TEXT TYPED — results, sectioned by species            │
//   │   • Sun                                                │
//   │   • …                                                  │
//   └────────────────────────────────────────────────────────┘
//
// Three states, one surface, no chrome to switch between them. The
// remembered set is what the sheet IS at rest, so it wears no label
// and has no competition. Recents surface only under a live cursor —
// the moment they are actually useful — and stay deliberately quiet.
//
// Tapping any row — remembered, recent or result — focuses the
// canvas on that object and dismisses the sheet; the existing
// `detailDestination` flow then brings up the matching detail card.
struct SearchSheet: View {

    @Environment(AppState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool
    @State private var detent: PresentationDetent = Self.barDetent

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
                .padding(.leading,  isPanel ? 14 : 12)
                .padding(.trailing, isPanel ? 14 : 14)
                .padding(.top,      isPanel ?  0 : 18)
                .padding(.bottom,   isPanel ? 14 : 18)

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
            TextField(String(localized: "Search, remember..."), text: $searchText)
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

    // The idle sheet has ONE list, and it is the remembered set. No tab
    // bar, no segmented control: the thing you kept is the thing the
    // sheet is for, so it needs no label and no competition.
    //
    // Recents are not gone, they are DEMOTED — they surface only once
    // the field is live (focused, still empty), as quiet text under the
    // cursor. That is the moment recents are actually useful ("take me
    // back to where I was") and the only moment they earn the space;
    // at rest they were furniture.
    @ViewBuilder
    private var browseContent: some View {
        if searchFocused {
            recentSuggestions
        } else {
            favouritesList
        }
    }

    /// The remembered set, in the plain-list dress: badge + serif name,
    /// no inset card. The sheet is already a material surface, and
    /// `.insetGrouped` laid a SECOND card on top of it — that doubled
    /// edge is what read heavy.
    @ViewBuilder
    private var favouritesList: some View {
        if favouriteCards.isEmpty {
            browseEmptyNote(String(localized: "Nothing remembered yet. Tap the heart on a star or a constellation to keep it."))
        } else {
            List(favouriteCards) { obj in
                Button { open(obj) } label: {
                    browseRowBody(for: obj)
                }
                .buttonStyle(.plain)
                .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    /// Recents under a live, empty field — simple text, nothing else.
    /// No badge, no separators: this is a suggestion list the eye should
    /// skim past on its way to typing, not content competing with the
    /// remembered set. An empty one draws NOTHING — a "no recents yet"
    /// note under a cursor is noise at the exact moment the user is
    /// already busy.
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

    // MARK: The remembered set

    /// Stars + constellations only. Those are the two species the
    /// favourites system is for — the things that change in the sky, or
    /// carry a story you return to. Solar-system bodies are never
    /// favouritable (no heart on their detail views), so this filter is
    /// belt-and-braces against anything stale in the stored set.
    private var favouriteCards: [SkyObject] {
        state.favourites
            .filter(isRememberable)
            .sorted(by: alphabetically)
    }

    private func isRememberable(_ obj: SkyObject) -> Bool {
        switch obj {
        case .star, .constellation: return true
        default:                    return false
        }
    }

    /// A to Z across the whole set, species ignored — stars and
    /// constellations interleave. Grouping by kind would make the user
    /// remember which bucket a name lives in before they can find it,
    /// and the list is short enough that one run beats two.
    /// `localizedStandardCompare` so accented names sort where a reader
    /// expects rather than after Z.
    private func alphabetically(_ a: SkyObject, _ b: SkyObject) -> Bool {
        a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
    }

    /// One remembered row — badge, name, and a line that says what the
    /// thing IS: "Red supergiant in Orion", "7 stars".
    ///
    /// Note this is NOT the old "STAR · ORION" caption coming back.
    /// That one restated the badge in capitals; `portrait` carries
    /// something the row cannot otherwise show, in a reading voice
    /// rather than a metadata voice. Search results keep the terse
    /// caption — there you are scanning strangers and want the species
    /// fast; here you are picking something you already chose to keep.
    private func browseRowBody(for obj: SkyObject) -> some View {
        HStack(spacing: 12) {
            resultIcon(for: obj)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(obj.displayName)
                    .font(.callout)
                    .fontDesign(.serif)            // sky-object name → serif
                    .foregroundStyle(.primary)
                Text(obj.portrait)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
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
