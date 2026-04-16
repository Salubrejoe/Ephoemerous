import Foundation
import CoreLocation
import Observation
import CoreGraphics
import simd

@Observable
class EAppState {

    var originLat: Double =  0.0
    var originLon: Double =  Double.pi
    var planeLat:  Double =  0.0
    var planeLon:  Double =  0.0
    var projectionMode: ProjectionMode = .coupled
    
    var isEditingDate: Bool = false

    var scale:  Double  = 100.0
    var offset: CGPoint = .zero

    var observationDate: Date    = .now
    var location: CLLocation     = CLLocation(latitude: 51, longitude: 0.0)

    var originVector: SIMD3<Double> {
        EProjection.spherePoint(lat: originLat, lon: originLon)
    }
    var planeVector: SIMD3<Double> {
        EProjection.spherePoint(lat: planeLat, lon: planeLon)
    }
    var siderealOffset: Double {
        ECalAndTransManager.siderealOffset(for: observationDate)
    }
    var observerZenith: SIMD3<Double> {
        let lst = ECalAndTransManager.lst(
            for: observationDate,
            longitude: location.coordinate.longitude
        )
        let lat = location.coordinate.latitude * Double.pi / 180.0
        return EProjection.spherePoint(lat: lat, lon: lst)
    }

    func setOrigin(lat: Double, lon: Double) {
        originLat = lat
        originLon = lon
        if projectionMode == .coupled {
            planeLat = -lat
            planeLon = lon + Double.pi
        }
    }
    
    struct GridState {
        let O: SIMD3<Double>
        let P: SIMD3<Double>
        let θ: Double
    }
    
    var gridState: GridState {
        GridState(
            O: originVector,
            P: planeVector,
            θ: siderealOffset
        )
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
