import SwiftUI
import LoreKit
// `CLHeading` members — MEMBER_IMPORT_VISIBILITY needs the defining module.
import CoreLocation

// MARK: - FacingBezel
// The stretch of horizon you face, lit softly on the rim — the chart's
// answer to "where am I facing" (see `Artist+Aim`).
//
// Drawn as a PROJECTED arc of the horizon (alt = 0) through the live
// camera, so it rides the rim through rotation, compass mode and the
// NorthIN ↔ NorthOUT morph with no special cases.
//
// Its own view, reading motion in its own body: phone motion redraws this
// arc and nothing else — the star field stays parked.
struct FacingBezel: View {

    let camera: SkyCamera
    @Environment(AppState.self) private var app

    var body: some View {
        // Only meaningful where you stand. The gate reads no motion, so a
        // panned-away sky takes no motion dependency at all.
        if app.isAtDeviceLocation, let facing {
            let a = Artist.shared
            Canvas { ctx, _ in
                let style = StrokeStyle(lineWidth: a.bezelLineWidth, lineCap: .round)
                if let span = arc(around: facing.azimuth, halfAngle: facing.halfAngle) {
                    ctx.stroke(span, with: .color(a.bezelInk.opacity(a.bezelOpacity)), style: style)
                }
                if let core = arc(around: facing.azimuth, halfAngle: facing.halfAngle * a.bezelCoreFraction) {
                    ctx.stroke(core, with: .color(a.bezelInk.opacity(a.bezelCoreOpacity)), style: style)
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: Facing

    private struct Facing {
        let azimuth:   Double      // radians, clockwise from north
        let halfAngle: Double      // radians
    }

    /// Where you face: the device aim when there's a gyro, else the bare
    /// compass (no gyro in the Simulator). The span is the compass's own
    /// accuracy, clamped.
    private var facing: Facing? {
        let a        = Artist.shared
        let compass  = LocationService.shared.heading
        let accuracy = compass.map(\.headingAccuracy).flatMap { $0 >= 0 ? $0 : nil } ?? a.bezelMinHalfAngleDeg
        let half     = min(a.bezelMaxHalfAngleDeg, max(a.bezelMinHalfAngleDeg, accuracy)) * .pi / 180

        if let aim = MotionService.shared.aim {
            return Facing(azimuth: aim.azimuth, halfAngle: half)
        }
        guard let h = compass, h.headingAccuracy >= 0 else { return nil }
        let heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        return Facing(azimuth: heading * .pi / 180, halfAngle: half)
    }

    /// The horizon from `azimuth − halfAngle` to `azimuth + halfAngle`,
    /// projected. Breaks where a point won't project.
    private func arc(around azimuth: Double, halfAngle: Double) -> Path? {
        let steps   = 32
        var path    = Path()
        var started = false
        for i in 0 ... steps {
            let az = azimuth - halfAngle + 2 * halfAngle * Double(i) / Double(steps)
            guard let p = camera.screen(rotatedEquatorial: camera.viewpoint.skyPoint(azimuth: az, altitude: 0)) else {
                started = false
                continue
            }
            if started { path.addLine(to: p) } else { path.move(to: p); started = true }
        }
        return path.isEmpty ? nil : path
    }
}
