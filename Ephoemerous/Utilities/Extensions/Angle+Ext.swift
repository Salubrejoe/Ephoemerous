import SwiftUI

// MARK: - Angle (astronomy)
// Domain-coupled extensions on `Angle` — initialisers and statics that
// reference `AstroConstants` (degrees-per-hour, obliquity) or carry
// celestial semantics (twilight horizons, parallel rosters).
//
// The pure-math members (`.pi`, `.twoPi`, `.piHalf`, `.pi(over:)`,
// `spherePoint(latitude:longitude:)`, `hmsString` / `dmsString`) live in
// LoreKit's `Angle+Math.swift`. Anything astronomy-specific stays here.
extension Angle {

    init(hours h: Double, minutes m: Double = 0, seconds s: Double = 0) {
        self = .degrees(
            (h + m / AstroConstants.minutesPerDegree
               + s / AstroConstants.secondsPerDegree)
            * AstroConstants.degreesPerHour
        )
    }

    func hoursMinSec() -> (hours: Double, minutes: Double, seconds: Double) {
        let hour   = (self.degrees / AstroConstants.degreesPerHour).rounded(.down)
        let minute = (self.degrees.truncatingRemainder(dividingBy: AstroConstants.degreesPerHour) * AstroConstants.minutesPerDegree).rounded()
        let second = ((self.degrees.truncatingRemainder(dividingBy: 1.0) * 3600.0).truncatingRemainder(dividingBy: 60.0)).rounded()
        return (hour, minute, second)
    }

    // MARK: Twilight horizons (sun altitude conventions)

    static let goldenHor    : Angle = .radians(0.1)
    static let horizon      : Angle = .radians(0)
    static let civil        : Angle = .radians(-0.1)
    static let naval        : Angle = .radians(-0.2)
    static let astronomical : Angle = .radians(-0.31)

    static let sunsets: [Angle] = [
        .goldenHor,
        .horizon,
        .civil,
        .naval,
        .astronomical,
    ]

    static let parallels: [Angle] = [
        .degrees(-89.99),
        .degrees(-80), .degrees(-70), .degrees(-60), .degrees(-50),
        .degrees(-40), .degrees(-30), .degrees(-20), .degrees(-10),
        .degrees(0.0),
        .degrees(10),  .degrees(20),  .degrees(30),  .degrees(40),
        .degrees(50),  .degrees(60),  .degrees(70),  .degrees(80),
        .degrees(89.99),
    ]

    static var earthTilt: Angle {
        .degrees(AstroConstants.obliquity.degrees)
    }
}
