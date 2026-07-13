import SwiftUI
import LoreKit

// MARK: - SkyLabHorizonCircles
// The horizon + twilight rings. In the observer-centred stereographic
// projection, every constant-ALTITUDE circle (almucantar) maps to a TRUE
// circle centred on the zenith — and the zenith is the projection origin,
// which `camera.screen(.zero)` puts at the canvas centre. So these are
// the one cartographic layer that's cleanest as native `Circle`s (no
// arc-visibility math, unlike the equatorial grid): concentric strokes,
// no fill, riding the parent transform.
//
// Projection radius for altitude a: ρ = 2·cos a / (1 + sin a)
//   horizon (0°)        → 2.00   (boundary of the visible sky)
//   civil  (−6°)        → 2.22
//   nautical (−12°)     → 2.47   (below the horizon → larger rings)
//   astronomical (−18°) → 2.75
struct EarthGridOverlay: View {

    let camera: SkyCamera
    @Environment(EAppState.self) private var app

    private struct Band {
        let altitude:  Angle
        let lineWidth: CGFloat
        let opacity:   Double
    }

    private static let horizon: Band = .init(
        altitude: .degrees(0),
        lineWidth: 1.1,
        opacity: 0.55
    )
    
    private static let bands: [Band] = [
        .init(altitude: .degrees(  0), lineWidth: 1.1, opacity: 0.55),
        .init(altitude: .degrees( -6), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-12), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-18), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-24), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-30), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-36), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-42), lineWidth: 0.7, opacity: 0.1),
        .init(altitude: .degrees(-48), lineWidth: 0.7, opacity: 0.1),
    ]

    var body: some View {
        switch camera.viewpoint.perspective {
        case .northIn:  northInAlmucantars
        case .northOut: northOutHorizon
        }
    }

    // MARK: NorthIN — concentric almucantars about the zenith

    // Every constant-altitude circle maps to a true circle centred on the
    // zenith = the projection origin = `camera.screen(.zero)`.
    private var northInAlmucantars: some View {
        let zenith = camera.screen(.zero)
        return ZStack {
            ForEach(0 ..< Self.bands.count, id: \.self) { i in
                let band = Self.bands[i]
                let r    = Self.projectionRadius(band.altitude) * camera.scale
                // A dashed almucantar ring drawn ABSOLUTELY at the zenith,
                // not via `Circle().frame(...)`. A framed Circle centres on
                // its layout box (the ZStack centre), so it drifts off the
                // horizon the instant there's a committed pan; drawing the
                // ellipse at `zenith` in the layer's own coordinate space
                // pins it to the projection origin under any pan / zoom.
                Ring(center: zenith, radius: r)
                    .stroke(
                        style: .init(
                            lineWidth: 0.8,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [10, 10]
                        )
                    )
                    .foregroundStyle(.grid)
                    .opacity(band.opacity)
            }
        }
    }

    // MARK: NorthOUT — the horizon as a projected great circle

    // In the pole-centred view the horizon is no longer concentric — it's the
    // observer's horizon great circle projected onto the celestial map, which
    // slides with latitude (a circle at the poles, a straight line at the
    // equator). Bare for now.
    private var northOutHorizon: some View {
        HorizonCurve(camera: camera, latitude: app.origin.latitude)
            .stroke(.grid, style: .init(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
            .opacity(0.55)
    }

    /// A circle of `radius` centred at an ABSOLUTE point (`center`) in the
    /// layer's own coordinate space — not at the view's frame centre. This
    /// is what pins each ring to the zenith: `camera.screen(.zero)` moves
    /// with the committed pan, and drawing the ellipse there directly keeps
    /// the almucantars on the horizon under any pan / zoom, riding the
    /// parent transform for its stroke width and dashing.
    private struct Ring: Shape {
        var center: CGPoint
        var radius: CGFloat
        func path(in rect: CGRect) -> Path {
            Path(ellipseIn: CGRect(x: center.x - radius,
                                   y: center.y - radius,
                                   width:  radius * 2,
                                   height: radius * 2))
        }
    }

    /// Stereographic screen radius (projection units) of the
    /// constant-`altitude` circle in the NorthIN (zenith-centred) view:
    /// `2cos a/(1+sin a)` — horizon (0°) → 2, zenith (90°) → 0.
    private static func projectionRadius(_ altitude: Angle) -> CGFloat {
        let a = altitude.radians
        return CGFloat(2 * cos(a) / (1 + sin(a)))
    }
}

// MARK: - HorizonCurve
// The observer's horizon (the great circle 90° from the zenith) projected
// into the NorthOUT pole-centred view. We sample the circle and project each
// point, so the shape self-forms: a full circle at high latitude, opening to
// a straight line at the equator (where the horizon runs through both poles).
//
// The zenith is taken in the MERIDIAN-UP frame — RA' = 0, dec = latitude —
// because `screen(rotatedEquatorial:)` projects in that same sidereally-
// rotated frame the stars ride. LST cancels there, so this horizon is fixed
// in time (only latitude moves it) while the stars wheel around the pole.
private struct HorizonCurve: Shape {
    let camera:   SkyCamera
    let latitude: Angle

    func path(in rect: CGRect) -> Path {
        // Meridian-up zenith, and the orthonormal basis of its horizon plane.
        let zr       = Angle.spherePoint(latitude: latitude, longitude: .zero)
        let (e1, e2) = zr.baseVectors()
        // "Infinity" cutoff: points streaking off toward the celestial north
        // pole break the path (so the closing circle becomes an open line).
        let origin   = camera.screen(.zero)
        let bound    = Swift.max(rect.width, rect.height) * 4 + 4000

        var path    = Path()
        var started = false
        let steps   = 360
        for i in 0 ... steps {
            let phi = Double(i) / Double(steps) * 2 * .pi
            let p   = cos(phi) * e1 + sin(phi) * e2      // unit vector on the horizon
            guard let sc = camera.screen(rotatedEquatorial: p),
                  hypot(sc.x - origin.x, sc.y - origin.y) < bound else {
                started = false                           // ran to infinity → break
                continue
            }
            if started { path.addLine(to: sc) } else { path.move(to: sc); started = true }
        }
        return path
    }
}
