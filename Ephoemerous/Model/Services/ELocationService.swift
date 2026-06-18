import CoreLocation
import Observation

@Observable
final class ELocationService: NSObject, CLLocationManagerDelegate {

    static let shared = ELocationService()

    private let manager = CLLocationManager()
    private(set) var location:   CLLocation?              = nil
    /// Latest compass heading + accuracy from CoreLocation. `nil`
    /// until the device delivers its first fix; `headingAccuracy`
    /// stays negative while the magnetometer is uncalibrated, so
    /// consumers should check `>= 0` before trusting the value.
    private(set) var heading:    CLHeading?               = nil
    private(set) var authStatus: CLAuthorizationStatus    = .notDetermined

    private override init() {
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Heading is degree-resolution; the default 1° filter is
        // exactly what the user-location puck wants.
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func requestIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        ELogger.location("ELocationService error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
