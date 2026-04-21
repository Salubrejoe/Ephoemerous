import SwiftUI
import CoreLocation
import Observation
import CoreGraphics
import simd


@Observable
class EAppState {
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
