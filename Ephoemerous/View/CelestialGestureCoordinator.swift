import SwiftUI
import UIKit

// MARK: - CelestialGestureCoordinator
// A pure transform engine. It owns the tuning constants and the transient
// anchors a gesture needs across callbacks (pan origin, pinch/zoom-drag
// sky anchor, axis lock) and translates already-resolved UIKit recogniser
// deltas into writes on EAppState. It contains NO SwiftUI gesture: touch
// classification, double-tap timing and arbitration all live in
// CelestialGestureView's UIKit recognisers. Keeping the math here and the
// recognisers there is what kills the old per-frame feedback loop — these
// methods run on the main thread OUTSIDE the SwiftUI body rebuild, so a
// state write can no longer pollute the next finger sample.
@Observable
final class CelestialGestureCoordinator {

    // MARK: Transient interaction state

    private(set) var isPanningViewport    = false
    private(set) var isPinchingToZoom     = false
    private(set) var isZoomDragging       = false
    private(set) var isTwoFingerOriginPan = false

    private var viewportOffsetAtPanStart: CGPoint = .zero
    private var scaleAtPinchStart:        Double  = 0
    private var skyAnchorUnderFingers:    CGPoint = .zero
    private var pinchCentroidAtStart:     CGPoint = .zero   // for origin-nudge delta

    private var zoomDragStartScale:  Double  = 0
    private var zoomDragLastScale:   Double  = 0
    private var zoomDragAnchorSky:   CGPoint = .zero   // sky point pinned under the tap
    private var zoomDragAnchorScreen: CGPoint = .zero  // fixed screen point (the double-tap)

    // Two-finger origin nudge: remembers where origin was before the
    // gesture so we can spring it back on release.
    private var originAtTwoFingerStart:   Origin? = nil
    // Parallel snapshot for the NS-projection origin — the same Δlat /
    // Δlon gets applied to both during the drag, and both spring back
    // together on release.
    private var nsOriginAtTwoFingerStart: Origin? = nil

    /// True while the user is actively manipulating the canvas. The
    /// timeline reads this to stay at 60 fps for the duration.
    var isInteracting: Bool {
        isPanningViewport || isPinchingToZoom || isZoomDragging || isTwoFingerOriginPan
    }

    // MARK: Tuning

    private let coupledSensitivity:     Double = 0.0001
    private let originNudgeSensitivity: Double = 0.004  // ~23° per 100pt of two-finger drag
    private let coupledAxisLockSlop:    Double = 6      // pt before an axis locks
    private let minimumFlingSpeed:      Double = 150    // pt/s, below this: no inertia
    private let maximumFlingSpeed:      Double = 4000   // pt/s, clamp wild flicks
    private let tapMaxMovement:         Double = 10     // pt: beyond this it's a drag
    private let tapMaxDuration:         Double = 0.30   // s: longer (still) isn't a tap
    private let zoomDragSensitivity:    Double = 0.005  // scale e-fold per pt dragged
    private let zoomDragMaxStep:        Double = 0.40   // max |Δln(scale)| per event (de-gain)
    private let maximumScale:           Double = 300    // hard zoom-in ceiling, all gestures
    private let rubberC:                Double = 0.55   // iOS scroll rubber-band constant
    private let scaleOvershootFraction: Double = 0.12   // damped zoom-past-ceiling room
    private let doubleTapZoomFactor:    Double = 2.0

    // MARK: - Pan: one finger
    //
    // Clock mode: pans the viewport (rubber-band on overscroll, fling
    // inertia on release). Travel mode: moves the observer with axis
    // lock — pure single-axis nudges of latitude OR longitude, picked
    // by whichever drag direction wins the first `coupledAxisLockSlop`
    // of motion.

    func panBegan(state: EAppState) {
        commitAnyRunningPresetTransition(state: state)
        stopInertia(state: state)
    }

