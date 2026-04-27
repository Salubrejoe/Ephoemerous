import SwiftUI
import CoreLocation
import Observation
import CoreGraphics
import simd


@Observable
class EAppState {
    
    enum ProjectionFrame {
        case northSouth
        case userLocation
    }
    
    var selectedStars: [EStar] = []
    var showSunInfo:  Bool = false
    var showMoonInfo: Bool = false
    var showStarList: Bool = false
    var sunScreenPosition:  CGPoint? = nil
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
    
    var originVector: SIMD3<Double> {
        Angle.spherePoint(latitude: origin.latitude, longitude: origin.longitude)
    }
    var planeVector: SIMD3<Double> {
        Angle.spherePoint(latitude: plane.latitude, longitude: plane.longitude)
    }
    
    var precessedSiderealOffset: Angle {
        -EPrecession.gmstSiderealOffset(for: observationDate)
    }
    
    var observerZenith: SIMD3<Double> {
        let lst = EPrecession.lst(
            for: observationDate,
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
    
    private(set) var recentStars: [EStar] = {
        guard let ids = UserDefaults.standard.array(forKey: "recentStarIDs") as? [String]
        else { return [] }
        let all = StarDatabase.shared.workableStars
        return ids.compactMap { id in all.first { $0.id.uuidString == id } }
    }()
    
    func recordViewed(_ star: EStar) {
        var updated = recentStars.filter { $0.id != star.id }
        updated.insert(star, at: 0)
        if updated.count > 5 { updated = Array(updated.prefix(5)) }
        recentStars = updated
        UserDefaults.standard.set(updated.map { $0.id.uuidString }, forKey: "recentStarIDs")
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
