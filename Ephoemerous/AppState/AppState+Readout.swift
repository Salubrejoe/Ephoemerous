import Foundation
import SwiftUI

// MARK: - AppState + Readout
// The scene readout — where and when the sky is being watched from — as
// words, plus the two "drifted" flags the go-back chips key on. Lives on
// the state rather than in `MainToolbar` because two surfaces speak it:
// the Here / Now capsule, and iPhone Duo's side rail (`SkyRail`), where the
// same words become the items' titles.
extension AppState {

    // MARK: Labels

    /// Locality label, three tiers from terse to verbose:
    ///   • observer is at the device's current fix → "Here"
    ///   • locality name resolved by the geocoder   → that name
    ///   • neither                                  → "lat°/lon°"
    /// The "Here" override mirrors the date pill's "Now" — when the
    /// observation matches the device's real-world state right now,
    /// the pill says so directly instead of repeating the resolved
    /// city name.
    var placeLabel: String {
        if isAtDeviceLocation { return String(localized: "Here") }
        if let name = localityName, !name.isEmpty {
            return name
        }
        let lat    = origin.latitude.degrees
        let lon    = origin.longitude.degrees
        let latStr = String(format: "%.1f°%@", abs(lat), lat >= 0 ? "N" : "S")
        let lonStr = String(format: "%.1f°%@", abs(lon), lon >= 0 ? "E" : "W")
        return "\(latStr)  \(lonStr)"
    }

    /// Four tiers, from terse to verbose:
    ///   • observation within 60 s of real now → "Now"
    ///   • today                               → "HH:mm"
    ///   • same year, other day                → "d MMM HH:mm"
    ///   • other year                          → "d MMM yyyy HH:mm"
    /// The 60-second window matches `DatePickerPanel`'s Now-button
    /// disabled threshold so the pill says "Now" exactly when the
    /// Now button is greyed out.
    var timeLabel: String {
        let date = observationDate
        if abs(date.timeIntervalSinceNow) < 60 { return String(localized: "Now") }

        let cal = Calendar.current
        let format: String
        if cal.isDateInToday(date) {
            format = "HH:mm"
        } else if cal.component(.year, from: date)
                    == cal.component(.year, from: .now) {
            format = "d MMM HH:mm"
        } else {
            format = "d MMM yyyy HH:mm"
        }
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date)
    }

    // MARK: Reset conditions

    /// True when the observer has been moved off the device's real fix —
    /// and we actually have a fix to return to — so the "back to Here"
    /// chip is worth showing.
    var isAwayFromHere: Bool {
        LocationService.shared.location != nil && !isAtDeviceLocation
    }

    /// True when the observation time is more than a minute off real now,
    /// so the "back to Now" chip shows. Same 60 s rule as the pill's "Now"
    /// label and the date picker's Now button.
    var isAwayFromNow: Bool {
        abs(observationDate.timeIntervalSinceNow) >= 60
    }

    /// Back to the real present — the "back to Now" chip's job.
    func returnToNow() {
        commitPickedObservationDate(.now)
    }

    // MARK: Locality

    /// Stable id for `.task(id:)` — re-fires the geocode only when the
    /// origin shifts by more than 0.1° (~11 km), so a per-frame slerp
    /// doesn't queue up dozens of geocodes.
    var localityKey: String {
        String(format: "%.1f,%.1f",
               origin.latitude.degrees,
               origin.longitude.degrees)
    }

    /// Clear the stale name immediately so the label falls back to
    /// coordinates, let a slerp settle for 400 ms, then geocode. Run from
    /// `.task(id: localityKey)`, whose cancel-and-restart is the debounce.
    func refreshLocalityAfterSettling() async {
        localityName = nil
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        await refreshLocalityName()
    }
}
