import SwiftUI

// MARK: - User-location puck
// Apple-Maps-style "you are here" rendering for the celestial
// canvas. Anchored at the projection's zenith (= the observer's
// point of view in the planetarium), with an optional heading
// cone whose width tracks the compass's reported accuracy.
//
// The puck DISC + RING is now a SwiftUI overlay
// (`UserLocationPuck` → `SquircleGlobePuck`), positioned at zenith
// in `CelestialCanva`. This extension keeps the heading cone
// (procedural canvas draw) and palette tunables, and exposes the
// longitude-keyed globe-symbol picker for the overlay.
extension EArtist {

    // MARK: - Tunables  ▼ TWEAK HERE ▼

    /// Total puck diameter in pt for the SwiftUI overlay.
    /// `SquircleGlobePuck` uses this as its `size`.
    var userPuckSize       : CGFloat { 28 }

    var userPuckDiscColor  : Color { palette.userPuckDisc }
    var userPuckRingColor  : Color { palette.userPuckRing }
    var userPuckConeColor  : Color { palette.userPuckCone }

    /// Outer reach of the heading cone, in points. The cone fades
    /// to transparent at this radius via a radial gradient.
    var userPuckConeRadius : CGFloat { 90 }
    /// Cone opacity at the apex; the gradient falls off to zero
    /// at the outer edge.
    var userPuckConeOpacity: Double  { 0.32 }
    /// Clamp the cone half-angle so an uncalibrated compass
    /// (huge `headingAccuracy`) doesn't blanket the whole canvas
    /// in blue, and a flawless one doesn't shrink to a sliver.
    var userPuckConeMinHalfAngle: Double { 8 }    // degrees
    var userPuckConeMaxHalfAngle: Double { 60 }   // degrees

    // MARK: - Symbol picker

    /// Apple's four hemisphere globe SF Symbols, mapped to the
    /// observer's longitude so the puck wears the continent it
    /// actually sits on. Bands chosen to match the symbol's
    /// rendered emphasis:
    ///   • -170° .. -30°  →  `globe.americas.fill`
    ///   • -30°  ..  60°  →  `globe.europe.africa.fill`
    ///   •  60°  .. 110°  →  `globe.central.south.asia.fill`
    ///   • 110°  .. 180°  →  `globe.asia.australia.fill`
    ///   • -180° .. -170° →  `globe.asia.australia.fill`  (dateline wrap)
    /// Input is wrapped into [-180, 180] before bucketing.
    func userLocationGlobeSymbol(forLongitude lon: Double) -> String {
        var l = lon
        while l >  180 { l -= 360 }
        while l < -180 { l += 360 }

        if l >= -30 && l <  60  { return "globe.europe.africa.fill"      }
        if l >=  60 && l < 110  { return "globe.central.south.asia.fill" }
        if l >= 110 || l < -170 { return "globe.asia.australia.fill"     }
        return "globe.americas.fill"  // -170° ≤ l < -30°
    }

    // MARK: - Drawing

    /// Heading fan — a wedge centred on the compass `heading`
    /// (degrees clockwise from true north) whose half-angle is
    /// `accuracy`, clamped to a usable range. On the planetarium
    /// chart, north sits at the top of the screen and east on the
    /// left; the wedge respects that orientation.
    func drawHeadingCone(at sc:    CGPoint,
                         heading:  Double,
                         accuracy: Double,
                         in dc:    inout EGraphicContext) {
        let halfAngleDeg = max(userPuckConeMinHalfAngle,
                               min(userPuckConeMaxHalfAngle, accuracy))
        let halfAngle    = halfAngleDeg * .pi / 180.0
        let headingRad   = heading      * .pi / 180.0
        let r            = userPuckConeRadius

        // Build the wedge as a fan of triangles from the apex.
        var path = Path()
        path.move(to: sc)
        let steps = 32
        for i in 0...steps {
            let t     = Double(i) / Double(steps)
            let angle = headingRad - halfAngle + 2 * halfAngle * t
            // North (h=0) → screen up (-y). East (h=π/2) → screen
            // left (-x) because the planetarium chart mirrors
            // compass east to the left side.
            let dx = -sin(angle) * r
            let dy = -cos(angle) * r
            path.addLine(to: CGPoint(x: sc.x + dx, y: sc.y + dy))
        }
        path.closeSubpath()

        dc.ctx.fill(
            path,
            with: .radialGradient(
                Gradient(colors: [
                    userPuckConeColor.opacity(userPuckConeOpacity),
                    userPuckConeColor.opacity(0)
                ]),
                center:      sc,
                startRadius: 0,
                endRadius:   r
            )
        )
    }
}
