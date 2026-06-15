import SwiftUI

// MARK: - SkyLabGestureCoordinator
// Gesture engine for the SkyLab, modelled on the production
// CelestialGestureCoordinator (UIKit recognisers → pure math), adapted to
// the lab's FREEZE model.
//
// THE SYNC RULE: every motion — live gesture AND its release (fling /
// spring / recenter) — drives the LIVE deltas, never the committed
// camera. The deltas feed the one shared parent transform
// (`.scaleEffect` / `.rotationEffect` / `.offset`), so all layers (frozen
// Canvases + native overlays) move as one. The committed camera is folded
// ONCE, when the release animation completes — re-rendering crisp from
// where the transform left it (no jump, no desync).
//
// Physics ported from production: rubberScale (progressive log-space
// spring, never a wall), recenter-on-zoom-out (offset homes below
// defaultScale), inertia (pan fling glides on).
@Observable
final class SkyLabGestureCoordinator {

    // Committed camera — FROZEN during a gesture AND its release.
    var scale:    CGFloat = 90
    var offset:   CGSize  = .zero
    var rotation: Angle   = .zero

    // Live deltas — drive the parent transform (gesture + release); the
    // release ANIMATES these, so the transform animates and all layers
    // stay in lockstep. Reset to identity on commit.
    var pinch:        CGFloat = 1
    var drag:         CGSize  = .zero
    var focal:        CGPoint = .zero
    var liveRotation: Angle   = .zero
    var homeBlend:    CGFloat = 0     // 0 = none, 1 = offset fully homed (recenter)

    // Config, set by the view.
    @ObservationIgnored var center: CGPoint = .zero

    // Limits / feel — production values.
    @ObservationIgnored var minScale:     CGFloat = 90
    @ObservationIgnored var maxScale:     CGFloat = 1200
    @ObservationIgnored var defaultScale: CGFloat = 90
    private let scaleRubberStiffness = 2.0
    private let minFlingSpeed: CGFloat = 150
    private let maxFlingSpeed: CGFloat = 4000
    private let flingDecay:    CGFloat = 16
    private let zoomDragSensitivity = 0.006
    private let stepZoomFactor: CGFloat = 2

    @ObservationIgnored private var active     = 0
    @ObservationIgnored private var pinchStart = CGPoint.zero
    @ObservationIgnored private var holdAnchor = CGPoint.zero
    @ObservationIgnored private var flingVel   = CGSize.zero
    @ObservationIgnored private var releaseID  = 0     // invalidates a superseded completion

    // MARK: Scale model

    private var floorScale: CGFloat { Swift.min(minScale, defaultScale) }

    private func rubberScale(_ raw: CGFloat) -> CGFloat {
        guard raw.isFinite, raw > 0 else { return floorScale }
        let k  = scaleRubberStiffness
        let L  = log(Double(raw)), Lc = log(Double(maxScale)), Lf = log(Double(floorScale))
        if L > Lc { return CGFloat(exp(Lc + log(1 + k * (L - Lc)) / k)) }
        if L < Lf { return CGFloat(exp(Lf - log(1 + k * (Lf - L)) / k)) }
        return raw
    }
    private func clampScale(_ s: CGFloat) -> CGFloat {
        s.isFinite ? Swift.min(Swift.max(s, floorScale), maxScale) : floorScale
    }
    /// 0 at/above defaultScale → 1 as the raw scale is pulled toward 0.
    private func homedFraction(_ raw: CGFloat) -> CGFloat {
        guard raw.isFinite, raw < defaultScale, defaultScale > 0 else { return 0 }
        return Swift.min(Swift.max((defaultScale - raw) / defaultScale, 0), 1)
    }

    // MARK: Derived (read by the view)

    var liveScale: CGFloat { rubberScale(scale * pinch) }
    var effPinch:  CGFloat { scale > 0 ? liveScale / scale : 1 }
    var applied: CGSize {
        let ep = effPinch
        let hb = homeBlend
        // Effective on-screen offset (no homing) = the scaleEffect's pull
        // on the committed offset + focal compensation + live pan. Homing
        // eases the WHOLE of it toward 0 — a TRUE recentre — not just the
        // committed part (the old bug left the focal term behind, so it
        // recentred off-centre). The parent `.offset` is that homed
        // effective minus the scaleEffect part (`ep·offset`).
        let effW = ep * offset.width  + (focal.x - center.x) * (1 - ep) + drag.width
        let effH = ep * offset.height + (focal.y - center.y) * (1 - ep) + drag.height
        return CGSize(width:  (1 - hb) * effW - ep * offset.width,
                      height: (1 - hb) * effH - ep * offset.height)
    }

    // MARK: Recogniser input

    func panBegan() { begin() }
    func panChanged(_ t: CGSize) { drag = t; pinch = 1; homeBlend = homedFraction(scale) }
    func panEnded(velocity v: CGSize) { flingVel = v; endOne() }

