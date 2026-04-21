
import SwiftUI


extension Angle {
    
    init(hours h: Double, minutes m: Double = 0, seconds s: Double = 0) {
        self = .degrees((h + m / 60.0 + s / 3_600.0) * 15.0)
    }
    
    static var pi: Angle {
        .radians(.pi)
    }
    
    static var twoPi: Angle {
        .radians(.pi * 2)
    }
    
    static var piHalf: Angle {
        .radians(.pi * 0.5)
    }
    
    static var earthTilt: Angle {
        .degrees(23.44)
    }
    
    static func spherePoint(latitude lat: Angle, longitude lon: Angle) -> SIMD3<Double> {
        SIMD3(
            cos(lat.radians) * cos(lon.radians),
            cos(lat.radians) * sin(lon.radians),
            sin(lat.radians)
        )
    }
}

extension Double {
    static var twoPi: Double {
        (.pi * 2)
    }
    
    static var piHalf: Double {
        (.pi * 0.5)
    }
    
    static var piThird: Double {
        (.pi * 0.33)
    }
    
    static var piSixth: Double {
        (.pi * 0.15)
    }
}
