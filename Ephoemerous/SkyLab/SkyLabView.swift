import SwiftUI

// MARK: - SkyLabView
// Proving ground for the rendering rethink: a Canvas layer (the grid) and
// a native SwiftUI overlay (the Sun label) under ONE shared parent
// transform.
//
// The sync model — the thing this view exists to validate:
//   • Both children render at the camera's COMMITTED (resting) transform.
//   • A live gesture writes only the transient `drag` / `pinch`, which
//     drive a single `.scaleEffect` + `.offset` on the ZStack that holds
//     BOTH children. A parent transform lands on every child in the same
//     CoreAnimation commit, so the Canvas and the overlay move as one and
//     cannot desync — no per-frame re-projection, no two clocks.
//   • On release the delta folds into the committed transform and resets
//     to identity: one reconciliation render at the new camera.
//
// Astronomical data (viewpoint, sidereal time, date) is read from the
// shared `EAppState`; the camera transform is the lab's own.
//
// To run it as the app root, swap `MainView()` for `SkyLabView()` in
// `EphoemerousApp` (kept out of production by default).
struct SkyLabView: View {

    @Environment(EAppState.self) private var app

    // Committed (resting) camera — FROZEN during a gesture.
    @State private var scale:  CGFloat = Self.defaultScale
    @State private var offset: CGSize  = .zero

    // Production scale model (hard clamp — no rubber, no recentering yet).
    private static let defaultScale: CGFloat = 90
    private static let minScale:     CGFloat = 90
    private static let maxScale:     CGFloat = 1200

    /// Only PROPER-named stars (Sirius, Betelgeuse…) get the POI label —
    /// like production. The Bayer / Flamsteed rest will get plain
    /// secondary text past max scale later; skipped for now. Computed
    /// ONCE (workableStars rebuilds ~9k EStars per access).
    private static let properNamedStars: [EStar] =
        StarDatabase.shared.workableStars.filter { $0.properName != nil }

    // Transient gesture deltas — applied to the shared parent transform,
    // folded into the committed camera on release.
    @State private var drag:  CGSize  = .zero
    @State private var pinch: CGFloat = 1
    /// Pinch focal point in screen coords (the centroid the gesture
    /// started on) — the zoom anchors here instead of the screen centre.
    @State private var focal: CGPoint = .zero

    // Double-tap-hold-drag zoom. A one-finger drag that BEGINS shortly
    // after a tap is a zoom-drag (vertical drag → zoom, anchored at the
    // tap); otherwise it's a pan. `lastTapTime` is stamped by a sibling
    // tap gesture; `dragMode` latches the decision for the drag's life.
    private enum DragMode { case pan; case zoom(anchor: CGPoint) }
    @State private var dragMode:    DragMode? = nil
    @State private var lastTapTime: Date = .distantPast

    private static let doubleTapWindow:     TimeInterval = 0.35  // s: tap → drag = zoom
    private static let zoomDragSensitivity: Double       = 0.006 // scale e-fold per pt up
    private static let stepZoomFactor:      CGFloat      = 2.0   // quick double-tap step

    /// Off-screen drawing margin per edge (pt). The Canvas is rendered
    /// this much larger than the screen so a pan reveals drawn grid, not
    /// blank — see the framing note in `body`. Generous for the lab;
    /// tune (and add `.clipped()`) when this graduates to production.
    private let overdraw: CGFloat = 600

