import SwiftUI
import simd
import LoreKit

// Renders the ecliptic as two 12-bulge rims, locked to the zodiac.
//
// The rim is parametrised by ecliptic longitude (λ) rather than canvas
// angle: sample λ from 0…2π, project each point, then scale its radial
// distance from the projected ecliptic's centroid by `lameRadius(λ)`.
// Because `lameRadius` is 30°-periodic for n = 12, each zodiac sign
// gets its own bulge — corner peak at the sign's midpoint (15°, 45°…),
// side midpoint at the sign's boundary (0°, 30°…). The glyphs sit on
// the bulge peaks by construction.
//
// `EProjection.project` is stereographic, so the ecliptic itself lands
// as a true circle in projection space — fitting the centroid + mean
// radius from the projected samples is exact.
struct EclipticLayer: EGridLayer {
    // 12-bulge squircle, one bulge per zodiac sign; tied to the
    // zodiac's 30°-per-sign symmetry, so these are ecliptic-specific
    // and don't belong on `EArtist`. Stroke colour + width come from
    // `EArtist.eclColor` / `eclWidth`.
    private let corners   : Int     = 12
    private let bulge     : CGFloat = 2.8
    private let sunMargin : CGFloat = 10   // screen px — sun disc + a touch

    func draw(in dc: inout EGraphicContext) {
        let samples = EProjection.sampleEcliptic(viewpoint:      dc.viewpoint,
                                                 siderealOffset: dc.localSiderealOffset)
            .compactMap { $0 }
        guard samples.count >= 8 else { return }
        
        let (centre, radius) = fitCircle(samples)
        guard radius > 0.0001 else { return }
        
        // Two parallel ecliptic rims straddling the true ecliptic so the
        // Sun (which sits on it by definition) is held between them.
        // `δ` lives in screen px and gets converted to projection units
        // so the band's apparent width stays constant under zoom.
//        let δ = sunMargin / dc.renderedScale
        
        var local = dc
        for offset in [0.0] {
            //        for offset in [0.0, δ] {
            //            local.ctx.addFilter(
            //                .shadow(
            //                    color: .yellow,
            //                    radius: 3,
            //                    x: 0,
            //                    y: 1,
            //                    blendMode: .destinationOver,
            //                    options: .shadowAbove
            //                )
            //            )
//            local.ctx.addFilter(.blur(radius: 1))
            local.strokeCurve(zodiacRim(extraOffset: offset, centre: centre, in: dc),
                              color: artist.eclColor,
                              width: artist.eclWidth)
        }
        
        drawZodiacGlyphs(centre: centre, in: &dc)
    }
    
    // Walk λ around the ecliptic, project each point, then push it
    // outward from the centroid by `lameRadius(λ)`. With corners = 12,
    // `lameRadius` is 30°-periodic — exactly the zodiac's sign spacing
    // — so each sign occupies one bulge.
    //
    // The baseline is each sample's *actual* projected distance `d`,
    // not the fitted mean radius. That keeps the rim concentric with
    // whatever shape the projection produces (true circle in pure
    // stereographic, deformed conic when origin and plane drift apart)
    // and locks it visually to the glyphs, which also ride the real
    // projected curve.
    private func zodiacRim(extraOffset: CGFloat,
                           centre: CGPoint,
                           in dc: EGraphicContext) -> [CGPoint?] {
        let steps  = 360
        let th     = dc.localSiderealOffset.radians
        let (c, s) = (cos(th), sin(th))
        let corn   = CGFloat(corners)
        return (0...steps).map { i in
            let lambda = Double(i) / Double(steps) * 2 * .pi
            let eq     = SIMD3<Double>.eclipticPoint(lambda: .radians(lambda))
            let Q      = SIMD3(eq.x * c - eq.y * s,
                               eq.x * s + eq.y * c,
                               eq.z)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { return nil }
            let dx = proj.x - centre.x
            let dy = proj.y - centre.y
            let d  = hypot(dx, dy)
            guard d > 0.0001 else { return nil }
            let k      = Squircle.lameRadius(angle: CGFloat(lambda), corners: corn, bulge: bulge)
            let target = k * (d + extraOffset)
            return CGPoint(x: centre.x + dx / d * target,
                           y: centre.y + dy / d * target)
        }
    }
    
    // Zodiac glyphs at each sign's midpoint (15°, 45°, 75°… ecliptic
    // longitude), drawn directly on the projected ecliptic — same
    // pipeline the Sun uses in `ESunLayer`. Each glyph is rotated so
    // its baseline lies tangent to the ecliptic and its "top" points
    // radially outward from the ecliptic's centroid — celestial
    // typography that reads naturally when you tilt your head around
    // the rim.
    private func drawZodiacGlyphs(centre: CGPoint, in dc: inout EGraphicContext) {
        let th         = dc.localSiderealOffset.radians
        let (c, s)     = (cos(th), sin(th))
        let centroidSc = dc.toScreen(centre)
        for sign in EZodiacSign.zodiac {
            let lambda = Angle.degrees(Double(sign.index - 1) * 30 + 15)
            let eq     = SIMD3<Double>.eclipticPoint(lambda: lambda)
            let Q      = SIMD3(eq.x * c - eq.y * s,
                               eq.x * s + eq.y * c,
                               eq.z)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)
            // Rotation that makes the text's "up" point along the
            // outward radial — atan2(Nx, −Ny) inverts the y because
            // screen-y grows downward.
            let nx = sc.x - centroidSc.x
            let ny = sc.y - centroidSc.y
            let θ  = atan2(nx, -ny)
            
            var local = dc.ctx
            local.translateBy(x: sc.x, y: sc.y)
            local.rotate(by: .radians(θ))
            local.draw(
                Text(sign.symbol)
                    .font(.footnote)
                    .foregroundStyle(artist.eclColor),
                at:     .zero,
                anchor: .center
            )
        }
    }
    
    // Stereographic guarantees the samples are concyclic, so centroid +
    // mean radius are exact for a fully-visible ecliptic. Falls back
    // gracefully if a few samples were nil (partial visibility).
    private func fitCircle(_ pts: [CGPoint]) -> (centre: CGPoint, radius: CGFloat) {
        let n  = CGFloat(pts.count)
        let cx = pts.map(\.x).reduce(0, +) / n
        let cy = pts.map(\.y).reduce(0, +) / n
        let r  = pts.map { hypot($0.x - cx, $0.y - cy) }.reduce(0, +) / n
        return (CGPoint(x: cx, y: cy), r)
    }
    
}

