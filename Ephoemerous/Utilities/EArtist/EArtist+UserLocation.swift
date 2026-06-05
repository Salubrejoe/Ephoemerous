import SwiftUI
import LoreKit

// MARK: - User-location puck
// Apple-Maps-style "you are here" rendering for the celestial
// canvas. Anchored at the projection's zenith (= the observer's
// point of view in the planetarium), with an optional heading
// cone whose width tracks the compass's reported accuracy.
//
// The puck DISC + RING + globe glyph are drawn procedurally on the
// canvas (`drawSquircleGlobePuck`) — same pipeline as the heading
// cone and the POI badges — so the puck tracks the zenith every
// frame instead of lagging in a SwiftUI overlay. The
// `SquircleGlobePuck` view still exists as the design sandbox /
// preview; this is its canvas twin.
extension EArtist {

    // MARK: - Tunables  ▼ TWEAK HERE ▼

    /// Total puck diameter in pt at the default (resting) zoom.
    var userPuckSize       : CGFloat { 22 }
    /// Gentle zoom response: the puck eases between these multiples of
    /// `userPuckSize` — a touch smaller when zoomed out, a touch larger
    /// zoomed in — anchored at 1.0 for the default view so the resting
    /// look is unchanged. Keep the spread narrow ("just so slightly").
    var userPuckMinScaleFactor: CGFloat { 0.45 }   // at the zoom-out floor
    var userPuckMaxScaleFactor: CGFloat { 1.46 }   // at the zoom-in ceiling
    /// White ring thickness as a fraction of the puck — the ring
    /// traces the scallop instead of a clean circle.
    var userPuckRingFraction: CGFloat { 0.08 }
    /// Globe glyph font size as a fraction of the puck.
    var userPuckGlyphScale : CGFloat { 0.92 }
    /// Globe glyph opacity — a touch under 1 so the disc tint
    /// breathes through, matching `SquircleGlobePuck`.
    var userPuckGlyphOpacity: Double { 0.85 }

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

    // MARK: - Aim cone tunables  ▼ TWEAK HERE ▼
    // The device-motion direction cone — a translucent Apple-Maps-style
    // wedge fanning from the puck toward the patch of sky the phone is
    // aimed at. Unlike the fixed heading cone, its LENGTH comes from pitch
    // straight out of the projection (`drawAimCone`):
    //   • phone parallel to ground → top edge points at altitude 0 → the
    //     aim point projects onto the horizon ring → cone REACHES the rim.
    //   • phone vertical           → top edge points up (altitude ~90°) →
    //     the aim point projects to the zenith → cone SHRINKS to the puck.
    // Its WIDTH is the compass's heading uncertainty (the fan), its
    // DIRECTION is the device azimuth. Colour/opacity/half-angle reuse the
    // heading-cone tunables above; only the pitch→length dials live here.

    /// Pitch→length honesty. 1.0 = the cone tip sits exactly on the sky
    /// point the phone aims at. <1 compresses (cone hugs the puck more);
    /// >1 exaggerates (reaches the horizon while still tilted up).
    var aimConeLengthGain    : Double { 1.0 }
    /// Clamp display altitude off the zenith singularity, where azimuth is
    /// undefined and the cone direction would spin. The cone can't fully
    /// vanish — it bottoms out as a sliver tucked under the puck.
    var aimConeMaxAltitudeDeg: Double { 86 }
    /// Floor display altitude at the horizon: aiming at or below the ring
    /// holds the cone at full (horizon) length instead of letting the tip
    /// shoot past the rim toward the projection's below-horizon infinity.
    var aimConeMinAltitudeDeg: Double { 0 }

    // MARK: - Aim blob tunables  ▼ TWEAK HERE ▼
    // The aim blob is the device-motion successor to the heading cone:
    // a soft green disc marking where the phone is physically pointed,
    // positioned on the real sky via the projection. Heading leads,
    // pitch eases it inward — the "azimuth-led hybrid."

