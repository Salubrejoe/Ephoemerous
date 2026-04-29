
import SwiftUI


extension Angle {
    
    init(hours h: Double, minutes m: Double = 0, seconds s: Double = 0) {
        self = .degrees((h + m / AstroConstants.minutesPerDegree + s / AstroConstants.secondsPerDegree) * AstroConstants.degreesPerHour)
    }
    
    func hoursMinSec() -> (hours: Double, minutes: Double, seconds: Double) {
        let hour = (self.degrees / AstroConstants.degreesPerHour).rounded(.down)
        let minute = (self.degrees.truncatingRemainder(dividingBy: AstroConstants.degreesPerHour) * AstroConstants.minutesPerDegree).rounded()
        let second = ((self.degrees.truncatingRemainder(dividingBy: 1.0) * 3600.0).truncatingRemainder(dividingBy: 60.0)).rounded()
        return (hour, minute, second)
    }
    
    static let goldenHor    : Angle = .radians(0.1)
    static let horizon      : Angle = .zero
    static let civil        : Angle = .radians(-0.1)
    static let naval        : Angle = .radians(-0.2)
    static let astronomical : Angle = .radians(-AstroConstants.civilTwilightRad)
    
    static let sunsets: [Angle] = [
        .goldenHor,
        .horizon,
        .civil,
        .naval,
        .astronomical,
    ]
    
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
        .degrees(AstroConstants.obliquity.degrees)
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
