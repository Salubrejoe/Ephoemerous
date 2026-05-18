import SwiftUI
import CoreLocation

// MARK: - EAppState + Location
// Device-location adoption and animated observer moves. The raw CoreLocation
// plumbing lives in ELocationService; this turns it into observer intent.
extension EAppState {

    /// Adopt the device's first location fix as the observer origin — once.
    /// Later fixes (or a user who has already moved) are ignored. Replaces
    /// the brittle `origin == .init()` guard and the duplicate seeding that
    /// used to live in both EAppState.init() and EphoemerousApp.
    func adoptInitialDeviceLocation(_ location: CLLocation) {
        guard !_didAdoptDeviceLocation else { return }
        _didAdoptDeviceLocation = true
        setOrigin(lat: .degrees(location.coordinate.latitude),
                  lon: .degrees(location.coordinate.longitude))
    }

    /// Animate the observer to the device's current location, briefly
    /// coupling the projection. If no fix is available yet, ask for one.
    func goToDeviceLocation() {
        guard let coordinate = ELocationService.shared.location?.coordinate else {
            ELocationService.shared.requestIfNeeded()
            return
        }
        useCoupledProjectionTemporarily(for: 0.7) {
            animateOrigin(to: .degrees(coordinate.latitude),
                          lon: .degrees(coordinate.longitude))
        }
    }

    /// True when the observer origin is within 1° of the device location.
    var isAtDeviceLocation: Bool {
        guard let c = ELocationService.shared.location?.coordinate else { return false }
        return abs(origin.latitude.degrees  - c.latitude)  < 1.0
            && abs(origin.longitude.degrees - c.longitude) < 1.0
    }

    /// Authorised, but still waiting for the first fix.
    var isAcquiringLocation: Bool {
        let auth       = ELocationService.shared.authStatus
        let authorised = auth == .authorizedWhenInUse || auth == .authorizedAlways
        return authorised && ELocationService.shared.location == nil
    }
}

// MARK: - EOriginTransition
// Smooth-stepped animated move of the observer origin. Read each frame by
// the canvas while in flight.
struct EOriginTransition {
    let fromLat:   Double
    let fromLon:   Double
    let toLat:     Double
    let toLon:     Double
    let startTime: Double
    let duration:  Double

    private static func smoothStep(_ t: Double) -> Double {
        let t = max(0, min(1, t))
        return t * t * (3 - 2 * t)
    }

    func interpolated(at time: Double) -> (lat: Double, lon: Double) {
        let t = Self.smoothStep((time - startTime) / duration)
        return (fromLat + (toLat - fromLat) * t,
                fromLon + (toLon - fromLon) * t)
    }

    func isFinished(at time: Double) -> Bool {
        time >= startTime + duration
    }
}

extension EAppState {

    func animateOrigin(to lat: Angle, lon: Angle, duration: Double = 0.6) {
        _originTransition = EOriginTransition(
            fromLat:   origin.latitude.radians,
            fromLon:   origin.longitude.radians,
            toLat:     lat.radians,
            toLon:     lon.radians,
            startTime: Date.now.timeIntervalSinceReferenceDate,
            duration:  duration
        )
    }
}
