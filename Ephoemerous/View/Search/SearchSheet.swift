import SwiftUI
import LoreKit

// MARK: - SearchSheet
// Apple-Maps-flavoured search surface that opens from the bottom-
// right search icon in MainView. Layout:
//
//   ┌────────────────────────────────────────────────────────┐
//   │  🔍 Search a star, constellation…         ⓧ       ✕   │
//   ├────────────────────────────────────────────────────────┤
//   │  FAVOURITES                                            │
//   │  [Star] [Const] [Star] [Const] [Star]  →               │
//   ├────────────────────────────────────────────────────────┤
//   │  (when search text is non-empty)                       │
//   │  RESULTS                                               │
//   │   • Sun                                                │
//   │   • Sirius                                             │
//   │   • …                                                  │
//   └────────────────────────────────────────────────────────┘
//
// The horizontal-scroll favourites row uses the shared
// `StarCard` / `ConstellationCard` from
// `ViewComponents/FavouriteCards.swift`. Tapping any favourite card
// — or any result row — focuses the canvas on that object and
// dismisses the sheet; the existing `detailDestination` flow then
// brings up the matching detail card.
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

                // Dismiss — only once the card is OPEN, and only in the
                // panel. Parked, the bar is the app's resting state and
                // there is nothing to close; in the sheet the search is
                // persistent by design and has never worn an X. The same
                // 44pt glass circle the detail header dismisses with, so
                // the two cards close the same way.
                if isPanel && stage != .bar {
                    CircleIconButton(symbol: .xmark) { closeSearch() }
                        .transition(.scale.combined(with: .opacity))
                }

                // Hertzsprung–Russell diagram — full-screen star chart.
//                hrButton
            }
                .animation(.snappy(duration: 0.28), value: stage)
                // Even inset all round — the concentricity depends on it.
                .padding(.horizontal, 18)
                .padding(.vertical,   18)

            if searchText.isEmpty && stage != .bar {
                // Idle browse state: favourites scroll + recents list,
                // Apple-Maps style. Scrolls as one when the sheet is
                // dragged up to medium / large.
                
                
//                Text(String(localized: "REMEMBERED"))
//                    .font(.default.weight(.semibold))
//                    .foregroundStyle(.gray)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.leading, 32)
//                    .padding(.top, 24)
                favouritesSection
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                
                List {
                    Section("RECENTS") {
                        if !state.recentObjects.isEmpty {
                            ForEach(Array(state.recentObjects.enumerated()), id: \.element.id) { idx, obj in
                                Button { open(obj) } label: {
                                    Text(obj.displayName)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
//                .listStyle(.plain)
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
        // 44 in an 80pt card with an 18pt inset all round is EXACTLY
        // concentric: the outer capsule's radius is 40, the inner's 22,
        // and 22 + 18 = 40. `.containerRelative` had no container shape to
        // resolve against inside the panel and fell back to a rectangle.
        .frame(height: 44)
        .glassEffect(.regular.interactive(), in: .capsule)
        // Swipe the BAR to open the panel, tap it to type. Both, on the
        // same pixels: `simultaneousGesture` leaves the field's own tap
        // intact rather than consuming it, and the 12pt minimum keeps a
        // slightly-imprecise tap from reading as a swipe. Panel only — in
        // a sheet the system's detent drag owns this.
        .simultaneousGesture(panelSwipe, isEnabled: isPanel)
    }

    // MARK: Favourites scroll

    /// Star + Constellation favourites only — the two card species
    /// the user spec'd. Solar-system favourites are stored on
    /// `state.favourites` but don't have a card form yet (they're
    /// always present on the canvas anyway).
    private var favouriteCards: [SkyObject] {
        state.favourites.filter {
            switch $0 {
            case .star, .constellation: return true
            default:                    return false
            }
        }
    }

    private var favouritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            if favouriteCards.isEmpty {
                Text("No favourites yet. Tap the heart on a star or constellation to add it.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(favouriteCards) { obj in
                            cardView(for: obj)
                                .onTapGesture { open(obj) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func cardView(for obj: SkyObject) -> some View {
        switch obj {
        case .star(let s):          StarCard(star: s)
        case .constellation(let c): ConstellationCard(constellation: c)
        default:                    EmptyView()
        }
    }


    /// One recents row — icon + name + type, mirroring `resultRow` but
    /// laid out for the inset card (its own padding, no List chrome).
    private func recentRowBody(for obj: SkyObject) -> some View {
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
        .padding(.horizontal, 12)
        .padding(.vertical,   10)
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
                         moonPhase: MoonPosition.phase(for: state.observationDate,
                                                       latitude: state.origin.latitude))
//            POIBadgeView(category: .moon, size: 22)
        case .planet(let p):
            POILabelView(category: .planet(p), text: "")
//            POIBadgeView(category: .planet(p), size: 22)
        case .constellation(let c):
            Image(symbol: Artist.shared.constellationEntitySymbol(
                Artist.shared.constellationEntity(of: c)
            ))
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
        }
    }

    // MARK: Search execution

    private var query: String { searchText.lowercased() }

    private var solarResults: [SkyObject] {
        let all: [SkyObject] = [.sun, .moon] + Planet.all.map { .planet($0) }
        return all.filter { $0.searchTokens.contains(query) }
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