    /// Blob radius as a fraction of the on-screen horizon-disc radius
    /// (the disc has radius 2·scale — see `EProjection`). >1 lets the
    /// soft tail spill past the horizon so the glow covers MOST of the
    /// visible sky while its bright core stays pinned precisely on the
    /// aim point. This is the dial that makes the blob "cover the sky."
    var aimBlobSkyFraction     : CGFloat { 1.15 }
    /// Extra radius per degree of compass uncertainty — a shaky
    /// magnetometer reads as a vaguer, larger blob. Secondary now that
    /// the base tracks the sky disc.
    var aimBlobRadiusPerDegree : CGFloat { 0.8 }
    /// Opacity at the blob centre. The gradient holds this near-full
    /// across the core, then eases slowly down a long tail to 0 at the
    /// rim (see `drawAimBlob`) — a precise centre, a sky-wide soft wash.
    var aimBlobOpacity         : Double  { 0.42 }
    /// Core hold: opacity stays near full out to this fraction of the
    /// radius — the crisp "you are aiming here" centre — before the slow
    /// fade begins. Small keeps the core tight; the rest is gentle tail.
    var aimBlobCoreFraction    : Double  { 0.10 }
    /// Sky-wash tint — the blue the night sky lifts toward where the
    /// phone points (`SkyAimWashLayer`, drawn behind the stars). Distinct
    /// from the green "you are here" puck on top.
    var skyAimColor            : Color   { palette.skyAim }

    /// Pitch gain: how much device tilt becomes display altitude. < 1
    /// keeps the blob azimuth-led — hugging the horizon ring, pitch
    /// easing it gently inward rather than driving it to the zenith.
    var aimPitchGain           : Double  { 0.85 }
    /// Never let the blob reach dead centre: clamps it off the zenith
    /// singularity, where azimuth is undefined and the blob would spin.
    var aimMaxAltitudeDeg      : Double  { 86 }
    /// Lower clamp on display altitude (deg). Aiming below the horizon
    /// dips the blob a little past the ring — far enough to read as
    /// "leaving the sky," not so far it rockets toward the projection's
    /// below-horizon infinity. Pairs with the fade below.
    var aimMinAltitudeDeg      : Double  { -8 }
    /// Top of the fade band (deg of display altitude): opacity is full
    /// at/above this and ramps to 0 by `aimMinAltitudeDeg`, so the blob
    /// softly dissolves as the phone drops below the horizon instead of
    /// hard-stopping at the ring or sliding off-canvas.
    var aimFadeTopDeg          : Double  { 0 }

    // MARK: - Aim mapping

    /// Map raw device pitch to the blob's display altitude under the
    /// azimuth-led hybrid: gentle gain, clamped off the zenith above and
    /// dipped just below the horizon ring below (where `aimFadeOpacity`
    /// dissolves it).
    func aimDisplayAltitude(deviceAltitudeRadians alt: Double) -> Double {
        let deg     = alt * 180 / .pi
        let geared  = deg * aimPitchGain
        let clamped = min(aimMaxAltitudeDeg, max(aimMinAltitudeDeg, geared))
        return clamped * .pi / 180
    }

    /// Opacity multiplier (0…1) for the blob at a given display altitude:
    /// 1 at/above the horizon, smoothstepping to 0 by `aimMinAltitudeDeg`
    /// as the aim crosses below the ring. The "you've left the sky" cue.
    func aimFadeOpacity(displayAltitudeRadians alt: Double) -> Double {
        let deg = alt * 180 / .pi
        guard deg < aimFadeTopDeg   else { return 1 }
        guard deg > aimMinAltitudeDeg else { return 0 }
        let t = (deg - aimMinAltitudeDeg) / (aimFadeTopDeg - aimMinAltitudeDeg)
        return t * t * (3 - 2 * t)   // smoothstep, 0 at floor → 1 at ring
    }

    /// Blob radius in screen points: a multiple of the on-screen horizon
    /// disc (`skyDiscRadius` = 2·scale) so the glow scales with zoom and
    /// covers most of the visible sky, plus a small bump for compass
    /// uncertainty. The bright core stays tight (see `drawAimBlob`); this
    /// is just how far the soft tail reaches.
    func aimBlobRadius(skyDiscRadius disc: CGFloat,
                       accuracyDegrees acc: Double) -> CGFloat {
        disc * aimBlobSkyFraction + CGFloat(max(0, acc)) * aimBlobRadiusPerDegree
    }

