import SwiftUI
import simd

struct EArtist {
    static let shared = EArtist()

    // MARK: - Grid
    let color      : Color  = .baseSlate.opacity(0.5)
    let width      : Double = 0.5
    let thickWidth : Double = 1.0

    // MARK: - Ecliptic
    let eclColor : Color  = .secondary.opacity(0.1)
    let eclWidth : Double = 16.0

    // MARK: - Meridians
    let nsMeridianColor   : Color  = .primary
    let nsMeridianOpacity : Double = 0.1
    let nsMeridianStep    : Double = 1.0
    let ulMeridianColor   : Color  = .primary
    let ulMeridianOpacity : Double = 0.1
    let ulMeridianStep    : Double = 1.0

    func meridianColor(mode: EProjection.ProjectionFrame) -> Color {
        mode == .northSouth ? nsMeridianColor.opacity(nsMeridianOpacity)
                            : ulMeridianColor.opacity(ulMeridianOpacity)
    }
    func meridianStep(mode: EProjection.ProjectionFrame) -> Double {
        mode == .northSouth ? nsMeridianStep : ulMeridianStep
    }

    // MARK: - Horizon
    let horizonFillColor   : Color  = .primary.opacity(0.4)
    let sunsetStrokeColor  : Color  = .baseOrange
    let sunsetStrokeWidth  : Double = 1.0

    // MARK: - Tap affordance (breathing ring)
    let breathPeriod     : Double  = 11.0   // seconds per full crisp→blur→crisp cycle
    let breathRingGap    : CGFloat = 3.0    // gap between body edge and the ring
    let breathRingWidth  : CGFloat = 1.5    // stroke width when in focus
    let breathMaxBlur    : Double  = 6.0    // blur radius at the defocused peak
    let breathMinOpacity : Double  = 0.16   // alpha when fully blurred
    let breathMaxOpacity : Double  = 0.50   // alpha when crisp / well-defined

    /// A proper, well-defined ring that slowly defocuses into a soft glow
    /// and sharpens back — a mix of a static ring and a breathing halo.
    /// Phase uses (1 − cos)/2 so the cycle begins and ends fully crisp.
    /// Driven off the canvas clock, so it costs ~nothing.
    func drawBreathingRing(at sc: CGPoint, radius: CGFloat, color: Color,
                           time t: Double, in dc: inout EGraphicContext) {
        let phase   = 0.5 - 0.5 * cos(2 * .pi * t / breathPeriod)   // 0 crisp → 1 blurred → 0
        let blur    = breathMaxBlur * phase
        let opacity = breathMaxOpacity - (breathMaxOpacity - breathMinOpacity) * phase
        let ring    = Path(ellipseIn: CGRect(x: sc.x - radius, y: sc.y - radius,
                                             width: radius * 2, height: radius * 2))
        var layer = dc.ctx
        if blur > 0.01 { layer.addFilter(.blur(radius: blur)) }
        layer.stroke(ring, with: .color(color.opacity(opacity)), lineWidth: breathRingWidth)
    }

    // MARK: - Sun
    let sunColor      : Color  = .yellow.opacity(0.8)
    let sunGlowBlur   : Double = 1.2   // multiplier on disc radius

    func drawSun(at sc: CGPoint, in dc: inout EGraphicContext) {
        let r    = 8.0
        let disc = Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r, width: 2*r, height: 2*r))
        var glow = dc.ctx
        glow.addFilter(.brightness(1))
        glow.addFilter(.blur(radius: r * sunGlowBlur))
        glow.fill(disc, with: .color(sunColor))
        var disco = dc.ctx
        disco.addFilter(.brightness(0.7))
        disco.fill(disc, with: .color(sunColor))
