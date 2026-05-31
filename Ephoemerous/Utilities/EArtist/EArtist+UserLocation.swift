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

    /// Total puck diameter in pt.
    var userPuckSize       : CGFloat { 28 }
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

    // MARK: - Aim blob tunables  ▼ TWEAK HERE ▼
    // The aim blob is the device-motion successor to the heading cone:
    // a soft green disc marking where the phone is physically pointed,
    // positioned on the real sky via the projection. Heading leads,
    // pitch eases it inward — the "azimuth-led hybrid."

    /// Blob radius (pt) with a well-calibrated compass.
    var aimBlobBaseRadius      : CGFloat { 26 }
    /// Extra radius per degree of compass uncertainty — a shaky
    /// magnetometer reads as a vaguer, larger blob.
    var aimBlobRadiusPerDegree : CGFloat { 0.8 }
    /// Clamp so an uncalibrated compass can't swallow the canvas.
    var aimBlobMaxRadius       : CGFloat { 120 }
    /// Opacity at the blob centre; the radial gradient fades to 0 at
    /// the rim — same apex feel as the old cone.
    var aimBlobOpacity         : Double  { 0.42 }

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

    /// Blob radius for a given compass accuracy (degrees; pass 0 when
    /// the compass hasn't reported one).
    func aimBlobRadius(accuracyDegrees acc: Double) -> CGFloat {
        let r = aimBlobBaseRadius + max(0, acc) * aimBlobRadiusPerDegree
        return min(aimBlobMaxRadius, r)
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

    /// Soft green disc marking where the phone is currently aimed on the
    /// sky — the device-motion successor to `drawHeadingCone`. The caller
    /// has already routed the device's (azimuth, altitude) through the
    /// projection, so `p` is the on-screen point over the real stars the
    /// phone points at; this just paints the glow there.
    /// `opacity` is a 0…1 multiplier on the blob's centre alpha — used by
    /// the horizon fade so the blob dissolves as the aim crosses the ring.
    func drawAimBlob(at p:    CGPoint,
                     radius:  CGFloat,
                     opacity: Double = 1,
                     in dc:   inout EGraphicContext) {
        let rect = CGRect(x: p.x - radius, y: p.y - radius,
                          width: 2 * radius, height: 2 * radius)
        dc.ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    userPuckConeColor.opacity(aimBlobOpacity * opacity),
                    userPuckConeColor.opacity(0)
                ]),
                center:      p,
                startRadius: 0,
                endRadius:   radius)
        )
    }

    /// Canvas twin of `SquircleGlobePuck`: a 12-corner Lamé squircle
    /// disc (the horizon silhouette — corners / bulge shared with
    /// `bumpedHorizonRim`) wearing the longitude-keyed globe SF
    /// Symbol, clipped to the same scallop so its rim ripples. Drawn
    /// at `sc` (the zenith) every frame, so it stays pinned through
    /// pan / zoom unlike the old SwiftUI overlay.
    func drawSquircleGlobePuck(at sc:    CGPoint,
                               symbol:    String,
                               in dc:     inout EGraphicContext) {
        let size  = userPuckSize
        let inset = size * userPuckRingFraction
        let shape = Squircle(corners: horizonBumpCorners,
                             bulge:   horizonBumpBulge)

        let outer = CGRect(x: sc.x - size / 2, y: sc.y - size / 2,
                           width: size, height: size)
        let disc  = outer.insetBy(dx: inset, dy: inset)

        // White scalloped ring.
        dc.ctx.fill(shape.path(in: outer), with: .color(userPuckRingColor))

        // Tinted disc with a soft top→bottom sheen.
        dc.ctx.fill(
            shape.path(in: disc),
            with: .linearGradient(
                Gradient(colors: [userPuckDiscColor,
                                  userPuckDiscColor.opacity(0.82)]),
                startPoint: CGPoint(x: disc.midX, y: disc.minY),
                endPoint:   CGPoint(x: disc.midX, y: disc.maxY))
        )

        // Globe glyph, clipped to the disc scallop so its rim ripples.
        var globe = dc.ctx
        globe.clip(to: shape.path(in: disc))
        globe.draw(
            Text(Image(systemName: symbol))
                .font(.system(size: size * userPuckGlyphScale, weight: .regular))
                .foregroundStyle(userPuckRingColor.opacity(userPuckGlyphOpacity)),
            at:     CGPoint(x: disc.midX, y: disc.midY),
            anchor: .center)
    }
}
