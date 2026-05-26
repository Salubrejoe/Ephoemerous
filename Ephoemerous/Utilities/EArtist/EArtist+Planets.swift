import SwiftUI

// MARK: - Planets
// Each planet is a filled disc whose radius reads its base magnitude
// (smaller = dimmer), surrounded by a soft radial-gradient glow in the
// planet's tinted colour. Labels are drawn to the right of the disc
// when the layer asks for them.
extension EArtist {

    var planetLabelSize   : Double      { 8.0 }
    var planetLabelWeight : Font.Weight { .medium }
    var planetGlowOpacity : Double      { 0.35 }
    var planetGlowRatio   : Double      { 3.0 }

    func planetRadius(_ planet: EPlanet) -> CGFloat {
        CGFloat(max(AstroConstants.planetDotMinR,
                    (AstroConstants.planetDotScale - planet.baseMagnitude) * AstroConstants.planetDotFactor)) / 2
    }

    func drawPlanet(_ planet: EPlanet, at sc: CGPoint, showLabel: Bool,
                    in dc: inout EGraphicContext) {
        let r     = planetRadius(planet)
        let glowR = r * planetGlowRatio

        // Glow.
        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - glowR, y: sc.y - glowR,
                                   width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: planet.color.opacity(planetGlowOpacity), location: 0),
                    .init(color: planet.color.opacity(0),                 location: 1)
                ]),
                center: sc, startRadius: 0, endRadius: glowR))

        // Body.
        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r,
                                   width: r * 2, height: r * 2)),
            with: .color(planet.color))

        // Label.
        if showLabel {
            dc.ctx.draw(
                Text(planet.name)
                    .font(.system(size: planetLabelSize, weight: planetLabelWeight))
                    .foregroundStyle(planet.color.opacity(0.8)),
                at:     CGPoint(x: sc.x + r + 4, y: sc.y),
                anchor: .leading
            )
        }
    }
}
