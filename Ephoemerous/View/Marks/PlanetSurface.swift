import SwiftUI

// MARK: - Planet surfaces
// The one readable detail each planet badge earns, drawn INSIDE the disc
// (the casing still traces a plain circle):
//   • Venus   — its real phase: the sunlit part in the planet's gradient,
//               the night side black. Thin crescents are held open.
//   • Jupiter — banded like a sphere: every belt follows its latitude on a
//               globe tipped toward us, so the edges curve. The promoted
//               pin adds the thin belts, streaks and the Great Red Spot.
//   • Mars    — a white north polar cap.
// Saturn's rings live in `SaturnRings` — they're outside the disc.
// ▼ TWEAK the colours and latitudes in `Artist+Planets` ▼

// MARK: Venus
struct VenusPhaseFill: View {
    let phase:   LunarPhase
    let litFill: AnyShapeStyle
    let night:   AnyShapeStyle

    var body: some View {
        // Held open: below ~14% the crescent is thinner than the casing.
        let held = LunarPhase(illuminatedFraction: max(phase.illuminatedFraction,
                                                       Artist.shared.venusMinimumLit),
                              isWaxing:            phase.isWaxing,
                              southernView:        phase.southernView)
        ZStack {
            Circle().fill(night)
            MoonPhaseShape(phase: held).fill(litFill)
        }
    }
}

// MARK: Jupiter
struct JupiterBands: View {
    /// Promoted pin: thin belts, streaks and the Great Red Spot too.
    let fullDetail: Bool

    var body: some View {
        let a = Artist.shared
        ZStack {
            PolarRegion(beyond:  a.jupiterPoleLatitude, tilt: a.jupiterTilt).fill(a.jupiterPole)
            PolarRegion(beyond: -a.jupiterPoleLatitude, tilt: a.jupiterTilt).fill(a.jupiterPole)
            ForEach(Array(a.jupiterBands(fullDetail: fullDetail).enumerated()), id: \.offset) { _, band in
                LatitudeBand(north: band.north, south: band.south, tilt: a.jupiterTilt).fill(band.color)
            }
            if fullDetail { GreatRedSpot() }
            // Limb darkening — the sphere falls off toward its edge.
            Circle().fill(EllipticalGradient(stops: [.init(color: a.jupiterLimb.opacity(0), location: 0.55),
                                                     .init(color: a.jupiterLimb,            location: 1)],
                                             center: UnitPoint(x: 0.5, y: 0.44)))
        }
        .clipShape(Circle())
    }
}

/// The Great Red Spot in its pale hollow, riding the SEB's southern edge
/// and following the globe's curvature.
private struct GreatRedSpot: View {
    var body: some View {
        GeometryReader { geo in
            let a  = Artist.shared
            let r  = geo.size.width / 2
            let at = Latitude(degrees: a.jupiterSpotLatitude, tilt: a.jupiterTilt, r: r)
            let x  = a.jupiterSpotLongitudeOffset * r
            let y  = at.y + at.ry * sqrt(max(0, 1 - pow(x / at.rx, 2)))
            ZStack {
                Ellipse().fill(a.jupiterSpotHollow)
                    .frame(width: r * 0.60, height: r * 0.34)
                Ellipse().fill(a.jupiterSpot)
                    .overlay(Ellipse().stroke(a.jupiterSpotRim, lineWidth: max(0.2, r * 0.03)))
                    .frame(width: r * 0.44, height: r * 0.24)
            }
            .position(x: r + x, y: r + y)
        }
    }
}

// MARK: Mars
struct MarsPolarCap: View {
    var body: some View {
        GeometryReader { geo in
            let d = geo.size.width
            Ellipse()
                .fill(Artist.shared.marsCap)
                .frame(width: d * 0.52, height: d * 0.32)
                .position(x: d / 2, y: d * 0.10)
        }
        .clipShape(Circle())
    }
}

// MARK: - Latitude geometry
/// A latitude circle on a globe tipped `tilt` toward the viewer projects
/// to an ellipse centred at y = r·sinφ·cos(tilt) with radii
/// (r·cosφ, r·cosφ·sin(tilt)); only its near (lower) arc is visible.
/// North is up, so northern latitudes have negative y.
private struct Latitude {
    let y, rx, ry: CGFloat
    init(degrees: Double, tilt: Angle, r: CGFloat) {
        let phi = -degrees * .pi / 180
        y  = r * CGFloat(sin(phi) * cos(tilt.radians))
        rx = r * CGFloat(cos(phi))
        ry = r * CGFloat(cos(phi) * sin(tilt.radians))
    }
    /// Points along the near arc, west → east (or reversed).
    func nearArc(reversed: Bool, samples: Int = 24) -> [CGPoint] {
        let pts = (0...samples).map { i -> CGPoint in
            let t = Double.pi * (1 - Double(i) / Double(samples))        // π → 0
            return CGPoint(x: rx * CGFloat(cos(t)), y: y + ry * CGFloat(sin(t)))
        }
        return reversed ? pts.reversed() : pts
    }
}

/// The band between two latitudes, run out past the limb (the caller
/// clips to the disc).
private struct LatitudeBand: Shape {
    let north, south: Double
    let tilt:         Angle

    func path(in rect: CGRect) -> Path {
        let r   = rect.width / 2, far = r * 1.3
        let n   = Latitude(degrees: north, tilt: tilt, r: r)
        let s   = Latitude(degrees: south, tilt: tilt, r: r)
        var p   = Path()
        p.move(to: CGPoint(x: -far, y: n.y))
        n.nearArc(reversed: false).forEach { p.addLine(to: $0) }
        p.addLine(to: CGPoint(x: far, y: n.y))
        p.addLine(to: CGPoint(x: far, y: s.y))
        s.nearArc(reversed: true).forEach { p.addLine(to: $0) }
        p.addLine(to: CGPoint(x: -far, y: s.y))
        p.closeSubpath()
        return p.offsetBy(dx: rect.midX, dy: rect.midY)
    }
}

/// Everything poleward of a latitude (positive = north cap, negative = south).
private struct PolarRegion: Shape {
    let beyond: Double
    let tilt:   Angle

    func path(in rect: CGRect) -> Path {
        let r    = rect.width / 2, far = r * 1.3
        let edge = Latitude(degrees: beyond, tilt: tilt, r: r)
        let pole = beyond > 0 ? -far : far
        var p    = Path()
        p.move(to: CGPoint(x: -far, y: pole))
        p.addLine(to: CGPoint(x: -far, y: edge.y))
        edge.nearArc(reversed: false).forEach { p.addLine(to: $0) }
        p.addLine(to: CGPoint(x: far, y: edge.y))
        p.addLine(to: CGPoint(x: far, y: pole))
        p.closeSubpath()
        return p.offsetBy(dx: rect.midX, dy: rect.midY)
    }
}