    func panChanged(translation t: CGSize, state: EAppState) {
        beginPanIfNeeded(state: state)
        switch state.appMode {
        case .clock:  panViewport(state: state, by: t)
        case .travel: moveObserverWithAxisLock(state: state, by: t)
        }
    }

    func panEnded(translation t: CGSize, velocity v: CGSize, state: EAppState) {
        if state.appMode == .clock {
            let clamped     = state.hardClampedOffset(state.offset, atScale: state.scale)
            let outOfBounds = hypot(clamped.x - state.offset.x,
                                    clamped.y - state.offset.y) > 0.5
            if outOfBounds { settleWithinBounds(state: state) }            // spring back
            else           { startInertiaIfFlung(state: state, velocity: v) }
        }
        endPan(state: state)
    }

    private func beginPanIfNeeded(state: EAppState) {
        guard !isPanningViewport else { return }
        isPanningViewport = true
        viewportOffsetAtPanStart = state.offset
    }

    private func panViewport(state: EAppState, by t: CGSize) {
        // t.width = horizontal (offset.y), t.height = vertical (offset.x).
        let raw = CGPoint(x: viewportOffsetAtPanStart.x + t.height,
                          y: viewportOffsetAtPanStart.y + t.width)
        state.offset = rubberOffset(raw, state: state, scale: state.scale)
    }

    private func endPan(state: EAppState) {
        isPanningViewport = false
        state.coupledAxis = nil          // release the axis lock for the next gesture
    }

    // Lock onto the first dominant axis, then walk the observer along it.
    private func moveObserverWithAxisLock(state: EAppState, by t: CGSize) {
        if state.coupledAxis == nil {
            let dx = abs(t.width)
            let dy = abs(t.height)
            guard dx > coupledAxisLockSlop || dy > coupledAxisLockSlop else { return }
            state.coupledAxis = dx > dy ? .horizontal : .vertical
        }

        let rawLat = state.origin.latitude  - .radians(t.height * coupledSensitivity)
        let newLat = Angle.radians(rawLat.radians.clamped(to: 0.1 ... .pi / 2 - 0.1))
        let rawLon = state.origin.longitude - .radians(t.width  * coupledSensitivity)
        let newLon = Angle.radians(rawLon.radians.truncatingRemainder(dividingBy: 2 * .pi))

        switch state.coupledAxis {
        case .vertical:
            emitTickIfDegreeChanged(from: state.origin.latitude, to: newLat,
                                    style: .light, state: state)
            state.setOrigin(lat: newLat, lon: state.origin.longitude)
        case .horizontal:
            emitTickIfDegreeChanged(from: state.origin.longitude, to: newLon,
                                    style: .rigid, state: state)
            state.setOrigin(lat: state.origin.latitude, lon: newLon)
        case nil:
            break
        }
    }

    // MARK: - Two-finger origin nudge (any app mode)
    //
    // Held two-finger drag moves origin freely (no axis lock, plane
    // untouched) and on release springs origin back to where the gesture
    // started via `animateOrigin(updatePlane: false)` — so the user
    // previews a position without the projection morphing under them.
    // Active in both modes; in clock mode the visible effect is on the
    // EarthGrid / Horizon / CardinalLabels (which read origin), with
    // the NS-projected celestial bodies staying put. Coexists with pinch
    // (delegate allows simultaneous recognition), so the user can
    // pan+zoom in one two-finger motion.

    func twoFingerOriginPanBegan(state: EAppState) {
        // Idempotent — pinch and twoFingerPan may both fire this on the
        // same gesture (one for pinch-drag, one for pure parallel drag).
        // First call wins; second is a no-op.
        guard !isTwoFingerOriginPan else { return }
        commitAnyRunningPresetTransition(state: state)
        stopInertia(state: state)
        isTwoFingerOriginPan     = true
        originAtTwoFingerStart   = state.origin
        nsOriginAtTwoFingerStart = state.nsOrigin
    }