    func pinchBegan(centroid c: CGPoint) { begin(); pinchStart = c; focal = c }
    func pinchChanged(scale s: CGFloat, centroid c: CGPoint) {
        pinch = s
        focal = pinchStart
        drag  = CGSize(width: c.x - pinchStart.x, height: c.y - pinchStart.y)
        homeBlend = homedFraction(scale * s)
    }
    func pinchEnded() { endOne() }

    func rotationBegan() { begin() }
    func rotationChanged(_ radians: Double) { liveRotation = .radians(radians) }
    func rotationEnded() { endOne() }

    func holdBegan(at p: CGPoint) { begin(); holdAnchor = p; focal = p }
    func holdChanged(_ t: CGSize) {
        focal = holdAnchor
        pinch = CGFloat(exp(-Double(t.height) * zoomDragSensitivity))
        drag  = .zero
        homeBlend = homedFraction(scale * pinch)
    }
    func holdEnded(wasTap: Bool) {
        active -= 1
        guard active <= 0 else { return }
        active = 0
        if wasTap { stepZoom() } else { release() }
    }

    // MARK: Lifecycle

    private func begin() {
        if active == 0 {
            // Interrupt any in-flight release: fold what's on screen now,
            // invalidate its pending completion, start clean.
            releaseID += 1
            if pinch != 1 || drag != .zero || liveRotation != .zero || homeBlend != 0 {
                commitLive()
            }
        }
        active += 1
        flingVel = .zero
    }

    private func endOne() {
        active -= 1
        guard active <= 0 else { return }
        active = 0
        release()
    }

    /// Animate the LIVE deltas to their settled values — fling glide, or
    /// spring back / recenter — then fold ONCE on completion. Everything
    /// rides the parent transform, so the layers stay synced.
    private func release() {
        let raw          = scale * pinch
        let settledScale = clampScale(raw)
        let overshoot    = abs(settledScale - raw) > 0.5
        let zoomedOut    = settledScale <= defaultScale + 0.5
        let speed        = hypot(flingVel.width, flingVel.height)
        releaseID += 1
        let id = releaseID

        // Inertia: a fling, in-bounds and zoomed-in, glides the live pan on.
        if !overshoot, !zoomedOut, speed > minFlingSpeed {
            let damp   = Swift.min(1, maxFlingSpeed / speed)
            let target = CGSize(width:  drag.width  + flingVel.width  * damp / flingDecay,
                                height: drag.height + flingVel.height * damp / flingDecay)
            withAnimation(.easeOut(duration: 0.7)) { drag = target }
                completion: { if self.releaseID == id { self.commitLive() } }
            return
        }

        // Settle: spring scale to the limit; home the offset if zoomed out.
        let targetPinch = scale > 0 ? settledScale / scale : 1
        let targetHome: CGFloat = zoomedOut ? 1 : 0
        let still = abs(targetPinch - pinch) < 0.001
            && abs(targetHome - homeBlend) < 0.001
            && drag == .zero && liveRotation == .zero
        if still { commitLive(); return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            pinch     = targetPinch
            homeBlend = targetHome
            // drag / liveRotation are already committed-relative; leave them.
        } completion: { if self.releaseID == id { self.commitLive() } }
    }

    /// Quick double-tap → animated step zoom toward the tap (live pinch).
    private func stepZoom() {
        let target = scale > 0 ? clampScale(scale * stepZoomFactor) / scale : 1
        releaseID += 1
        let id = releaseID
        withAnimation(.easeOut(duration: 0.25)) { pinch = target }
            completion: { if self.releaseID == id { self.commitLive() } }
    }

    /// Fold the current LIVE state into the committed camera, then reset
    /// the deltas to identity. Because the parent transform already shows
    /// this state, the re-render lands exactly here — no jump.
    private func commitLive() {
        let settled = rubberScale(scale * pinch)
        let cMag = scale > 0 ? settled / scale : 1
        let lr = liveRotation.radians
        let rc = CGFloat(cos(lr)), rs = CGFloat(sin(lr))
        let hb = homeBlend
        // Whole effective offset (rotated committed offset + focal comp +
        // pan), then homed toward 0 by `hb` — so hb = 1 lands exactly at
        // centre, matching the live `applied`.
        let effW = cMag * (offset.width * rc - offset.height * rs) + (focal.x - center.x) * (1 - cMag) + drag.width
        let effH = cMag * (offset.width * rs + offset.height * rc) + (focal.y - center.y) * (1 - cMag) + drag.height
        offset   = CGSize(width: (1 - hb) * effW, height: (1 - hb) * effH)
        scale    = settled
        rotation = rotation + liveRotation
        pinch = 1; drag = .zero; liveRotation = .zero; homeBlend = 0
    }
}
