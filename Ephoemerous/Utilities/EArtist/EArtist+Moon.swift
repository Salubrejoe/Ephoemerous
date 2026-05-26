import SwiftUI

// MARK: - Moon
// The Moon is a layered illustration: a soft radial-gradient glow
// behind a dark body, a clipped lit crescent whose width tracks the
// illumination fraction, and a thin rim outline. In NS mode the Moon
// also picks up a breathing-ring tap affordance on top.
extension EArtist {

    var moonBodyColor : Color { .gray.opacity(0.55) }

    func drawMoon(at sc: CGPoint, fraction: Double, showRing: Bool,
                  in dc: inout EGraphicContext) {
        let baseRadius = 4.0
        let glowRadius = baseRadius * AstroConstants.moonGlowRatio

        // Glow.
        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - glowRadius, y: sc.y - glowRadius,
                                   width: glowRadius * 2, height: glowRadius * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(AstroConstants.moonGlowOpacity * fraction), location: 0),
                    .init(color: .white.opacity(0),                                         location: 1)
                ]),
                center: sc, startRadius: 0, endRadius: glowRadius
            )
        )

        // Dark body.
        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - baseRadius, y: sc.y - baseRadius,
                                   width: baseRadius * 2, height: baseRadius * 2)),
            with: .color(moonBodyColor)
        )

        // Lit crescent — clipped to the body so it never spills past.
        let shift = baseRadius * CGFloat(1.0 - 2.0 * fraction)
        var clipped = dc.ctx
        clipped.clip(to: Path(ellipseIn: CGRect(x: sc.x - baseRadius, y: sc.y - baseRadius,
                                                width: baseRadius * 2, height: baseRadius * 2)))
        clipped.fill(
            Path(ellipseIn: CGRect(x: sc.x - baseRadius + shift, y: sc.y - baseRadius,
                                   width: baseRadius * 2, height: baseRadius * 2)),
            with: .color(.white.opacity(AstroConstants.moonLimbOpacity))
        )

        // Rim.
        dc.ctx.stroke(
            Path(ellipseIn: CGRect(x: sc.x - baseRadius, y: sc.y - baseRadius,
                                   width: baseRadius * 2, height: baseRadius * 2)),
            with: .color(.white.opacity(AstroConstants.moonRimOpacity)),
            lineWidth: 0.5
        )

        // NS-only tap affordance.
        if showRing {
            drawBreathingRing(at:     sc,
                              radius: baseRadius + breathRingGap,
                              color:  .white,
                              time:   dc.animationTime,
                              in:     &dc)
        }
    }
}