    func twoFingerOriginPanChanged(translation t: CGSize, state: EAppState) {
        guard isTwoFingerOriginPan,
              let start   = originAtTwoFingerStart,
              let nsStart = nsOriginAtTwoFingerStart else { return }

        // Anchor on the snapshot rather than the live origin so the drag
        // is absolute (no drift across the gesture).
        let rawLat = start.latitude  - .radians(t.height * originNudgeSensitivity)
        let newLat = Angle.radians(rawLat.radians.clamped(to: -.pi / 2 ... .pi / 2))
        let rawLon = start.longitude - .radians(t.width  * originNudgeSensitivity)
        let newLon = Angle.radians(rawLon.radians.truncatingRemainder(dividingBy: 2 * .pi))
        // Direct mutation — bypass `setOrigin` so plane is preserved.
        state.origin.latitude  = newLat
        state.origin.longitude = newLon

        // Same Δlat / Δlon applied to the NS origin so the celestial
        // frame tilts in step with the observer frame. Plane is left
        // alone (it's hardcoded `.south` in the projection).
        let nsRawLat = nsStart.latitude  - .radians(t.height * originNudgeSensitivity)
        let nsNewLat = Angle.radians(nsRawLat.radians.clamped(to: -.pi / 2 ... .pi / 2))
        let nsRawLon = nsStart.longitude - .radians(t.width  * originNudgeSensitivity)
        let nsNewLon = Angle.radians(nsRawLon.radians.truncatingRemainder(dividingBy: 2 * .pi))
        state.nsOrigin.latitude  = nsNewLat
        state.nsOrigin.longitude = nsNewLon
    }

    func twoFingerOriginPanEnded(state: EAppState) {
        guard isTwoFingerOriginPan,
              let snapshot   = originAtTwoFingerStart,
              let nsSnapshot = nsOriginAtTwoFingerStart else { return }
        isTwoFingerOriginPan     = false
        originAtTwoFingerStart   = nil
        nsOriginAtTwoFingerStart = nil
        state.animateOrigin(to:          snapshot.latitude,
                            lon:         snapshot.longitude,
                            duration:    0.45,
                            updatePlane: false)
        state.animateNSOrigin(to:       nsSnapshot.latitude,
                              lon:      nsSnapshot.longitude,
                              duration: 0.45)
    }

    // MARK: - Pinch: two fingers  (Maps-style: scale + translate together)
    // The sky point under the two-finger centroid at gesture start is pinned
    // to the *live* centroid every callback. Because the centroid moves with
    // the fingers, that single reprojection gives scale-about-centroid AND
    // pan-follows-centroid at once — no second recogniser, no double-count.

    func pinchBegan(centroid c: CGPoint, state: EAppState) {
        commitAnyRunningPresetTransition(state: state)
        stopInertia(state: state)
        guard !isPinchingToZoom else { return }
        isPinchingToZoom      = true
        scaleAtPinchStart     = state.scale
        skyAnchorUnderFingers = skyPoint(under: c, state: state)
        // Origin nudge piggy-backs on pinch — pinch reliably tracks the
        // two-finger centroid, while a parallel UIPanGestureRecognizer
        // with min/max=2 loses the touch race with pinch.
        pinchCentroidAtStart = c
        twoFingerOriginPanBegan(state: state)
    }

    func pinchChanged(scale magnification: Double, centroid c: CGPoint,
                      state: EAppState) {
        let rawScale = scaleAtPinchStart * magnification
        let newScale = rubberScale(rawScale, state: state)
        // Pin to the START centroid rather than the live one. Scale
        // changes still anchor around the original pinch point (Maps-
        // style zoom-around-fingers), but pure finger TRANSLATION no
        // longer pans the viewport — that's the origin nudge's job.
        let pinned   = screenPin(sky: skyAnchorUnderFingers,
                                 under: pinchCentroidAtStart,
                                 scale: newScale, state: state)
        state.scale  = newScale
        state.offset = rubberOffset(homedTowardDefault(pinned,
                                                       rawScale: rawScale,
                                                       state: state),
                                    state: state, scale: newScale)
        // Origin nudge from the centroid's translation since pinch began.
        // Pure pinching (centroid stationary) → no origin shift; pure
        // two-finger drag → pure origin shift.
        twoFingerOriginPanChanged(
            translation: CGSize(width:  c.x - pinchCentroidAtStart.x,
                                height: c.y - pinchCentroidAtStart.y),
            state: state)
    }