    /// Puck diameter for the current zoom: `userPuckSize` eased between the
    /// min/max factors. Two segments anchored at the default scale (factor
    /// 1.0) — shrinking toward `userPuckMinScaleFactor` at the zoom-out
    /// floor, growing toward `userPuckMaxScaleFactor` at the ceiling —
    /// clamped beyond the ends. Same two-anchor shape as `magnitudeCap`.
    func userPuckScaledSize(forScale scale: Double) -> CGFloat {
        let floorScale   = 25.0
        let defaultScale = AstroConstants.defaultScale
        let ceilScale    = AstroConstants.maximumScale

        if scale <= floorScale { return userPuckSize * userPuckMinScaleFactor }
        if scale >= ceilScale  { return userPuckSize * userPuckMaxScaleFactor }

        let factor: CGFloat
        if scale <= defaultScale {
            let t = CGFloat((scale - floorScale) / (defaultScale - floorScale))
            factor = userPuckMinScaleFactor + (1 - userPuckMinScaleFactor) * t
        } else {
            let t = CGFloat((scale - defaultScale) / (ceilScale - defaultScale))
            factor = 1 + (userPuckMaxScaleFactor - 1) * t
        }
        return userPuckSize * factor
    }

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
    func userLocationGlobeSymbol(forLongitude lon: Double) -> ESymbol {
        var l = lon
        while l >  180 { l -= 360 }
        while l < -180 { l += 360 }

        if l >= -30 && l <  60  { return .globeEuropeAfrica  }
        if l >=  60 && l < 110  { return .globeSouthAsia     }
        if l >= 110 || l < -170 { return .globeAsiaAustralia }
        return .globeAmericas  // -170° ≤ l < -30°
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

        let cone = dc.resolve(userPuckConeColor)
        dc.ctx.fill(
            path,
            with: .radialGradient(
                Gradient(colors: [
                    cone.opacity(userPuckConeOpacity),
                    cone.opacity(0)
                ]),
                center:      sc,
                startRadius: 0,
                endRadius:   r
            )
        )
    }

    /// Device-motion direction cone — the live successor to
    /// `drawHeadingCone`. A translucent wedge from the puck (`sc`, the
    /// zenith) toward the patch of sky the phone is physically aimed at.
    ///
    /// The trick that gives the requested behaviour for free: the cone tip
    /// is the *projected aim point*, `screenPoint(azimuth, altitude)`. The
    /// projection's own radial law `rho = 2·cos(alt)/(1 + sin(alt))` means
    /// the tip rides the horizon ring at altitude 0 (phone flat) and
    /// collapses onto the zenith at altitude 90° (phone vertical) — so the
    /// cone's LENGTH tracks pitch with no extra mapping. Its DIRECTION is
    /// the screen vector to that point (so it already carries canvas
    /// rotation + the planetarium east-left mirror), and its WIDTH is the
    /// compass `accuracy` fan, clamped to a usable range.
    ///
    /// `azimuth` / `altitude` are the raw device aim in radians;
    /// `accuracy` is the compass heading uncertainty in degrees.
    func drawAimCone(at sc:    CGPoint,
                     azimuth:  Double,
                     altitude: Double,
                     accuracy: Double,
                     in dc:    inout EGraphicContext) {
        // Pitch → display altitude: honest gain, clamped off the zenith
        // (azimuth spins there) and floored at the horizon (tip won't
        // spill past the ring).
        let geared     = altitude * 180 / .pi * aimConeLengthGain
        let clampedDeg = min(aimConeMaxAltitudeDeg, max(aimConeMinAltitudeDeg, geared))
        let displayAlt = clampedDeg * .pi / 180

        // Tip = where the phone points, on the real sky. nil only if it
        // somehow projects behind the viewer (shouldn't, above horizon).
        guard let tip = dc.screenPoint(azimuth: azimuth, altitude: displayAlt) else { return }
        let dx = tip.x - sc.x
        let dy = tip.y - sc.y
        let length = hypot(dx, dy)
        // Phone near-vertical → tip sits on the puck; nothing to draw.
        guard length > 0.5 else { return }
        let axis = atan2(dy, dx)

        let halfAngle = max(userPuckConeMinHalfAngle,
                            min(userPuckConeMaxHalfAngle, accuracy)) * .pi / 180

        // Pie-slice fan: apex at the puck, far edge an arc at `length`.
        var path = Path()
        path.move(to: sc)
        let steps = 40
        for i in 0...steps {
            let t     = Double(i) / Double(steps)
            let angle = axis - halfAngle + 2 * halfAngle * t
            path.addLine(to: CGPoint(x: sc.x + cos(angle) * length,
                                     y: sc.y + sin(angle) * length))
        }
        path.closeSubpath()

        let cone = dc.resolve(userPuckConeColor)
        dc.ctx.fill(
            path,
            with: .radialGradient(
                Gradient(colors: [
                    cone.opacity(userPuckConeOpacity),
                    cone.opacity(0)
                ]),
                center:      sc,
                startRadius: 0,
                endRadius:   length
            )
        )
    }

