import SwiftUI
import LoreKit

// MARK: - SkyLabHorizonCircles
// The horizon + twilight rings. Every constant-ALTITUDE circle (almucantar)
// is drawn as a PROJECTED curve through the live camera, so it MORPHS with the
// NorthIN↔NorthOUT transition instead of crossfading: concentric circles about
// the zenith in NorthIN (the stereographic image of an almucantar is a true
// circle there), opening into the single offset horizon curve in NorthOUT
// (pole-centred sky, the horizon sliding with latitude — a circle at the
// poles, a straight line at the equator).
//
// The horizon (0°) holds; the below-horizon twilight bands fade out toward
// NorthOUT, which is bare. They fade while still morphing — the lines
// translate, they don't dissolve into a different shape.
struct EarthGridOverlay: View {

    let camera: SkyCamera
    @Environment(AppState.self) private var app

    private struct Band {
        let altitude: Angle
        let opacity:  Double
    }

    private static let bands: [Band] = [
        .init(altitude: .degrees(  0), opacity: 0.55),   // horizon
        .init(altitude: .degrees( -6), opacity: 0.1),
        .init(altitude: .degrees(-12), opacity: 0.1),
        .init(altitude: .degrees(-18), opacity: 0.1),
        .init(altitude: .degrees(-24), opacity: 0.1),
        .init(altitude: .degrees(-30), opacity: 0.1),
        .init(altitude: .degrees(-36), opacity: 0.1),
        .init(altitude: .degrees(-42), opacity: 0.1),
        .init(altitude: .degrees(-48), opacity: 0.1),
    ]

    var body: some View {
        let morph = app.perspectiveMorph
        ZStack {
            ForEach(0 ..< Self.bands.count, id: \.self) { i in
                let band = Self.bands[i]
                // Horizon holds full; the twilight bands fade out toward the
                // bare NorthOUT view. Every band is a projected curve, so the
                // lines translate continuously through the morph.
                let fade = band.altitude == .degrees(0) ? 1 : (1 - morph)
                AlmucantarCurve(camera: camera, altitude: band.altitude)
                    .stroke(style: .init(lineWidth: 0.8,
                                         lineCap:  .round,
                                         lineJoin: .round,
                                         dash:     [10, 10]))
                    .foregroundStyle(.grid)
                    .opacity(band.opacity * fade)
            }
        }
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
