
import SwiftUI
import simd

// MARK: - Drawing context

/// Bundles everything a canvas layer needs: the live graphics context,
/// the canvas size, and the current app state. Drawing helpers are
/// methods here so layers stay concise.
struct EGraphicContext {

    var ctx:   GraphicsContext   // var — GraphicsContext drawing methods are mutating
    let size:  CGSize
    let state: EAppState

    // MARK: Per-frame snapshot
    // Resolved exactly ONCE per frame in `CelestialCanva` and held as
    // plain values. A frame projects 10k+ points (the RA/Dec grid alone
    // is ~12 meridians + parallels × 360 samples); reading `@Observable`
    // state inside those loops funnels every single read through
    // Observation's `access(keyPath:)` keypath machinery, which pegs the
    // CPU. Layers and `toScreen` read these snapshots instead so the hot
    // loops never touch the observable graph. The Canvas still registers
    // one dependency per property (the single read below), so it still
    // redraws correctly when any of them changes.
    let renderedScale:           Double
    let renderedOffset:          CGPoint
    let renderedObservationDate: Date
    let localSiderealOffset:     Angle
    let animationTime:           Double

    // MARK: Coordinate helpers

    func toScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(
            x: size.width  / 2 + p.x * renderedScale + renderedOffset.y,
            y: size.height / 2 - p.y * renderedScale + renderedOffset.x
        )
    }
//
//    func sidereallyRotated(_ v: SIMD3<Double>) -> SIMD3<Double> {
////        let θ = state.siderealPlusDynOffset
//        return v.siderealyRotated(by: θ)
//    }

    func onScreen(_ p: CGPoint, margin: CGFloat = 8) -> Bool {
        p.x > margin && p.x < size.width  - margin &&
        p.y > margin && p.y < size.height - margin
    }

    // MARK: Drawing helpers

    mutating func strokeCurve(_ pts: [CGPoint?], color: Color, width: CGFloat = 1) {
        var path = Path()
        var prev: CGPoint? = nil

        for pt in pts {
            guard let pt else { prev = nil; continue }
            let sc = toScreen(pt)
            if let p = prev {
                let dx = sc.x - p.x, dy = sc.y - p.y
                // Break the path at back-side projection discontinuities
                if dx * dx + dy * dy < 80_000 {
                    path.addLine(to: sc)
                } else {
                    path.move(to: sc)
                }
            } else {
                path.move(to: sc)
            }
            prev = sc
        }
        ctx.stroke(path, with: .color(color), lineWidth: width)
//        ctx.stroke(path, with: .foreground, lineWidth: 2)
    }

    
    mutating func fillCurve(_ pts: [CGPoint?], color: Color) {
        var path = Path()
        var prev: CGPoint? = nil

        for pt in pts {
            guard let pt else { prev = nil; continue }
            let sc = toScreen(pt)
            if let p = prev {
                let dx = sc.x - p.x, dy = sc.y - p.y
                // Break the path at back-side projection discontinuities
                if dx * dx + dy * dy < 80_000 {
                    path.addLine(to: sc)
                } else {
                    path.move(to: sc)
                }
            } else {
                path.move(to: sc)
            }
            prev = sc
        }
        ctx.fill(path, with: .color(color))
    }
    
    mutating func fillDot(at sc: CGPoint, radius: CGFloat, color: Color) {
        
        ctx.fill(
            Path(
                ellipseIn: CGRect(
                    x      : sc.x - radius,
                    y      : sc.y - radius,
                    width  : 2 * radius,
                    height : 2 * radius
                )
            ),
//            with: .radialGradient(.init(colors: [color, .white]), center: sc, startRadius: 3, endRadius: 0)
            with: .color(color)
        )
    }

    mutating func gridLabel(at point: CGPoint, text: String) {
        
        ctx.draw(
            Text(text)
                .font(.footnote)
            ,
            at: point,
            anchor: .leading
        )
    }
}
