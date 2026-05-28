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

    @Environment(EAppState.self) private var state

    @State private var completer = LocationSearchCompleter()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var centerCoordinate: CLLocationCoordinate2D = .init(latitude: 0, longitude: 0)
    @State private var searchFieldFocused: Bool = false

    /// Panel height. Matches the "fills the bottom third" intent —
    /// just enough room for the map to be useful without burying the
    /// canvas. Tunable.
    private let mapHeight: CGFloat = 280

    var body: some View {
        VStack(spacing: 8) {
            searchField

            if !completer.suggestions.isEmpty {
                suggestionList
            } else {
                mapView
            }
            actionRow
            
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.clear,
                     in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            // Seed the camera at the current observer location so the
            // picker opens "where you are now."
            cameraPosition = .region(MKCoordinateRegion(
                center: currentObserverCoordinate,
                span:   MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)))
            centerCoordinate = currentObserverCoordinate
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search a place",
                      text: Binding(get: { completer.query },
                                    set: { completer.query = $0 }))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !completer.query.isEmpty {
                Button {
                    completer.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical,    9)
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
        }
        .frame(height: mapHeight)
    }

    // MARK: - Map

    private var mapView: some View {
        ZStack {
            Map(position: $cameraPosition)
                .onMapCameraChange(frequency: .continuous) { ctx in
                    centerCoordinate = ctx.camera.centerCoordinate
                }
                .clipShape(RoundedRectangle(cornerRadius: 22,
                                            style: .continuous))

            // Fixed centred crosshair — whatever's under it is the
            // candidate location.
            crosshair
                .allowsHitTesting(false)
        }
        .frame(height: mapHeight)
    }

    private var crosshair: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.85), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            Circle()
                .fill(.primary.opacity(0.85))
                .frame(width: 4, height: 4)
            Rectangle()
                .fill(.primary.opacity(0.85))
                .frame(width: 1, height: 32)
            Rectangle()
                .fill(.primary.opacity(0.85))
                .frame(width: 32, height: 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 2)
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 8) {
            // "Here": snap to device location. Disabled when the
            // observer is already within ~111 km of the device fix
            // (the tolerance `state.isAtDeviceLocation` already uses
            // elsewhere) — tapping there would be a no-op.
            Button {
                state.goToDeviceLocation()
                state.isShowingLocationPicker = false
            } label: {
                Text("Here")
//                Label("Here", systemImage: "location.fill")
                    .font(.callout.weight(.medium))
                    .contentShape(Capsule())
            }
            .buttonStyle(.glass)
            .disabled(state.isAtDeviceLocation)

            Spacer()

            // Coordinate readout — what "Set" will commit to.
            Text(coordinateLabel)
                .font(.subheadline.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .shadow(radius: 2)
                .lineLimit(1)

            Spacer()

            // "Travel": commit the map's centre as the new origin.
            // Disabled when the map is already centred on the
            // current origin (panning hasn't moved it). Tolerance
            // ~0.001° (≈ 110 m) lets onMapCameraChange noise pass
            // without spuriously enabling the button.
            Button {
                commitCenter()
            } label: {
                Text("Travel")
                    .font(.callout.weight(.semibold))
                    .contentShape(Capsule())
            }
            .buttonStyle(.glassProminent)
            .disabled(centerMatchesOrigin)
        }
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

#Preview {
    LocationPickerPanel()
        .environment(EAppState())
        .padding()
}