//        dc.ctx.fill(disc, with: .color(sunColor))
        drawBreathingRing(at: sc,
                          radius: r + breathRingGap,
                          color:  .yellow,
                          time:   dc.state.animationTime,
                          in:     &dc)
    }

    // MARK: - Moon
    let moonBodyColor  : Color  = .gray.opacity(0.55)

    func drawMoon(at sc: CGPoint, fraction: Double, showRing: Bool, in dc: inout EGraphicContext) {
        let baseRadius = 4.0
        let glowRadius = baseRadius * AstroConstants.moonGlowRatio

        // Glow
        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - glowRadius, y: sc.y - glowRadius,
                                   width: glowRadius * 2, height: glowRadius * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(AstroConstants.moonGlowOpacity * fraction), location: 0),
                    .init(color: .white.opacity(0), location: 1)
                ]),
                center: sc, startRadius: 0, endRadius: glowRadius
            )
        )
        // Dark body
        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - baseRadius, y: sc.y - baseRadius,
                                   width: baseRadius * 2, height: baseRadius * 2)),
            with: .color(moonBodyColor)
        )
        // Lit crescent
        let shift = baseRadius * CGFloat(1.0 - 2.0 * fraction)
        var clipped = dc.ctx
        clipped.clip(to: Path(ellipseIn: CGRect(x: sc.x - baseRadius, y: sc.y - baseRadius,
                                                width: baseRadius * 2, height: baseRadius * 2)))
        clipped.fill(
            Path(ellipseIn: CGRect(x: sc.x - baseRadius + shift, y: sc.y - baseRadius,
                                   width: baseRadius * 2, height: baseRadius * 2)),
            with: .color(.white.opacity(AstroConstants.moonLimbOpacity))
        )
        // Rim
        dc.ctx.stroke(
            Path(ellipseIn: CGRect(x: sc.x - baseRadius, y: sc.y - baseRadius,
                                   width: baseRadius * 2, height: baseRadius * 2)),
            with: .color(.white.opacity(AstroConstants.moonRimOpacity)),
            lineWidth: 0.5
        )
        // NS-only tap affordance
        if showRing {
            drawBreathingRing(at: sc,
                              radius: baseRadius + breathRingGap,
                              color:  .white,
                              time:   dc.state.animationTime,
                              in:     &dc)
        }
    }

    // MARK: - Planets
    let planetLabelSize   : Double = 8.0
    let planetLabelWeight : Font.Weight = .medium
    let planetGlowOpacity : Double = 0.35
    let planetGlowRatio   : Double = 3.0

    func planetRadius(_ planet: EPlanet) -> CGFloat {
        CGFloat(max(AstroConstants.planetDotMinR,
                    (AstroConstants.planetDotScale - planet.baseMagnitude) * AstroConstants.planetDotFactor)) / 2
    }

    func drawPlanet(_ planet: EPlanet, at sc: CGPoint, showLabel: Bool, in dc: inout EGraphicContext) {
        let r     = planetRadius(planet)
        let glowR = r * planetGlowRatio

        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - glowR, y: sc.y - glowR, width: glowR*2, height: glowR*2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: planet.color.opacity(planetGlowOpacity), location: 0),
                    .init(color: planet.color.opacity(0),                 location: 1)]),
                center: sc, startRadius: 0, endRadius: glowR))

        dc.ctx.fill(
            Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r, width: r*2, height: r*2)),
            with: .color(planet.color))

        if showLabel {
            dc.ctx.draw(
                Text(planet.name)
                    .font(.system(size: planetLabelSize, weight: planetLabelWeight))
                    .foregroundStyle(planet.color.opacity(0.8)),
                at: CGPoint(x: sc.x + r + 4, y: sc.y), anchor: .leading)
        }
    }

    // MARK: - Selected stars
    let selectedStarRingRadius      : CGFloat = 6.0
    let constellationStarRingRadius : CGFloat = 4.5
    let constellationStarRingWidth  : CGFloat = 0.75
    let starLabelOffset             : CGPoint = CGPoint(x: 12, y: -4)
    let starLabelOpacity            : Double  = 0.9

    func drawSelectedStar(_ star: EStar, at sc: CGPoint,
                          isSelected: Bool, isCurrentlyDisplayed: Bool,
                          showLabel: Bool, in dc: inout EGraphicContext) {
        // User-selected stars get the breathing ring (the old static ring is
        // gone). Constellation members keep a plain identity ring — it's
        // their only marker, and breathing a dense constellation would shimmer.
        if isSelected {
            drawBreathingRing(at: sc,
                              radius: selectedStarRingRadius + breathRingGap,
                              color:  star.spectralClass.color,
                              time:   dc.state.animationTime,
                              in:     &dc)
        } else {
            let r    = constellationStarRingRadius
            let ring = Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r,
                                              width: r * 2, height: r * 2))
            dc.ctx.stroke(ring, with: .color(star.spectralClass.color.opacity(0.4)),
                          lineWidth: constellationStarRingWidth)
        }

        if dc.state.renderedScale > 100 {
            let font: Font = isCurrentlyDisplayed ? .body.weight(.heavy) : .footnote.weight(.light)
            dc.ctx.draw(
                Text(star.displayName)
                    .font(font)
                    .foregroundStyle(star.spectralClass.color.opacity(starLabelOpacity)),
                at: CGPoint(x: sc.x + starLabelOffset.x, y: sc.y + starLabelOffset.y),
                anchor: .leading
            )
        }
    }

    // MARK: - Watch crown
    let crownBorderColor : Color  = .primary
    let crownBorderWidth : Double = 2.0

    // Clip disc + bezel trick (shared by the sky clip, sky background,
    // crown and pan bounds — single source of truth).
    //   • clipRadius  — disc radius in NS projection units (dec −30°)
    //   • clipBleed   — px clipped past the disc so the rim is real
    //                   content, not a jagged clip seam
    //   • bezelWidth  — background-tinted ring laid over the old edge;
    //                   (clipBleed − bezelWidth) px of content peeks past it
    //   • hourRingGap — gap from the disc to the hour-number midline
    let clipRadius  : Double = 2 * sqrt(3)
    let clipBleed   : Double = 8
    let bezelWidth  : Double = 4
    let hourRingGap : Double = 20

    // MARK: - Stars
    func starPointFallsWithinMarigin(_ screenPoint: CGPoint, in dc: EGraphicContext, margin: Double = 20) -> Bool {
        screenPoint.x > -margin &&
        screenPoint.x < dc.size.width  + margin &&
        screenPoint.y > -margin &&
        screenPoint.y < dc.size.height + margin
    }

    func starRadius(_ star: EStar, in dc: EGraphicContext) -> Double {
        let ra    = star.rightAscension.radians
        let dec   = star.declination.radians
        let phase   = ra * AstroConstants.twinklePhaseRA + dec * AstroConstants.twinklePhaseDec + .random(in: -1...1)
        let twinkle = 1.0 + AstroConstants.twinkleAmplitude * sin(dc.state.animationTime * AstroConstants.twinkleFrequency + phase)
        let returned = max(AstroConstants.dotMinRadius, (AstroConstants.dotScale - star.magnitude) * AstroConstants.dotFactor) * twinkle
        
        return returned
    }

    func drawStar(_ star: EStar, at sc: CGPoint, in dc: inout EGraphicContext) {
        let r = starRadius(star, in: dc) * 0.5
        var glow = dc.ctx
        glow.addFilter(.blur(radius: r * AstroConstants.starGlowBlurRatio/3))
        glow.fill(
            Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r, width: r * 2, height: r * 2)),
            with: .color(star.spectralClass.color.opacity(0.5))
        )
        dc.fillDot(at: sc, radius: r, color: star.spectralClass.color)
//        dc.fillDot(at: sc, radius: r, color: .secondary)
        
    }
}