    var body: some View {
        GeometryReader { geo in
            // The canvas is rendered OVERSIZE — the screen plus an
            // `overdraw` margin on every edge — and centred. A SwiftUI
            // Canvas clips to its own frame, so a screen-sized one would
            // slide in blank at the trailing edge the instant the parent
            // transform pans it. Drawing the margin keeps grid in reserve
            // all around; nothing clips it because we never apply
            // `.clipped()` and a `.frame` doesn't clip overflow.
            let canvasSize = CGSize(width:  geo.size.width  + overdraw * 2,
                                    height: geo.size.height + overdraw * 2)
            // Centre = canvasSize/2, which (because the oversize content is
            // centred in the screen below) lands on the screen centre.
            let camera = SkyLabCamera(
                scale:     scale,
                offset:    offset,           // committed pan baked in → Canvas
                size:      canvasSize,       //   draws centred on the view
                viewpoint: app.viewpoint,
                sidereal:  app.localSiderealOffset
            )

            // Screen centre — the `.scaleEffect(anchor: .center)` fixed
            // point, and the reference the focal compensation works from.
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            // Hard-clamp the live zoom to [min, max] — a wall, no rubber.
            // `effPinch` is the magnification actually applied this frame
            // (and `liveScale` the resulting committed-equivalent scale),
            // so everything downstream — the scaleEffect, the pan
            // compensation, the overlay counter-scale, the named-star
            // gate — speaks one clamped value.
            let liveScale = min(max(scale * pinch, Self.minScale), Self.maxScale)
            let effPinch  = scale > 0 ? liveScale / scale : 1

            // LIVE gesture delta applied OUTSIDE the scale (the committed
            // pan now lives in the camera). Two terms:
            //   • `(focal − center)·(1 − effPinch)` — focal compensation, so
            //     the sky point under the FINGERS stays under the fingers as
            //     the scaleEffect zooms about screen centre.
            //   • `drag` — live one-finger / centroid pan.
            // At rest (effPinch 1, drag 0) this is .zero — parent identity,
            // canvas shown exactly as drawn.
            let applied = CGSize(
                width:  (focal.x - center.x) * (1 - effPinch) + drag.width,
                height: (focal.y - center.y) * (1 - effPinch) + drag.height
            )

            ZStack {
                // `.equatable()` → these Canvases redraw only when the
                // committed camera changes (a settle / date / origin move),
                // NOT per gesture frame. Frozen + parent-transformed = the
                // whole point. The starfield is the stress test.
                SkyLabGridCanvas(camera: camera)
                    .equatable()
                // Horizon + twilight rings — native concentric circles
                // about the zenith, riding the parent transform.
                SkyLabHorizonCircles(camera: camera)
                SkyLabStarsCanvas(camera: camera, stars: app.sortedStars)
                    .equatable()
                // Curved cartographic labels — horizon rim + colures.
                // Canvas (per-glyph curve), frozen via .equatable().
                SkyLabCartographyLabels(camera:   camera,
                                        latitude: app.origin.latitude,
                                        date:     app.renderedObservationDate)
                    .equatable()
                // Tiered native labels — each object reveals at its
                // production zoom tier (see each overlay's gate):
                //   • favourite stars  — .followedStar  (badgeIn 70)
                //   • constellation names — tier ~190
                //   • proper-name stars — .namedStar    (badgeIn ~280)
                //   • Sun/Moon/planets  — bodies overlay (0 / 80)
                // Greek-letter stars: skipped for now.
                SkyLabConstellationLabelsOverlay(camera: camera,
                                                 pinch: effPinch,
                                                 scale: liveScale)
                SkyLabStarLabelsOverlay(camera: camera,
                                        stars: app.favouriteStars,
                                        pinch: effPinch,
                                        scale: liveScale,
                                        category: { .followedStar($0) })
                SkyLabStarLabelsOverlay(camera: camera,
                                        stars: Self.properNamedStars,
                                        pinch: effPinch,
                                        scale: liveScale,
                                        category: { .namedStar($0) })
                SkyLabBodiesOverlay(camera: camera,
                                    date:  app.renderedObservationDate,
                                    pinch: effPinch,
                                    scale: liveScale)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            // THE shared parent transform — both children, one commit.
            // ORDER MATTERS: scale (about centre) first, THEN the computed
            // translation. Keeping translation outside the scale is what
            // makes the pinch-release commit land exactly where the gesture
            // left it — see `applied` and the commit in the gesture.
            .scaleEffect(effPinch, anchor: .center)
            .offset(x: applied.width, y: applied.height)
            // Constrain the layout back to the screen (centres the oversize
            // content; overflow renders off-screen, ready for the pan).
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(.rect)
            // ONE combined gesture so pan + pinch (+ zoom-drag) commit in a
            // single `onEnded` — separate commits would double-count the
            // offset. `.first` = drag, `.second` = magnify. The zoom-drag
            // feeds the SAME `pinch`/`focal` as a pinch, so the live
            // transform and the commit below are one code path.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .simultaneously(with: MagnifyGesture())
                    .onChanged { v in
                        // Two-finger pinch (+ centroid pan).
                        if let m = v.second {
                            pinch = m.magnification
                            focal = m.startLocation
                            drag  = v.first?.translation ?? .zero
                            return
                        }
                        guard let d = v.first else { return }
                        // One finger: decide the mode once, at drag start.
                        if dragMode == nil {
                            dragMode = Date().timeIntervalSince(lastTapTime) < Self.doubleTapWindow
                                ? .zoom(anchor: d.startLocation)   // tap-then-drag
                                : .pan
                        }
                        switch dragMode {
                        case .zoom(let anchor):
                            // Vertical drag → zoom anchored at the tap. Drag
                            // up (negative height) zooms in.
                            focal = anchor
                            pinch = exp(-Double(d.translation.height) * Self.zoomDragSensitivity)
                            drag  = .zero
                        case .pan:
                            drag  = d.translation
                            pinch = 1
                        case .none:
                            break
                        }
                    }
                    .onEnded { _ in
                        // Quick double-tap (zoom mode, no real drag) → step
                        // zoom toward the tap.
                        if case .zoom = dragMode, abs(pinch - 1) < 0.02 {
                            let newScale = min(max(scale * Self.stepZoomFactor,
                                                   Self.minScale), Self.maxScale)
                            let cMag = scale > 0 ? newScale / scale : 1
                            withAnimation(.easeOut(duration: 0.22)) {
                                offset = CGSize(
                                    width:  (focal.x - center.x) * (1 - cMag) + offset.width  * cMag,
                                    height: (focal.y - center.y) * (1 - cMag) + offset.height * cMag
                                )
                                scale = newScale
                            }
                        } else {
                            // Continuous: fold the live transform (pinch /
                            // zoom-drag / pan) into the committed camera with
                            // the CLAMPED factor — no travel on release.
                            let newScale = min(max(scale * pinch, Self.minScale), Self.maxScale)
                            let cMag     = scale > 0 ? newScale / scale : 1
                            offset = CGSize(
                                width:  (focal.x - center.x) * (1 - cMag) + offset.width  * cMag + drag.width,
                                height: (focal.y - center.y) * (1 - cMag) + offset.height * cMag + drag.height
                            )
                            scale = newScale
                        }
                        drag     = .zero
                        pinch    = 1
                        dragMode = nil
                    }
            )
            // Stamps a tap so the NEXT one-finger drag is read as a
            // zoom-drag (the "double-tap-hold-drag"). A pan moves, so it
            // never registers as a tap.
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { _ in lastTapTime = Date() }
            )
        }
        // The label's casing is `.systemBackground` — designed to knock
        // stars out from behind the glyphs on a DARK sky, not to be a
        // bright outline. Without a dark background (and dark scheme) the
        // casing is invisible and the label reads borderless. Give the lab
        // the production night sky so labels render as intended.
        .background(EArtist.shared.canvasBackground)
//        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
}

#Preview {
    SkyLabView()
        .environment(EAppState())
}
