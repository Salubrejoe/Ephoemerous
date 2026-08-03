import SwiftUI
import MapKit
import CoreLocation
import LoreKit

// MARK: - LocationPickerPanel
// Inline location picker that springs up above MainToolbar. A SwiftUI
// `Map` fills most of the panel with a centred crosshair; whatever's
// under the crosshair when the user taps "Set" becomes the new
// observer origin (animated via `animateOrigin`).
//
// A search field above the map drives an `MKLocalSearchCompleter`;
// suggestions resolve via `MKLocalSearch` and pan the camera to the
// chosen place. "Here" snaps to the device's CoreLocation fix.
//
// The picker doesn't touch `state.origin` until the user explicitly
// confirms — panning the map alone never moves the observer. This
// keeps the canvas behind from morphing every time the user nudges
// the map.
struct LocationPickerPanel: View {

    @Environment(AppState.self) private var state

    @State private var completer = LocationSearchCompleter()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var centerCoordinate: CLLocationCoordinate2D = .init(latitude: 0, longitude: 0)
    /// Drives the map → suggestion-list swap. Bound to the search field
    /// via `.focused`, so tapping the field reveals the suggestions over
    /// the map and dismissing the keyboard returns to the map.
    @FocusState private var searchFocused: Bool

    /// Show the suggestion list (over the map) while the user is in
    /// search mode: field focused, or there are live suggestions to act
    /// on even after the keyboard dropped.
    private var isSearching: Bool {
        searchFocused || !completer.suggestions.isEmpty
    }

    var body: some View {
        ZStack {
            // The map IS the background — fills the whole sheet.
            mapView
            // Suggestion list covers the map (on a material) while
            // searching; the map stays mounted underneath so returning
            // from search doesn't re-seed the camera.
            if isSearching {
                suggestionList
                    .background(.regularMaterial)
            }

            // Floating chrome: header pinned top, Travel + search pinned
            // bottom. Sits above both map and suggestions.
            VStack(spacing: 10) {
                sheetHeader
                Spacer()
                // Commit the panned-to centre as the new origin. Shown
                // only once the map has actually moved off the current
                // origin, and hidden while searching (the list owns the
                // screen then).
                if !centerMatchesOrigin && !isSearching {
                    travelButton
                }
                searchField
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Seed the camera at the current observer location so the
            // picker opens "where you are now."
            cameraPosition = .region(MKCoordinateRegion(
                center: currentObserverCoordinate,
                span:   MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)))
            centerCoordinate = currentObserverCoordinate
        }
    }

    // MARK: - Travel

    /// Commit the map's centre as the new observer origin. Full-width
    /// glass-prominent capsule sitting just above the search field.
    private var travelButton: some View {
        Button {
            commitCenter()
        } label: {
            Text("Travel")
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .contentShape(Capsule())
        }
        .buttonStyle(.glassProminent)
    }

    // MARK: - Sheet header

    /// Title + close X — shared shape with `DatePickerPanel.sheetHeader`
    /// so the two scene editors read as one family. Commit actions
    /// (Here / Travel) stay in the bottom action row; this header only
    /// titles and dismisses.
    private var sheetHeader: some View {
        HStack(spacing: 12) {
            Button {
                state.goToDeviceLocation()
                state.isShowingLocationPicker = false
            } label: {
                Text("Here")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical,   2)
            }
            .disabled(state.isAtDeviceLocation)
            .frame(width: 100, alignment: .leading)
            .buttonStyle(.glass)
            
            Spacer()
            
            Text(coordinateLabel)
                .font(.footnote.monospacedDigit())
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer()
            
            CircleIconButton(symbol: .xmark, action: {
                state.isShowingLocationPicker = false
            })
            .frame(width: 100, alignment: .trailing)
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(symbol: .search)
            TextField("Search a place",
                      text: Binding(get: { completer.query },
                                    set: { completer.query = $0 }))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
            if !completer.query.isEmpty {
                Button {
                    completer.query = ""
                } label: {
                    Image(symbol: .xmarkCircleFill)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical,    9)
        .background(
            Capsule().fill(.clear).glassEffect(.clear.interactive())
        )
    }

    private var suggestionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(completer.suggestions, id: \.self) { suggestion in
                    Button {
                        Task { await jump(to: suggestion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical,   8)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.4)
                }
            }
            // Top inset clears the floating header; bottom clears the
            // floating search field so the list never hides under them.
            .padding(.top, 56)
            .padding(.bottom, 72)
            .padding(.horizontal, 10)
        }
    }

    // MARK: - Map

    /// Fills the whole sheet as the background. Crosshair marks the
    /// candidate location; the floating Travel button (in `body`)
    /// commits whatever's under it.
    private var mapView: some View {
        Map(position: $cameraPosition)
            .onMapCameraChange(frequency: .continuous) { ctx in
                centerCoordinate = ctx.camera.centerCoordinate
            }
            .ignoresSafeArea()
            .mapStyle(.imagery)
            .overlay {
                // Fixed centred crosshair — whatever's under it is the
                // candidate location.
                crosshair
                    .allowsHitTesting(false)
            }
    }

    private var crosshair: some View {
        // The 12-point horizon scallop — the app's signature silhouette
        // (shared with the user puck + horizon rim) instead of a generic
        // ring, so the aim reticle reads as Ephoemerous's own. Corner /
        // bulge come from Artist so it can never drift from the real rim.
        let artist = Artist.shared
        return ZStack {
            Squircle(corners: artist.horizonBumpCorners,
                     bulge:   artist.horizonBumpBulge)
                .stroke(Color.systemBackground, lineWidth: 2.5)
                .frame(width: 26, height: 26)
                .shadow(color: .primary, radius: 6)
//            Circle()
//                .fill(.primary.opacity(0.85))
//                .frame(width: 4, height: 4)
//            Rectangle()
//                .fill(.primary.opacity(0.85))
//                .frame(width: 1, height: 32)
//            Rectangle()
//                .fill(.primary.opacity(0.85))
//                .frame(width: 32, height: 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 2)
    }


    /// `true` when the map's centre coordinate is essentially the
    /// current observer origin — no panning has happened, so the
    /// Travel button would commit no change.
    private var centerMatchesOrigin: Bool {
        let dLat = abs(centerCoordinate.latitude  - state.origin.latitude.degrees)
        let dLon = abs(centerCoordinate.longitude - state.origin.longitude.degrees)
        return dLat < 0.001 && dLon < 0.001
    }

    // MARK: - Helpers

    private var currentObserverCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude:  state.origin.latitude.degrees,
                               longitude: state.origin.longitude.degrees)
    }

    private var coordinateLabel: String {
        let lat = centerCoordinate.latitude
        let lon = centerCoordinate.longitude
        return String(format: "%.2f°%@  %.2f°%@",
                      abs(lat), lat >= 0 ? "N" : "S",
                      abs(lon), lon >= 0 ? "E" : "W")
    }

    private func jump(to suggestion: MKLocalSearchCompletion) async {
        guard let coord = await completer.resolve(suggestion) else { return }
        // Drop the keyboard + clear suggestions so the map (now panned
        // to the pick) is revealed for confirmation via Travel.
        searchFocused = false
        completer.query = ""
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            span:   MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)))
        centerCoordinate = coord
    }

    private func commitCenter() {
        state.animateOrigin(to:  .degrees(centerCoordinate.latitude),
                            lon: .degrees(centerCoordinate.longitude))
        state.isShowingLocationPicker = false
    }
}

#if DEBUG
#Preview {
    LocationPickerPanel()
        .environment(AppState())
        .padding()
}
#endif