    func pinchEnded(state: EAppState) {
        isPinchingToZoom = false
        settleWithinBounds(state: state)        // spring back from overshoot
        twoFingerOriginPanEnded(state: state)   // spring origin back
    }

    // MARK: - Double-tap-and-hold-drag zoom (continuous, anchored at the tap)

    func doubleHoldBegan(at anchor: CGPoint, state: EAppState) {
        commitAnyRunningPresetTransition(state: state)
        stopInertia(state: state)
        isZoomDragging       = true
        zoomDragStartScale   = state.scale
        zoomDragLastScale    = state.scale
        zoomDragAnchorScreen = anchor
        zoomDragAnchorSky    = skyPoint(under: anchor, state: state)
    }

    func doubleHoldChanged(translation t: CGSize, state: EAppState) {
        // Drag up (t.height < 0) → zoom in; down → zoom out.
        let target = zoomDragStartScale * exp(-t.height * zoomDragSensitivity)

        // De-gain: cap |Δln(scale)| per event so a single spurious sample
        // can't be amplified through the anchor lever into a huge offset
        // jump. With clean recogniser input this never binds.
        let prev    = zoomDragLastScale > 0 ? zoomDragLastScale : zoomDragStartScale
        let safeTgt = target.isFinite ? target : prev
        let lo      = prev * exp(-zoomDragMaxStep)
        let hi      = prev * exp( zoomDragMaxStep)
        let limited = Swift.min(Swift.max(safeTgt, lo), hi)

        let newScale = rubberScale(limited, state: state)
        zoomDragLastScale = newScale
        let pinned   = screenPin(sky: zoomDragAnchorSky,
                                 under: zoomDragAnchorScreen,
                                 scale: newScale, state: state)
        state.scale  = newScale
        state.offset = rubberOffset(homedTowardDefault(pinned,
                                                       rawScale: limited,
                                                       state: state),
                                    state: state, scale: newScale)
    }

    func doubleHoldEnded(translation t: CGSize, duration: Double,
                         state: EAppState) {
        let moved  = hypot(t.width, t.height)
        let wasTap = moved <= tapMaxMovement && duration <= tapMaxDuration
        // Quick double-tap (no real drag) → discrete step zoom. A real drag
        // applied continuous zoom live → just spring any overshoot back.
        if wasTap { zoomToward(point: zoomDragAnchorScreen, state: state) }
        else      { settleWithinBounds(state: state) }
        isZoomDragging = false
    }

    // MARK: - Discrete step zoom (quick double-tap)
    // Reuses the pinch anchor math so the tapped point stays pinned,
    // animated via the shared preset transition.

