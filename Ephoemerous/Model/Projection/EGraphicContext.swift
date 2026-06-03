
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
    let viewpoint:               EProjection.Viewpoint
    /// Sky-fixed canvas rotation. Applied to each projected point in
    /// `toScreen` so "celestial up" lands by the device's DI edge
    /// regardless of orientation. Set by `MainView` based on
    /// `verticalSizeClass`. See `EAppState.canvasRotation`.
    let canvasRotation:          Angle

    // MARK: Selection promotion snapshot
    // Resolved once per frame (like the camera values above) so the
    // POI draw can promote the selected label without reading the
    // observable graph per-object in the hot loops. See
    // `EArtist.drawPOILabel` for what `promotion` / `wiggle` drive.
    let selectedObjectID: String?
    let selectionStart:   Double
    let deselectingID:    String?
    let deselectStart:    Double

    /// Fast path for the common "nothing selected" case — lets a layer
    /// skip building per-object ids when no label is (de)selecting.
    var hasActivePromotion: Bool { selectedObjectID != nil || deselectingID != nil }

    /// Promotion (0…1) for the POI label identified by `id` (an
    /// `ESkyObject.id`), as a function of the per-frame animation clock:
    ///   • the selected object eases UP (0→1)
    ///   • the just-deselected object eases DOWN (1→0)
    ///   • everything else stays flat (0)
    /// Pass the result straight into `drawPOILabel(promotion:)`.
    func poiPromotion(forObjectID id: String?) -> Double {
        guard let id else { return 0 }
        let artist = EArtist.shared
        if id == selectedObjectID {
            return artist.poiSelectProgress(from: 0, to: 1,
                                            elapsed: animationTime - selectionStart)
        }
        if id == deselectingID {
            return artist.poiSelectProgress(from: 1, to: 0,
                                            elapsed: animationTime - deselectStart)
        }
        return 0
    }

    // MARK: Coordinate helpers

    /// Project-unit point → screen pixel. The point is rotated by
    /// `canvasRotation` around the projection origin first; the badge
    /// shapes + labels drawn at the resulting screen position stay
    /// axis-aligned. When `canvasRotation == 0` the rotation step is
    /// skipped entirely.
    func toScreen(_ p: CGPoint) -> CGPoint {
        let pRot: CGPoint
        if canvasRotation == .zero {
            pRot = p
        } else {
            let θ    = canvasRotation.radians
            let cosθ = cos(θ)
            let sinθ = sin(θ)
            pRot = CGPoint(x: p.x * cosθ - p.y * sinθ,
                           y: p.x * sinθ + p.y * cosθ)
        }
        return CGPoint(
            x: size.width  / 2 + pRot.x * renderedScale + renderedOffset.y,
            y: size.height / 2 - pRot.y * renderedScale + renderedOffset.x
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

    /// Screen position for a horizon-frame aim (azimuth clockwise from
    /// north, altitude above the horizon, both radians), or `nil` when it
    /// projects behind the viewer. Threads the full pipeline —
    /// `viewpoint.skyPoint` → `EProjection.project` → `toScreen` — so the
    /// result sits on the real sky and tracks pan / zoom / rotation for
    /// free. The device-aim blob uses this to land on the stars the phone
    /// points at.
    func screenPoint(azimuth: Double, altitude: Double) -> CGPoint? {
        let v = viewpoint.skyPoint(azimuth: azimuth, altitude: altitude)
        guard let p = EProjection.project(v, viewpoint: viewpoint) else { return nil }
        return toScreen(p)
    }

    // MARK: Star cull
    //
    // Observer-centred stereographic ⇒ a star's distance from the
    // projected zenith depends ONLY on its angle from the zenith:
    //   projection-radius ρ = 2·cos(alt) / (1 + sin(alt))
    //   dot(zenith, starVector) = sin(alt)
    // So "could this star be on screen?" is one dot product against a
    // per-frame `minDot` cutoff — no per-star projection. The cutoff is
    // derived from the farthest visible corner, so the kept disc always
    // CONTAINS the visible rect: an on-screen star can never be culled.

    /// Per-frame visibility gate for the star field. Built once in
    /// `StarsLayer`; `keeps(_:)` is then called per star with the star's
    /// constant (un-precessed, un-rotated) `equatorialVector`.
    struct StarCull {
        /// Sidereal-inverse-rotated zenith. Dotting the star's UN-rotated
        /// vector against this equals dotting the rotated star against the
        /// real zenith — saves a rotation per star (do it once here).
        let zenithUnrotated: SIMD3<Double>
        /// Minimum `dot` (= sin altitude) a star needs to survive. Lower
        /// = wider cone = more stars; rises toward 1 as you zoom in.
        let minDot: Double

        @inline(__always)
        func keeps(_ starVector: SIMD3<Double>) -> Bool {
            simd_dot(starVector, zenithUnrotated) >= minDot
        }
    }

    /// Build the per-frame star cull from the current camera. Returns a
    /// gate that rejects stars whose angle from the zenith puts them
    /// outside the visible area (plus a margin). `nil`-safe: when the
    /// whole sky is visible (zoomed out) the cutoff just goes ≤ −1 and
    /// keeps everything.
    func makeStarCull(marginPixels: CGFloat = 40) -> StarCull {
        // Zenith projects to the origin → its screen point is the centre
        // + pan offset. Farthest visible corner from there sets the cone.
        let zc = toScreen(.zero)
        let corners = [CGPoint(x: 0, y: 0),
                       CGPoint(x: size.width, y: 0),
                       CGPoint(x: 0, y: size.height),
                       CGPoint(x: size.width, y: size.height)]
        let maxDist = corners.map { hypot($0.x - zc.x, $0.y - zc.y) }.max() ?? 0
        let dMax = maxDist + marginPixels

        // Pixels → projection radius (toScreen scales projection coords
        // by renderedScale). Then invert the stereographic radius for the
        // minimum sine-altitude that still lands within dMax.
        let rho = renderedScale > 0 ? Double(dMax) / renderedScale : .infinity
        let sinAltMin = (4 - rho * rho) / (4 + rho * rho)   // → −1 as rho → ∞

        // Dot the un-rotated star against the inverse-rotated zenith so
        // the per-star path needs no rotation.
        let zenithUnrotated = viewpoint.originVector
            .sidereallyRotated(by: -localSiderealOffset)

        return StarCull(zenithUnrotated: zenithUnrotated, minDot: sinAltMin)
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

    /// Fill everything *outside* the curve. Builds the same screen-
    /// space path as `fillCurve` and unions it with a canvas-sized
    /// outer rectangle; an even-odd fill rule then turns the inner
    /// curve into a hole. Used by the horizon to tint the
    /// below-horizon region while leaving the visible-sky disc bare.
    mutating func fillOutsideCurve(_ pts: [CGPoint?], color: Color) {
        var inner = Path()
        var prev: CGPoint? = nil

        for pt in pts {
            guard let pt else { prev = nil; continue }
            let sc = toScreen(pt)
            if let p = prev {
                let dx = sc.x - p.x, dy = sc.y - p.y
                if dx * dx + dy * dy < 80_000 {
                    inner.addLine(to: sc)
                } else {
                    inner.move(to: sc)
                }
            } else {
                inner.move(to: sc)
            }
            prev = sc
        }
        inner.closeSubpath()

        // Generously oversize the outer rect (3× the canvas in each
        // direction) so panning / zooming can never leave a corner
        // of the canvas un-tinted.
        var compound = Path(
            CGRect(x:      -size.width,
                   y:      -size.height,
                   width:  3 * size.width,
                   height: 3 * size.height)
        )
        compound.addPath(inner)

        ctx.fill(compound,
                 with: .color(color),
                 style: FillStyle(eoFill: true))
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
