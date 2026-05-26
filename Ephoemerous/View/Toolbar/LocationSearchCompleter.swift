import Foundation
import MapKit
import Observation

// MARK: - LocationSearchCompleter
// Thin `@Observable` wrapper around `MKLocalSearchCompleter`. SwiftUI
// can't bind to the delegate-based MapKit API directly, so we forward
// the query through `MKLocalSearchCompleter` and republish the results
// as an `[MKLocalSearchCompletion]` array the panel can iterate.
//
// `.address` is the only result type — astronomy locations are cities,
// villages, mountain peaks, observatories, named geographic features.
// Skipping `.pointOfInterest` keeps the suggestion list focused
// (no coffee shops competing with "Cambridge").
@Observable
@MainActor
final class LocationSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {

    /// Live autocomplete suggestions for the current `query`.
    private(set) var suggestions: [MKLocalSearchCompletion] = []

    /// The user's typed query string. Set this and `suggestions` updates
    /// asynchronously via the delegate callback.
    var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                suggestions = []
                completer.cancel()
            } else {
                completer.queryFragment = query
            }
        }
    }

    private let completer: MKLocalSearchCompleter

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.resultTypes = .address
        self.completer.delegate    = self
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let next = completer.results
        Task { @MainActor in self.suggestions = next }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter,
                               didFailWithError error: any Error) {
        Task { @MainActor in self.suggestions = [] }
    }

    // MARK: - Resolving a suggestion → coordinate

    /// Run an `MKLocalSearch` against the picked completion and return
    /// the coordinate of the top map item, or `nil` if the search has
    /// no usable result.
    func resolve(_ completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        let search  = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first?.placemark.coordinate
        } catch {
            return nil
        }
    }
}
