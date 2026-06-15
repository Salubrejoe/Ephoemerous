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
    @State private var scale:  CGFloat = 90
    @State private var offset: CGSize  = .zero

    // Transient gesture deltas — applied to the shared parent transform,
    // folded into the committed camera on release.
    @State private var drag:  CGSize  = .zero
    @State private var pinch: CGFloat = 1
    /// Pinch focal point in screen coords (the centroid the gesture
    /// started on) — the zoom anchors here instead of the screen centre.
    @State private var focal: CGPoint = .zero

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
                size:      canvasSize,
                viewpoint: app.viewpoint,
                sidereal:  app.localSiderealOffset
            )

            // Screen centre — the `.scaleEffect(anchor: .center)` fixed
            // point, and the reference the focal compensation works from.
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            // Total translation applied OUTSIDE the scale. Three terms:
            //   • `(focal − center)·(1 − pinch)` — focal compensation. The
            //     scaleEffect zooms about screen centre; this shifts so the
            //     sky point under the FINGERS stays under the fingers.
            //   • `offset · pinch` — the committed pan, scaled, because a
            //     zoom about a point scales the whole already-panned image.
            //   • `drag` — live one-finger / centroid pan.
            // At rest (pinch 1, drag 0) this is exactly `offset`.
            let applied = CGSize(
                width:  (focal.x - center.x) * (1 - pinch) + offset.width  * pinch + drag.width,
                height: (focal.y - center.y) * (1 - pinch) + offset.height * pinch + drag.height
            )

            ZStack {
                // `.equatable()` → these Canvases redraw only when the
                // committed camera changes (a settle / date / origin move),
                // NOT per gesture frame. Frozen + parent-transformed = the
                // whole point. The starfield is the stress test.
                SkyLabGridCanvas(camera: camera)
                    .equatable()
                SkyLabStarsCanvas(camera: camera, stars: app.sortedStars)
                    .equatable()
                SkyLabSunLabel(camera: camera,
                               date:  app.renderedObservationDate,
                               pinch: pinch)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            // THE shared parent transform — both children, one commit.
            // ORDER MATTERS: scale (about centre) first, THEN the computed
            // translation. Keeping translation outside the scale is what
            // makes the pinch-release commit land exactly where the gesture
            // left it — see `applied` and the commit in the gesture.
            .scaleEffect(pinch, anchor: .center)
            .offset(x: applied.width, y: applied.height)
            // Constrain the layout back to the screen (centres the oversize
            // content; overflow renders off-screen, ready for the pan).
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(.rect)
            // ONE combined gesture so pan + pinch commit in a single
            // `onEnded` — two separate gesture commits would double-count
            // the offset. `.first` = drag, `.second` = magnify.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .simultaneously(with: MagnifyGesture())
                    .onChanged { v in
                        drag = v.first?.translation ?? .zero
                        if let m = v.second {
                            pinch = m.magnification
                            focal = m.startLocation
                        }
                    }
                    .onEnded { v in
                        let mag = v.second?.magnification ?? 1
                        let f   = v.second?.startLocation ?? center
                        let tr  = v.first?.translation ?? .zero
                        // Fold the live transform into the committed camera
                        // with the SAME formula `applied` uses, so the
                        // resting render reproduces the final gesture frame.
                        offset = CGSize(
                            width:  (f.x - center.x) * (1 - mag) + offset.width  * mag + tr.width,
                            height: (f.y - center.y) * (1 - mag) + offset.height * mag + tr.height
                        )
                        scale *= mag
                        drag  = .zero
                        pinch = 1
                    }
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
