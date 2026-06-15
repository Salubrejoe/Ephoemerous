import SwiftUI

// MARK: - SkyLabGestureCoordinator
// Gesture engine for the SkyLab, modelled on the production
// CelestialGestureCoordinator (UIKit recognisers → pure math), but
// adapted to the lab's FREEZE model: it never touches the committed
// camera mid-gesture. Instead each recogniser writes the LIVE deltas
// (`pinch` / `drag` / `focal` / `liveRotation`) that drive the parent
// transform, and the committed camera (`scale` / `offset` / `rotation`)
// is folded ONCE when the last recogniser ends — so the `.equatable()`
// Canvases stay frozen through the whole interaction.
//
// No rubber / inertia / recentering yet (deliberately). Hard scale clamp.
@Observable
final class SkyLabGestureCoordinator {

    // Committed camera — FROZEN during a gesture.
    var scale:    CGFloat = 90
    var offset:   CGSize  = .zero
    var rotation: Angle   = .zero

    // Live gesture deltas — drive the parent transform; reset on commit.
    var pinch:        CGFloat = 1
    var drag:         CGSize  = .zero
    var focal:        CGPoint = .zero
    var liveRotation: Angle   = .zero

    // Config, set by the view each layout.
    @ObservationIgnored var center:   CGPoint = .zero
    @ObservationIgnored var minScale: CGFloat = 90
    @ObservationIgnored var maxScale: CGFloat = 1200

    // Transient interaction bookkeeping (not observed).
    @ObservationIgnored private var active     = 0          // live recogniser count
    @ObservationIgnored private var pinchStart = CGPoint.zero
    @ObservationIgnored private var holdAnchor = CGPoint.zero

    private let zoomDragSensitivity = 0.006
    private let stepZoomFactor: CGFloat = 2

    // MARK: Derived (read by the view)

    /// Clamped live scale — the wall (no rubber). Drives the tier gates.
    var liveScale: CGFloat { Swift.min(Swift.max(scale * pinch, minScale), maxScale) }
    /// Magnification actually applied this frame (clamped).
    var effPinch:  CGFloat { scale > 0 ? liveScale / scale : 1 }
    /// Live translation for the parent `.offset` — focal compensation
    /// (keeps the pinch point under the fingers) + live pan. The
    /// committed pan lives in the camera, so it isn't here.
    var applied: CGSize {
        CGSize(width:  (focal.x - center.x) * (1 - effPinch) + drag.width,
               height: (focal.y - center.y) * (1 - effPinch) + drag.height)
    }

    // MARK: Pan (1 finger)

    func panBegan() { active += 1 }
    func panChanged(_ t: CGSize) { drag = t; pinch = 1 }
    func panEnded() { endOne() }

    // MARK: Pinch (2 fingers, Maps-style: scale about + pan with centroid)

    func pinchBegan(centroid c: CGPoint) { active += 1; pinchStart = c; focal = c }
    func pinchChanged(scale s: CGFloat, centroid c: CGPoint) {
        pinch = s
        focal = pinchStart
        drag  = CGSize(width: c.x - pinchStart.x, height: c.y - pinchStart.y)
    }
    func pinchEnded() { endOne() }

    // MARK: Rotation (2 fingers)

    func rotationBegan() { active += 1 }
    func rotationChanged(_ radians: Double) { liveRotation = .radians(radians) }
    func rotationEnded() { endOne() }

    // MARK: Double-tap-hold-drag zoom (anchored at the tap)

    func holdBegan(at p: CGPoint) { active += 1; holdAnchor = p; focal = p }
    func holdChanged(_ t: CGSize) {
        focal = holdAnchor
        pinch = CGFloat(exp(-Double(t.height) * zoomDragSensitivity))  // up = zoom in
        drag  = .zero
    }
    func holdEnded(wasTap: Bool) {
        if wasTap { stepZoom(at: holdAnchor); resetLive() }  // quick double-tap → step
        endOne()
    }

    // MARK: Commit (fold live → committed when ALL recognisers end)

    private func endOne() {
        active -= 1
        if active <= 0 { active = 0; commit() }
    }

    private func commit() {
        let newScale = Swift.min(Swift.max(scale * pinch, minScale), maxScale)
        let cMag = scale > 0 ? newScale / scale : 1
        // Rotation is about centre → the committed offset rotates by the
        // live angle (and scales by cMag); same algebra as the live frame,
        // so the resting render reproduces it exactly (no travel).
        let lr = liveRotation.radians
        let rc = CGFloat(cos(lr)), rs = CGFloat(sin(lr))
        let rox = (offset.width * rc - offset.height * rs) * cMag
        let roy = (offset.width * rs + offset.height * rc) * cMag
        offset = CGSize(width:  (focal.x - center.x) * (1 - cMag) + rox + drag.width,
                        height: (focal.y - center.y) * (1 - cMag) + roy + drag.height)
        scale    = newScale
        rotation = rotation + liveRotation
        resetLive()
    }

    private func stepZoom(at anchor: CGPoint) {
        let newScale = Swift.min(Swift.max(scale * stepZoomFactor, minScale), maxScale)
        let cMag = scale > 0 ? newScale / scale : 1
        offset = CGSize(width:  (anchor.x - center.x) * (1 - cMag) + offset.width  * cMag,
                        height: (anchor.y - center.y) * (1 - cMag) + offset.height * cMag)
        scale = newScale
    }

    private func resetLive() { pinch = 1; drag = .zero; liveRotation = .zero }
}
