import SwiftUI

// MARK: - User-location puck
// Apple-Maps-style "you are here" rendering for the celestial
// canvas. Anchored at the projection's zenith (= the observer's
// point of view in the planetarium), with an optional heading
// cone whose width tracks the compass's reported accuracy.
//
// `drawUserLocationPuck(at:in:)` paints the disc + ring.
// `drawHeadingCone(at:heading:accuracy:in:)` paints the fan
// behind the disc.
extension EArtist {

    // MARK: - Tunables  ▼ TWEAK HERE ▼

    /// Diameter of the inner blue disc (pt).
    var userPuckDiscRadius : CGFloat { 6 }
    /// White ring thickness around the disc.
    var userPuckRingWidth  : CGFloat { 2 }

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

    // MARK: - Drawing

    /// Blue filled disc on a white ring — the classic Maps puck.
    func drawUserLocationPuck(at sc: CGPoint, in dc: inout EGraphicContext) {
        let inner = userPuckDiscRadius
        let outer = inner + userPuckRingWidth

        // White outer ring (drawn first so the disc sits on top).
        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - outer, y: sc.y - outer,
                                   width: 2 * outer, height: 2 * outer)),
            with: .color(userPuckRingColor)
        )
        // Blue disc.
        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - inner, y: sc.y - inner,
                                   width: 2 * inner, height: 2 * inner)),
            with: .color(userPuckDiscColor)
        )
    }

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
