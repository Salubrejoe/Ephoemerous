
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
    
    static let goldenHor    : Angle = .radians(-0.1)
    static let horizon      : Angle = .radians(0)
    static let civil        : Angle = .radians(0.1)
    static let naval        : Angle = .radians(0.2)
    static let astronomical : Angle = .radians(AstroConstants.civilTwilightRad)
//    static let userLocation : Angle = .radians(1.45)
    
    static let sunsets: [Angle] = [
        .goldenHor,
        .horizon,
        .civil,
        .naval,
        .astronomical,
//        .degrees(15),
//        .degrees(30),
//        .degrees(45),
//        .degrees(60),
//        .degrees(75),
//        .userLocation
    ]
    
    static let parallels: [Angle] = [
        .degrees(-89.99),
        .degrees(-80),
        .degrees(-70),
        .degrees(-60),
        .degrees(-50),
        .degrees(-40),
        .degrees(-30),
        .degrees(-20),
        .degrees(-10),
        .degrees(0.0),
        .degrees(10),
        .degrees(20),
        .degrees(30),
        .degrees(40),
        .degrees(50),
        .degrees(60),
        .degrees(70),
        .degrees(80),
        .degrees(89.99),
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
    
    // HMS / DMS string formatting
    var hmsString: String {
        let t = radians * (12.0 / Double.pi) * 3600
        let h = Int(t / 3600)
        let m = Int(t.truncatingRemainder(dividingBy: 3600) / 60)
        let s = t.truncatingRemainder(dividingBy: 60)
        return String(format: "%02dh %02dm %05.2fs", h, m, s)
    }
    var dmsString: String {
        let d = degrees; let sign = d >= 0 ? "+" : "-"
        let a = Swift.abs(d); let dd = Int(a)
        let mm = Int((a - Double(dd)) * 60)
        let ss = (a - Double(dd) - Double(mm) / 60) * 3600
        return String(format: "%@%02d° %02d′ %05.2f″", sign, dd, mm, ss)
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
