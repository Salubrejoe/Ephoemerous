import SwiftUI
import UIKit

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
//
// STEPPED REFRESH: a long pinch no longer waits for the release to look
// right. Each time the live zoom crosses `refreshStep` away from the
// committed camera, the live state folds into the camera MID-GESTURE
// (`commitLive`, jump-free by construction) and the gesture re-bases on
// it — so the frozen Canvases redraw crisp at the new zoom, with the right
// dot sizes and the fainter stars let in, a few times per pinch instead of
// once at the end. The way Maps steps through its tile levels.
@Observable
final class MainGestureCoordinator {

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
    /// Tap hit-test, supplied by the view (it owns the camera + catalogue).
    /// Called with the tap location in screen points.
    @ObservationIgnored var onTap: ((CGPoint) -> Void)?
    /// Fired when a camera-manipulation gesture (pan / pinch / rotation /
    /// hold) begins — the view uses it to drop compass mode so grabbing the
    /// canvas hands control back to touch. Runs before the gesture's own
    /// begin bookkeeping.
    @ObservationIgnored var onGestureStart: (() -> Void)?

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

    // Stepped refresh (see the header). The recognisers report CUMULATIVE
    // values since the gesture began; after a mid-gesture fold these are
    // what the next values are measured from.
    /// Zoom ratio, live against committed, that triggers a refresh. ▼ TWEAK ▼
    private let refreshStep: CGFloat = 1.35
    @ObservationIgnored private var pinchBase:      CGFloat = 1
    @ObservationIgnored private var lastPinchScale: CGFloat = 1
    @ObservationIgnored private var lastCentroid:   CGPoint = .zero
    @ObservationIgnored private var rotationBase:   Double  = 0
    @ObservationIgnored private var lastRotation:   Double  = 0
    @ObservationIgnored private var holdBase:       CGFloat = 0
    @ObservationIgnored private var lastHoldY:      CGFloat = 0
    @ObservationIgnored private var holding = false

    // North detent — within ±threshold of north the rotation sticks to 0
    // with one haptic tick on entry (production's "realign right").
    private let northSnap: Double = 7 * .pi / 180
    @ObservationIgnored private var northEngaged = false
    @ObservationIgnored private let rotationHaptic = UIImpactFeedbackGenerator(style: .rigid)

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

    func pinchBegan(centroid c: CGPoint) {
        begin(); pinchStart = c; focal = c
        pinchBase = 1; lastPinchScale = 1; lastCentroid = c
    }
    func pinchChanged(scale s: CGFloat, centroid c: CGPoint) {
        lastPinchScale = s; lastCentroid = c
        pinch = s / pinchBase
        focal = pinchStart
        drag  = CGSize(width: c.x - pinchStart.x, height: c.y - pinchStart.y)
        homeBlend = homedFraction(scale * pinch)
        refreshIfStepped()
    }
    func pinchEnded() { endOne() }

    func rotationBegan() {
        begin()
        rotationBase = 0; lastRotation = 0
        // Don't re-tick if we START already aligned with north.
        northEngaged = abs(Self.wrapPi(rotation.radians)) <= northSnap
        rotationHaptic.prepare()
    }
    func rotationChanged(_ cumulative: Double) {
        lastRotation = cumulative
        let radians  = cumulative - rotationBase
        // Total displayed rotation if we applied the raw delta.
        let total = Self.wrapPi(rotation.radians + radians)
        if abs(total) <= northSnap {
            // Inside the detent → hold the TOTAL at north (live delta
            // cancels the committed rotation); tick once on entry.
            if !northEngaged { northEngaged = true; rotationHaptic.impactOccurred() }
            liveRotation = .radians(-rotation.radians)
        } else {
            northEngaged = false
            liveRotation = .radians(radians)
        }
    }
    func rotationEnded() { endOne() }

    /// Fold an angle into (−π, π].
    private static func wrapPi(_ a: Double) -> Double {
        var x = a.truncatingRemainder(dividingBy: 2 * .pi)
        if x >  .pi { x -= 2 * .pi }
        if x < -.pi { x += 2 * .pi }
        return x
    }

