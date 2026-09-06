import SwiftUI
import LoreKit

// MARK: - SkyLabHorizonCircles
// The horizon ring. It is drawn as a PROJECTED curve through the live
// camera, so it MORPHS with the NorthIN↔NorthOUT transition instead of
// crossfading: a circle about the zenith in NorthIN (the stereographic
// image of an almucantar is a true circle there), opening into the single
// offset horizon curve in NorthOUT (pole-centred sky, the horizon sliding
// with latitude — a circle at the poles, a straight line at the equator).
//
// The below-horizon twilight bands (−6°…−48°, the concentric scallops that
// spelled civil / nautical / astronomical dusk spatially) were REMOVED by
// request. The frosted ground below the rim still carries time-of-day, so
// the horizon is now the only almucantar drawn — and the only dashed ring
// on the canvas, which is what makes it read as the rim rather than as one
// member of a family.
struct EarthGridOverlay: View {

    let camera: SkyCamera

    /// The rim's weight. Was the horizon band's own opacity in the old
    /// band table, kept at the same value so the ring didn't change
    /// brightness when its siblings went. ▼ TWEAK ▼
    private static let opacity: Double = 0.55

    var body: some View {
        AlmucantarCurve(camera: camera, altitude: .degrees(0))
            .stroke(style: .init(lineWidth: 0.8,
                                 lineCap:  .round,
                                 lineJoin: .round,
                                 dash:     [10, 10]))
            .foregroundStyle(.grid)
            .opacity(Self.opacity)
    }
}

// MARK: - AlmucantarCurve
// One constant-altitude circle, sampled in 3-D (`skyPoint`) and projected
// point-by-point through the (morphing) camera. Sampling + projecting —
// rather than a closed-form radius — is what lets it MORPH: at NorthIN it
// comes out a true concentric circle (radius 2·tan((90°−a)/2) = 2cos a/(1+sin
// a), matching the old formula exactly), and it deforms smoothly to the offset
// NorthOUT curve as the projection eye slerps. `skyPoint` is a fixed set of
// sky directions (morph-independent); only its projection changes, so the
// curve morphs purely through the camera. Points streaking to infinity break
// the path, so a closing circle becomes an open line where it should.
private struct AlmucantarCurve: Shape {
    let camera:   SkyCamera
    let altitude: Angle

    func path(in rect: CGRect) -> Path {
        let origin = camera.screen(.zero)
        let bound  = Swift.max(rect.width, rect.height) * 4 + 4000
        var path    = Path()
        var started = false
        let steps   = 240
        for i in 0 ... steps {
            let t = Double(i) / Double(steps)
            let p = camera.viewpoint.skyPoint(altitude: altitude, at: t)
            guard let sc = camera.screen(rotatedEquatorial: p),
                  hypot(sc.x - origin.x, sc.y - origin.y) < bound else {
                started = false                       // ran to infinity → break
                continue
            }
            if started { path.addLine(to: sc) } else { path.move(to: sc); started = true }
        }
        return path
    }
}

#if DEBUG
#Preview("Horizon") {
    PreviewSky.night { EarthGridOverlay(camera: PreviewSky.camera) }
}
#endif