    private func zoomToward(point: CGPoint, state: EAppState) {
        let size = state.canvasSize
        guard size.width > 0, size.height > 0 else { return }

        let ceiling = maximumScale
        let floor   = state.defaultScale.isFinite
            ? Swift.min(state.defaultScale, ceiling) : 1
        let anchor  = skyPoint(under: point, state: state)

        // Zoom in a step; once at the ceiling the next double-tap zooms out.
        let atCeiling = state.scale >= ceiling - 0.5
        let target    = atCeiling
            ? floor
            : Swift.min(state.scale * doubleTapZoomFactor, ceiling)

        let newOffset = state.hardClampedOffset(
            screenPin(sky: anchor, under: point, scale: target, state: state),
            atScale: target)

        state._activeTransition = EPresetTransition(
            fromScale:  state.renderedScale,
            fromOffset: state.renderedOffset,
            toScale:    target,
            toOffset:   newOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        state.scale  = target
        state.offset = newOffset
    }

    // MARK: - Projection inversion / reprojection
    // Single source of truth for the screen⇄sky mapping every zoom uses.
    // Mirrors EGraphicContext.toScreen: offset.y is the horizontal shift,
    // offset.x the vertical.

    private func skyPoint(under screen: CGPoint, state: EAppState) -> CGPoint {
        let size = state.canvasSize
        return CGPoint(
            x: (screen.x - size.width  / 2 - state.offset.y) / state.scale,
            y: (size.height / 2 + state.offset.x - screen.y) / state.scale
        )
    }

    /// Offset that puts `sky` exactly under screen point `p` at `scale`.
    private func screenPin(sky: CGPoint, under p: CGPoint, scale: Double,
                           state: EAppState) -> CGPoint {
        let size = state.canvasSize
        return CGPoint(
            x: p.y - size.height / 2 + sky.y * scale,
            y: p.x - size.width  / 2 - sky.x * scale
        )
    }

    // Order- and NaN-safe scale clamp. Floor = defaultScale but never above
    // the hard ceiling; ceiling = maximumScale.
    private func clampScale(_ candidate: Double, state: EAppState) -> Double {
        let df    = state.defaultScale
        let floor = df.isFinite ? Swift.min(df, maximumScale) : 1
        guard candidate.isFinite else { return floor }
        return Swift.min(Swift.max(candidate, floor), maximumScale)
    }

    // MARK: - Rubber-band (offset & scale boundaries)

    // iOS UIScrollView damping: past `limit`, each extra point of pull
    // yields progressively less travel, asymptotic to `limit + dim`.
    private func rubber(_ v: Double, limit: Double, dim: Double) -> Double {
        let a = abs(v)
        guard a > limit, dim > 0 else { return v }
        let over   = a - limit
        let damped = (1 - 1 / (over * rubberC / dim + 1)) * dim
        return (v < 0 ? -1.0 : 1.0) * (limit + damped)
    }

    // Offset with rubber resistance past the map-like disc limits.
    private func rubberOffset(_ raw: CGPoint, state: EAppState,
                              scale s: Double) -> CGPoint {
        guard let lim = state.viewportOffsetLimits(forScale: s) else { return raw }
        // Resist relative to defaultOffset (the home), not screen-centre.
        let c = state.defaultOffset
        return CGPoint(
            x: c.x + rubber(raw.x - c.x, limit: lim.x, dim: state.canvasSize.height),
            y: c.y + rubber(raw.y - c.y, limit: lim.y, dim: state.canvasSize.width)
        )
    }

    // Zoom-out reset. While the raw (pre-rubber) scale is pulled below
    // `defaultScale` — the zoom-out rubber zone — blend the offset home
    // toward `defaultOffset` in step with how far it's pulled. So pinching
    // or hold-dragging all the way out lands on the exact initial view
    // (default scale AND offset), not just the initial scale. f = 0 at the
    // floor (offset stays pinned), → 1 as the scale is pulled toward 0.
    private func homedTowardDefault(_ pinned: CGPoint, rawScale: Double,
                                    state: EAppState) -> CGPoint {
        let floor = state.defaultScale.isFinite
            ? Swift.min(state.defaultScale, maximumScale) : 1
        guard rawScale.isFinite, rawScale < floor, floor > 0 else { return pinned }
        let f = Swift.min(Swift.max((floor - rawScale) / floor, 0), 1)
        let d = state.defaultOffset
        return CGPoint(x: pinned.x + (d.x - pinned.x) * f,
                       y: pinned.y + (d.y - pinned.y) * f)
    }

    // Scale with damped overshoot past floor / ceiling (springs back on release).
    private func rubberScale(_ raw: Double, state: EAppState) -> Double {
        let ceiling = maximumScale
        let floor   = state.defaultScale.isFinite
            ? Swift.min(state.defaultScale, ceiling) : 1
        guard raw.isFinite else { return floor }
        if raw > ceiling {
            let over = raw - ceiling
            return ceiling + (1 - 1 / (over * rubberC / ceiling + 1)) * (ceiling * scaleOvershootFraction)
        }
        if raw < floor {
            let over = floor - raw
            return floor - (1 - 1 / (over * rubberC / floor + 1)) * (floor * 0.45)
        }
        return raw
    }

    // On gesture end: if scale/offset overshot, spring back to the exact
    // limits via the shared preset transition (its bounce reads as "edge").
    private func settleWithinBounds(state: EAppState) {
        let targetScale  = clampScale(state.scale, state: state)
        let targetOffset = state.hardClampedOffset(state.offset, atScale: targetScale)
        let dScale  = abs(targetScale - state.scale)
        let dOffset = hypot(targetOffset.x - state.offset.x,
                            targetOffset.y - state.offset.y)
        guard dScale > 0.01 || dOffset > 0.5 else { return }
        state._activeTransition = EPresetTransition(
            fromScale:  state.renderedScale,
            fromOffset: state.renderedOffset,
            toScale:    targetScale,
            toOffset:   targetOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        state.scale  = targetScale
        state.offset = targetOffset
    }

    // MARK: - Inertia

    private func startInertiaIfFlung(state: EAppState, velocity: CGSize) {
        let speed = hypot(velocity.width, velocity.height)
        guard speed > minimumFlingSpeed else { return }
        let damp = min(1, maximumFlingSpeed / speed)   // clamp wild flicks
        let now  = Date().timeIntervalSinceReferenceDate
        state._inertiaTransition = EInertiaTransition(
            velX: velocity.height * damp,   // offset.x follows vertical
            velY: velocity.width  * damp,   // offset.y follows horizontal
            startTime:       now,
            lastEmittedTime: now
        )
    }

    private func stopInertia(state: EAppState) {
        if state._inertiaTransition != nil { state._inertiaTransition = nil }
    }

    // MARK: - Helpers

    private func commitAnyRunningPresetTransition(state: EAppState) {
        guard state._activeTransition != nil else { return }
        state.scale  = state.renderedScale
        state.offset = state.renderedOffset
        state._activeTransition = nil
    }

    private func emitTickIfDegreeChanged(from old: Angle, to new: Angle,
                                         style: UIImpactFeedbackGenerator.FeedbackStyle,
                                         state: EAppState) {
        guard state.haptics, Int(old.degrees) != Int(new.degrees) else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - EInertiaTransition
// Momentum glide after a flick. Velocity decays exponentially:
//   v(t) = v0 · e^(−k·t)
// Each frame emits the *exact* integral of v over the elapsed slice, so the
// distance travelled is identical no matter the frame rate.
struct EInertiaTransition {
    let velX:      Double      // pt/s along offset.x  (follows vertical)
    let velY:      Double      // pt/s along offset.y  (follows horizontal)
    let startTime: Double
    var lastEmittedTime: Double

    /// Decay rate (1/s). Higher = shorter, snappier glide. Total travel ≈ v0 / k.
    let decayRate:         Double = 80.0
    /// Stop once speed has fallen to this fraction of the launch speed.
    let stopSpeedFraction: Double = 0.02

    /// Returns the offset delta to apply for the slice
    /// [lastEmittedTime, time] and whether the glide has settled.
    /// `advance` is mutating: it remembers how far it has already emitted.
    mutating func advance(to time: Double) -> (dx: Double, dy: Double, isFinished: Bool) {
        let k  = decayRate
        let t0 = max(0, lastEmittedTime - startTime)
        let t1 = max(t0, time - startTime)
        // ∫ v0·e^(−k·t) dt  from t0 to t1  =  (v0/k)·(e^(−k·t0) − e^(−k·t1))
        let span = (exp(-k * t0) - exp(-k * t1)) / k
        lastEmittedTime = time
        let finished = exp(-k * t1) < stopSpeedFraction
        return (velX * span, velY * span, finished)
    }
}
