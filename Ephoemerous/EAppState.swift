import SwiftUI
import CoreLocation
import Observation
import CoreGraphics
import simd


@Observable
class EAppState {
    
    var _dateTransition: EDateTransition? = nil
    var _originTransition: EOriginTransition? = nil
    
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
    
    var origin  : Origin
    var plane   : Plane
    
    init() {
        self.origin   = .init()
        self.plane    = .init()
    }
    
    // MARK: - Layer visibility
    var showEquatorTropics  : Bool = true
    var showEcliptic        : Bool = true
    var showNSMeridians     : Bool = true
    var showULMeridians     : Bool = true
    var showHorizon         : Bool = true
    var showStars           : Bool = true
    var showPlanets         : Bool = true
    var showSelectedStars   : Bool = true
    var appMode: EAppMode          = .clock
    var projectionMode: ProjectionMode = .drag
    
    var isShowingDatePicker: Bool = false
    var magnitudeFilter: Double = AstroConstants.defaultMagCap
    
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
    
    var currentlyDisplayedStar: EStar?
    var currentlyDisplayedConstellation: EConstellation?
    
    var scale:  Double  = AstroConstants.defaultScale
    var offset: CGPoint = .init(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY)
    
    var observationDate: Date    = .now
    var animationTime: Double    = 0.0

    // Backing store for the running preset transition (set by EViewPreset extension)
    var _activeTransition: EPresetTransition? = nil
    
    // In .origin mode both projections move their origin with the observer, planes stay fixed.
    var northSouthOrigin: SIMD3<Double> { .north }

    var originVector: SIMD3<Double> {
        Angle.spherePoint(latitude: origin.latitude, longitude: origin.longitude)
    }

    var planeVector: SIMD3<Double> {
        Angle.spherePoint(latitude: plane.latitude, longitude: plane.longitude)
    }
    
    // LST = GMST + longitude -- the sidereal phase at the observer location
    var localSiderealOffset: Angle {
        -EPrecession.lst(for: renderedObservationDate, longitude: origin.longitude)
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
            plane.latitude  = -lat
            plane.longitude = lon + Angle.pi
        }
    }
    
    // MARK: - Recently viewed
    
    private(set) var recentStars: [EStar] = []

    func setRecentStars(_ stars: [EStar]) { recentStars = stars }
    
    func recordViewed(_ star: EStar) {
        var updated = recentStars.filter { $0.id != star.id }
        updated.insert(star, at: 0)
        if updated.count > 10 { updated = Array(updated.prefix(10)) }
        recentStars = updated
        ECloudSync.shared.saveRecentStars(updated)
    }
}


enum ProjectionMode: String, CaseIterable {
    case drag    = "drag"
    case coupled = "coupled"
    case origin  = "origin"
    
    var symbol: String {
        switch self {
        case .drag:    return "arrow.up.and.down.and.arrow.left.and.right"
        case .coupled: return "arcade.stick.and.arrow.up.and.arrow.down"
        case .origin:  return "figure.walk.motion"
        }
    }
    
    var color: Color {
        switch self {
        case .drag:    return .primary
        case .coupled: return .baseOrange
        case .origin:  return .baseCoral
        }
    }
}
enum EAppMode {
    case clock, travel
    
    mutating func toggle() {
        self = self == .clock ? .travel: .clock
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
            startTime:    Date.now.timeIntervalSinceReferenceDate,
            duration:     0.7
        )
        observationDate = newDate
    }
}
