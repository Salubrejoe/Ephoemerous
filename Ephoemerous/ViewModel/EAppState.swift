import SwiftUI
import CoreLocation
import Observation
import CoreGraphics
import simd


@Observable
class EAppState {
    
    var selectedStar: EStar?
    
    var origin : Origin
    var plane  : Plane
    
    init() {
        self.origin = .init()
        self.plane  = .init()
    }
    
    var nsProjection: ENSProjection {
        ENSProjection(siderealOffset: precessedSiderealOffset)
    }
    
    var projectionMode: ProjectionMode = .coupled
    
    var isEditingDate: Bool = false

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




struct Origin {
    var latitude : Angle = .degrees(51)
    var longitude: Angle = .zero
}

struct Plane {
    var latitude : Angle = .degrees(51+180)
    var longitude: Angle = .zero

    
}