    /// Soft green disc marking where the phone is currently aimed on the
    /// sky — the device-motion successor to `drawHeadingCone`. The caller
    /// has already routed the device's (azimuth, altitude) through the
    /// projection, so `p` is the on-screen point over the real stars the
    /// phone points at; this just paints the glow there.
    /// `opacity` is a 0…1 multiplier on the blob's centre alpha — used by
    /// the horizon fade so the blob dissolves as the aim crosses the ring.
    /// `color` defaults to the green cone tint (the on-top "you are here"
    /// blob); `SkyAimWashLayer` passes `skyAimColor` instead. `clipDome`,
    /// when given, confines the wash to the horizon rim so it reads as the
    /// *sky itself* lifting rather than a disc floating over the edge.
    func drawAimBlob(at p:       CGPoint,
                     radius:     CGFloat,
                     opacity:    Double  = 1,
                     color:      Color?  = nil,
                     clipDome:   Path?   = nil,
                     in dc:      inout EGraphicContext) {
        let rect = CGRect(x: p.x - radius, y: p.y - radius,
                          width: 2 * radius, height: 2 * radius)
        // Core-hold + slow-tail gradient: full alpha across a tight
        // central core (precise "you're aiming here"), then a long, gentle
        // fade that keeps real colour out to mid-radius so the wash covers
        // most of the sky before easing to nothing at the rim.
        let a = aimBlobOpacity * opacity
        let c = dc.resolve(color ?? userPuckConeColor)
        let gradient = GraphicsContext.Shading.radialGradient(
            Gradient(stops: [
                .init(color: c.opacity(a),        location: 0),
                .init(color: c.opacity(a),        location: aimBlobCoreFraction),
                .init(color: c.opacity(a * 0.45), location: 0.5),
                .init(color: c.opacity(a * 0.15), location: 0.8),
                .init(color: c.opacity(0),        location: 1.0),
            ]),
            center:      p,
            startRadius: 0,
            endRadius:   radius)

        if let clipDome {
            var sky = dc.ctx
            sky.clip(to: clipDome)
            sky.fill(Path(ellipseIn: rect), with: gradient)
        } else {
            dc.ctx.fill(Path(ellipseIn: rect), with: gradient)
        }
    }

    /// Canvas twin of `SquircleGlobePuck`: a 12-corner Lamé squircle
    /// disc (the horizon silhouette — corners / bulge shared with
    /// `bumpedHorizonRim`) wearing the longitude-keyed globe SF
    /// Symbol, clipped to the same scallop so its rim ripples. Drawn
    /// at `sc` (the zenith) every frame, so it stays pinned through
    /// pan / zoom unlike the old SwiftUI overlay.
    func drawSquircleGlobePuck(at sc:    CGPoint,
                               symbol:    ESymbol,
                               in dc:     inout EGraphicContext) {
        let size  = userPuckScaledSize(forScale: dc.renderedScale)
        let inset = size * userPuckRingFraction
        let shape = Squircle(corners: horizonBumpCorners,
                             bulge:   horizonBumpBulge)
        // Resolve the puck's asset colours once — it redraws every frame.
        let ring  = dc.resolve(userPuckRingColor)
        let discC = dc.resolve(userPuckDiscColor)

        let outer = CGRect(x: sc.x - size / 2, y: sc.y - size / 2,
                           width: size, height: size)
        let disc  = outer.insetBy(dx: inset, dy: inset)

        // White scalloped ring.
        dc.ctx.fill(shape.path(in: outer), with: .color(ring))

        // Tinted disc with a soft top→bottom sheen.
        dc.ctx.fill(
            shape.path(in: disc),
            with: .linearGradient(
                Gradient(colors: [discC, discC.opacity(0.82)]),
                startPoint: CGPoint(x: disc.midX, y: disc.minY),
                endPoint:   CGPoint(x: disc.midX, y: disc.maxY))
        )

        // Globe glyph, clipped to the disc scallop so its rim ripples.
        var globe = dc.ctx
        globe.clip(to: shape.path(in: disc))
        globe.draw(
            Text(Image(symbol: symbol))
                .font(.system(size: size * userPuckGlyphScale, weight: .regular))
                .foregroundStyle(ring.opacity(userPuckGlyphOpacity)),
            at:     CGPoint(x: disc.midX, y: disc.midY),
            anchor: .center)
    }
}
