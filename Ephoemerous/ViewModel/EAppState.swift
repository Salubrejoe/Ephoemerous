import SwiftUI
import CoreLocation
import Observation
import CoreGraphics
import simd


@Observable
class EAppState {
    var _dateTransition: EDateTransition? = nil
    enum ProjectionFrame {
        case northSouth
        case userLocation
    }
    
    var selectedStars: [EStar] = [] {
        didSet {
            let names = selectedStars.map(\.name).joined(separator: ", ")
            ELogger.selectedStars("selection changed (\(selectedStars.count)) → [\(names)]")
            ECloudSync.shared.saveSelectedStars(selectedStars)
        }
    }
    var showSunInfo:  Bool = false
    var showMoonInfo: Bool = false
    var showStarList: Bool = false
    var sunScreenPosition:         CGPoint? = nil
    var selectedStarPositions:    [String: CGPoint] = [:]
    var canvasSize:         CGSize   = .zero
    var moonScreenPosition: CGPoint? = nil
    
    var origin : Origin
    var plane  : Plane
    
    init() {
        self.origin = .init()
        self.plane  = .init()
    }
    
    var projectionMode: ProjectionMode = .coupled
    
    var isShowingDatePicker: Bool = false
    var magnitudeFilter: Double = 5.5
    var stars: [EStar] {
        let zenith = observerZenith // SIMD3<Double>, expected to be unit length
        return StarDatabase.shared.workableStars
            .filter { s in
            // Precess RA/Dec to the observation date
            let precessed = EPrecession.precess(
                ra: s.rightAscension,
                dec: s.declination,
                to: observationDate
            )
            // Convert to a unit vector in the same frame as observerZenith
            let starVec = Angle.spherePoint(
                latitude: precessed.dec,
                longitude: precessed.ra
            )
            // Above horizon if dot(star, zenith) > 0
            return simd_dot(starVec, zenith) > 0.0
        }
            .filter {
                $0.name != "Unknown"
            }
            .filter {
                $0.magnitude < magnitudeFilter
            }
    }
    
    var scale:  Double  = 50.0
    var offset: CGPoint = .init(x: -80, y: 0)
    
    var observationDate: Date    = .now
    var animationTime: Double    = 0.0

    // Backing store for the running preset transition (set by EViewPreset extension)
    var _activeTransition: EPresetTransition? = nil
    
    var originVector: SIMD3<Double> {
        Angle.spherePoint(latitude: origin.latitude, longitude: origin.longitude)
    }
    var planeVector: SIMD3<Double> {
        Angle.spherePoint(latitude: plane.latitude, longitude: plane.longitude)
    }
    
    var precessedSiderealOffset: Angle {
        -EPrecession.gmstSiderealOffset(for: renderedObservationDate)
    }
    
    var observerZenith: SIMD3<Double> {
        let lst = EPrecession.lst(
            for: renderedObservationDate,
            longitude: origin.longitude
        )
        return Angle.spherePoint(latitude: origin.latitude, longitude: lst)
    }
    
    func setOrigin(lat: Angle, lon: Angle) {
        origin.latitude  = lat
        origin.longitude = lon
        if projectionMode == .coupled {
            plane.latitude = -lat
            plane.longitude = lon + Angle.pi
        }
    }
    
    // MARK: - Recently viewed
    
    private(set) var recentStars: [EStar] = []

    func setRecentStars(_ stars: [EStar]) { recentStars = stars }
    
    func recordViewed(_ star: EStar) {
        var updated = recentStars.filter { $0.id != star.id }
        updated.insert(star, at: 0)
        if updated.count > 5 { updated = Array(updated.prefix(5)) }
        recentStars = updated
        ECloudSync.shared.saveRecentStars(updated)
    }
}

enum ProjectionMode: String, CaseIterable {
    case coupled = "Coupled"
    case origin  = "Origin"
    //    case plane   = "Plane"
    
    var symbol: String {
        switch self {
        case .coupled: "globe"
        case .origin:   "figure.walk.motion"
            //            case .plane:    "figure.climbing"
        }
    }
}




struct Origin: Equatable {
    var latitude : Angle = .degrees(51)
    var longitude: Angle = .zero
}

struct Plane: Equatable {
    var latitude : Angle = .degrees(51+180)
    var longitude: Angle = .zero
}

// MARK: - Observation date animation
extension EAppState {

    struct EDateTransition {
        let fromInterval: TimeInterval
        let toInterval:   TimeInterval
        let startTime:    Double
        let duration:     Double

        func interpolated(at time: Double) -> Date {
            let raw = (time - startTime) / duration
            let t   = max(0, min(1, raw))
            // Smooth step -- no overshoot, sky rotation looks odd with bounce
            let st  = t * t * (3 - 2 * t)
            return Date(timeIntervalSinceReferenceDate: fromInterval + (toInterval - fromInterval) * st)
        }

        func isFinished(at time: Double) -> Bool {
            time >= startTime + duration
        }
    }

    

    // Every canvas layer should read this instead of observationDate directly.
    var renderedObservationDate: Date {
        guard let t = _dateTransition else { return observationDate }
        if t.isFinished(at: animationTime) {
            _dateTransition = nil
            return observationDate
        }
        return t.interpolated(at: animationTime)
    }

    // Call instead of setting observationDate directly when you want animation.
    func setObservationDate(_ newDate: Date, animated: Bool = true) {
        guard animated else { observationDate = newDate; return }
        _dateTransition = EDateTransition(
            fromInterval: renderedObservationDate.timeIntervalSinceReferenceDate,
            toInterval:   newDate.timeIntervalSinceReferenceDate,
            startTime:    animationTime,
            duration:     0.7
        )
        observationDate = newDate
    }
}
