import Foundation
import SwiftUI

// MARK: - AppState + Locality
// Asynchronous reverse-geocode of the observer origin to a locality
// name (city / town / region). Called from MainToolbar via a
// `.task(id: roundedCoord)` so it re-runs only when the rounded
// origin actually changes — slerps mid-transition don't spam Apple's
// geocoder.
extension AppState {

    /// Refresh `localityName` to the best-effort name for the current
    /// origin. Cached inside `LocalityResolver` so repeated calls at
    /// the same rounded coordinate are free. Failures are silent; the
    /// toolbar falls back to coordinates whenever `localityName` is
    /// nil.
    func refreshLocalityName() async {
        let lat  = origin.latitude.degrees
        let lon  = origin.longitude.degrees
        let name = await LocalityResolver.shared.resolve(lat: lat, lon: lon)
        localityName = name
    }
}