    func holdBegan(at p: CGPoint) {
        begin(); holdAnchor = p; focal = p
        holdBase = 0; lastHoldY = 0; holding = true
    }
    func holdChanged(_ t: CGSize) {
        lastHoldY = t.height
        focal = holdAnchor
        pinch = CGFloat(exp(-Double(t.height - holdBase) * zoomDragSensitivity))
        drag  = .zero
        homeBlend = homedFraction(scale * pinch)
        refreshIfStepped()
    }
    func holdEnded(wasTap: Bool) {
        holding = false
        active -= 1
        guard active <= 0 else { return }
        active = 0
        if wasTap { stepZoom() } else { release() }
    }

    func tapped(at p: CGPoint) { onTap?(p) }

    // MARK: Selection / comfort-zone pan

    /// True when nothing is animating or being touched — the committed
    /// camera IS what's on screen, so a hit-test against it is valid.
    var isResting: Bool {
        active == 0 && pinch == 1 && drag == .zero
            && liveRotation == .zero && homeBlend == 0
    }

    /// Cancel any in-flight release and fold what's on screen into the
    /// committed camera (no jump). Used to interrupt a fling on tap.
    func settleNow() {
        releaseID += 1
        if pinch != 1 || drag != .zero || liveRotation != .zero || homeBlend != 0 {
            commitLive()
        }
    }

    /// Glide the camera home — default scale, centred — via the LIVE deltas
    /// (animated pinch + full homeBlend), folding once on completion. Same
    /// synced primitive as the release spring, so the frozen Canvases ride
    /// the parent transform instead of snapping. Used when the date crown
    /// presents: the time-ring must sit exactly on the horizon circle, which
    /// only holds at the default centred framing.
    func glideHome() { glide(to: defaultScale) }

    /// Glide to an ARBITRARY committed scale, same synced primitive as
    /// `glideHome` — the live pinch animates and folds once on completion,
    /// so every layer rides the parent transform and nothing desyncs.
    /// The date picker uses it to make room for the crown.
    func glide(to targetScale: CGFloat) {
        releaseID += 1
        let id = releaseID
        let targetPinch = scale > 0 ? targetScale / scale : 1
        let still = abs(targetPinch - pinch) < 0.001
            && offset == .zero && drag == .zero && homeBlend == 0
        if still { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            pinch     = targetPinch
            homeBlend = 1
        } completion: { if self.releaseID == id { self.commitLive() } }
    }

    /// Comfort-zone pan: glide the LIVE drag to `target` (a screen-space
    /// translation), then fold once on completion. Same synced primitive as
    /// the fling — every layer rides the parent transform, so nothing
    /// desyncs. Caller guarantees `isResting` (drag starts from identity).
    func focusPan(dragTarget target: CGSize) {
        guard target != .zero else { return }
        releaseID += 1
        let id = releaseID
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            drag = target
        } completion: { if self.releaseID == id { self.commitLive() } }
    }

    // MARK: Lifecycle

    private func begin() {
        // A touch is taking over — let the view drop compass mode first, so
        // the committed camera it freezes is the one this gesture builds on.
        if active == 0 { onGestureStart?() }
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

    // MARK: Stepped refresh

    /// Mid-gesture, fold the live zoom into the camera once it has drifted
    /// `refreshStep` from it, then re-base the gesture so it carries on
    /// seamlessly from the folded state. Skipped while the scale is in its
    /// rubber band or homing — there the live transform is doing physics
    /// the camera must not bake in.
    private func refreshIfStepped() {
        guard active > 0, homeBlend == 0 else { return }
        let raw = scale * pinch
        guard raw >= floorScale, raw <= maxScale,
              pinch >= refreshStep || pinch <= 1 / refreshStep else { return }
        commitLive()
        // The folded state is now the camera; measure what comes next from
        // the recognisers' current cumulative values.
        pinchBase    = lastPinchScale
        pinchStart   = lastCentroid
        focal        = lastCentroid
        rotationBase = lastRotation
        if holding { holdBase = lastHoldY; focal = holdAnchor }
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
