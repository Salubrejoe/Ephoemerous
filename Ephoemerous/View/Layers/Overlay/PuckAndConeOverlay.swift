import SwiftUI
import simd
import LoreKit
// `CLHeading`'s members (headingAccuracy / trueHeading / magneticHeading) are
// read in `drawAim`. MEMBER_IMPORT_VISIBILITY is on for this project, so the
// DEFINING module must be imported explicitly — reaching them through
// `ELocationService.heading` isn't enough. Xcode 26.6 enforces this; the 27
// beta doesn't, which is how it reached CI unnoticed.
import CoreLocation

// MARK: - SkyLabUserLocationOverlay
// The "you are here" cluster — aim cone + globe puck — anchored at the
// zenith (`camera.screen(.zero)`). Native port of production's
// `UserLocationLayer`, reusing its tunables/styling (EArtist.userPuck* /
// aimCone*), with the puck drawn as a plain CIRCLE (the squircle scallop
// border dropped).
//
// The aim cone's direction + length come for free from the PROJECTED aim
// point — `camera.screen(rotatedEquatorial: skyPoint(az, alt))` — so it
// already carries the camera rotation (compass heading-up → cone points
// up) and the projection's rho law (horizon when the phone's flat,
// collapsing to the puck when vertical). No manual rotation math.
//
// Gated on `isAtDeviceLocation`: the mark is meaningless anywhere else,
// and the gate short-circuits BEFORE reading device motion so a
// panned-away canvas takes no motion dependency.
struct PuckAndConeOverlay: View {

    let camera: SkyCamera
    let pinch:  CGFloat
    @Environment(EAppState.self) private var app

    var body: some View {
        // The puck + cone are anchored to the zenith (projection origin). As
        // the morph runs toward NorthOUT the origin drifts to the celestial
        // south pole and the "you are here" mark stops meaning anything — so
        // fade it out with the morph (fully gone in NorthOUT).
        if app.isAtDeviceLocation, app.perspectiveMorph < 1 {
            let zenith = camera.screen(.zero)
            ZStack {
                // Aim cone wash — redraws as the device aim changes.
                Canvas { ctx, _ in drawAim(ctx, zenith: zenith) }
                    .allowsHitTesting(false)
                // Globe puck on top, constant screen size.
                puck
                    .scaleEffect(1 / pinch)
                    .position(zenith)
                    .allowsHitTesting(false)
            }
            .opacity(1 - app.perspectiveMorph)
        }
    }

    // MARK: Aim cone

    private func drawAim(_ ctx: GraphicsContext, zenith: CGPoint) {
        let a = EArtist.shared
        let compass  = ELocationService.shared.heading
        let accuracy = (compass?.headingAccuracy ?? -1) >= 0
            ? compass!.headingAccuracy
            : a.userPuckConeMinHalfAngle

        func paint(_ path: Path, length: CGFloat) {
            ctx.fill(path, with: .radialGradient(
                Gradient(colors: [a.userPuckConeColor.opacity(a.userPuckConeOpacity),
                                  a.userPuckConeColor.opacity(0)]),
                center: zenith, startRadius: 0, endRadius: length))
        }

        // Live device motion → real direction cone (tip is the projected
        // aim point, so it carries rotation + the pitch→length law).
        if let aim = EMotionService.shared.aim,
           let wedge = aimWedge(zenith: zenith, azimuth: aim.azimuth,
                                altitude: aim.altitude, accuracy: accuracy) {
            paint(wedge.path, length: wedge.length)
            return
        }
        // Fallback (no gyro): fixed-length heading fan, north-up.
        if let h = compass, h.headingAccuracy >= 0 {
            let heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
            let half = clampHalfAngle(h.headingAccuracy)
            let axis = atan2(-cos(heading * .pi / 180), -sin(heading * .pi / 180))
            paint(fan(zenith: zenith, axis: axis, half: half, length: a.userPuckConeRadius),
                  length: a.userPuckConeRadius)
        }
    }

    /// Device-aim wedge: tip = projected aim point, so length tracks pitch
    /// and direction tracks azimuth + the camera rotation automatically.
    private func aimWedge(zenith: CGPoint, azimuth: Double, altitude: Double,
                          accuracy: Double) -> (path: Path, length: CGFloat)? {
        let a = EArtist.shared
        let geared     = altitude * 180 / .pi * a.aimConeLengthGain
        let clampedDeg = min(a.aimConeMaxAltitudeDeg, max(a.aimConeMinAltitudeDeg, geared))
        let displayAlt = clampedDeg * .pi / 180
        let v = camera.viewpoint.skyPoint(azimuth: azimuth, altitude: displayAlt)
        guard let tip = camera.screen(rotatedEquatorial: v) else { return nil }
        let dx = tip.x - zenith.x, dy = tip.y - zenith.y
        let length = hypot(dx, dy)
        guard length > 0.5 else { return nil }                  // phone vertical
        // In compass mode the phone is the DIAL: the sky spins to keep the
        // heading up, so the cone stays fixed pointing straight up (−y) —
        // otherwise the heading low-pass lag makes it wobble. Length still
        // tracks pitch (azimuth doesn't affect the projected distance).
        let axis = app.compassMode ? -Double.pi / 2 : atan2(dy, dx)
        return (fan(zenith: zenith, axis: axis, half: clampHalfAngle(accuracy), length: length),
                length)
    }

    private func clampHalfAngle(_ accuracy: Double) -> Double {
        let a = EArtist.shared
        return max(a.userPuckConeMinHalfAngle, min(a.userPuckConeMaxHalfAngle, accuracy)) * .pi / 180
    }

    private func fan(zenith: CGPoint, axis: Double, half: Double, length: CGFloat) -> Path {
        var path = Path()
        path.move(to: zenith)
        let steps = 40
        for i in 0 ... steps {
            let t     = Double(i) / Double(steps)
            let angle = axis - half + 2 * half * t
            path.addLine(to: CGPoint(x: zenith.x + cos(angle) * length,
                                     y: zenith.y + sin(angle) * length))
        }
        path.closeSubpath()
        return path
    }

    // MARK: Puck — a mute mark, not a button

    // A glyph inside a circle PROMISES a tap (it reads as a POI badge /
    // control) but the puck isn't tappable — a broken affordance. Maps'
    // blue dot works because it's mute: a dot, a ring, done. Ours is the
    // signature scallop squircle (the same family as the compass rose face
    // and the horizon bump), solid in the grid ink with a casing ring so it
    // reads "marker", never "button".
    private var puck: some View {
        let size = EArtist.shared.userPuckSize * 0.7
        let mark = Squircle(corners: 12, bulge: 2.5)
        return mark
            .fill(EArtist.shared.gridColor)
            .overlay(mark.stroke(EArtist.shared.canvasBackground, lineWidth: 2))
            .frame(width: size, height: size)
    }
}
