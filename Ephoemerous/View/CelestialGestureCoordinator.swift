import SwiftUI
import UIKit

// MARK: - CelestialGestureCoordinator
// Owns every touch interaction for the celestial canvas and keeps the
// transient gesture state that must survive across individual callbacks
// (pan origin, pinch anchor, axis lock). All persistent view state still
// lives on EAppState — this object only translates fingers into intent.
//
// One drag gesture, one pinch gesture. The drag does different work per
// projection mode; the pinch always zooms about the finger midpoint.
// They never write the viewport at the same time: the drag stands down
// while a pinch is in progress, so two fingers can't fight over `offset`.
@Observable
final class CelestialGestureCoordinator {

    // MARK: Transient interaction state

    private(set) var isPanningViewport = false
    private(set) var isPinchingToZoom  = false
    private(set) var isZoomDragging    = false

    private var viewportOffsetAtPanStart: CGPoint = .zero
    private var scaleAtPinchStart:        Double  = 0
    private var skyAnchorUnderFingers:    CGPoint = .zero

    // One-finger touch classification (tap / double-tap / double-tap-drag / pan).
    private enum TouchPhase { case undecided, panning, zoomDragging }
    private var phase:             TouchPhase = .undecided
    private var touchStamped:      Bool       = false   // stamp start once per touch
    private var touchStartTime:    Date       = .distantPast
    private var touchStartPoint:   CGPoint    = .zero
    private var lastTapEndedAt:    Date       = .distantPast
    private var lastTapPoint:      CGPoint    = .zero
    private var zoomDragStartScale: Double    = 0
    private var zoomDragAnchorSky:  CGPoint   = .zero   // sky point pinned under the tap
    private var zoomDragAnchorScreen: CGPoint = .zero   // fixed screen point (the double-tap)

    /// True while the user is actively manipulating the canvas. The
    /// timeline reads this to stay at 60 fps for the duration.
    var isInteracting: Bool { isPanningViewport || isPinchingToZoom || isZoomDragging }

    // MARK: Tuning

    private let coupledSensitivity:     Double = 0.0001
    private let coupledAxisLockSlop:    Double = 6      // pt before an axis locks
    private let minimumFlingSpeed:      Double = 150    // pt/s, below this: no inertia
    private let maximumFlingSpeed:      Double = 4000   // pt/s, clamp wild flicks
    private let doubleTapWindow:        Double = 0.30   // s: tap-up → next touch-down
    private let tapMaxMovement:         Double = 10     // pt: beyond this it's a drag
    private let tapMaxDuration:         Double = 0.30   // s: longer (still) isn't a tap
    private let zoomDragSensitivity:    Double = 0.005  // scale e-fold per pt dragged
    private let maximumScale:           Double = 300    // hard zoom-in ceiling, all gestures

    // MARK: - Primary one-finger gesture
    // One DragGesture(minimumDistance: 0) classifies the touch: a quick tap,
    // a double-tap (discrete step zoom), a double-tap held + dragged
    // (continuous zoom — drag down = in, up = out, exactly like pinch), or
    // a pan (viewport / coupled / origin + inertia). Doing this in a single
    // gesture avoids SwiftUI arbitration fights between tap and drag.

    func primaryGesture(state: EAppState) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("celestialCanvas"))
            .onChanged { value in
                guard !self.isPinchingToZoom else { return }   // pinch owns 2-finger

                if self.phase == .undecided {
                    self.classifyTouch(state: state, value: value)
                }

                switch self.phase {
                case .zoomDragging:
                    self.updateZoomDrag(state: state, value: value)

                case .panning:
                    self.commitAnyRunningPresetTransition(state: state)
                    self.stopInertia(state: state)
                    self.beginPanIfNeeded(state: state)
                    switch state.projectionMode {
                    case .drag:    self.panViewport(state: state, by: value.translation)
                    case .coupled: self.moveObserverWithAxisLock(state: state, by: value)
                    case .origin:  self.moveObserverFreely(state: state, by: value.translation)
                    }

                case .undecided:
                    break   // tiny movement so far — still could be a tap
                }
            }
            .onEnded { value in
                defer { self.phase = .undecided; self.touchStamped = false }
                guard !self.isPinchingToZoom else { return }

                let moved    = hypot(value.translation.width, value.translation.height)
                let duration = Date.now.timeIntervalSince(self.touchStartTime)
                let wasTap   = moved <= self.tapMaxMovement && duration <= self.tapMaxDuration

                switch self.phase {
                case .zoomDragging:
                    // Second tap with no drag → discrete step zoom; with a
                    // drag → continuous zoom already applied live. Either
                    // way the zoom centres on the FIRST tap of the series.
                    if wasTap { self.zoomToward(point: self.lastTapPoint, state: state) }
                    self.lastTapEndedAt = .distantPast      // double-tap consumed
                    self.isZoomDragging = false

                case .panning:
                    if state.projectionMode == .drag {
                        self.startInertiaIfFlung(state: state, velocity: value.velocity)
                    }
                    self.endPan(state: state)
                    self.lastTapEndedAt = .distantPast      // a pan cancels a pending tap

                case .undecided:
                    if wasTap {                             // a (first) clean tap
                        self.lastTapEndedAt = Date.now
                        self.lastTapPoint   = self.touchStartPoint
                    }
                }
            }
    }

    // First onChanged of a touch: stamp it, then decide whether it's the
    // held second tap of a double-tap (→ zoom drag) or an ordinary drag.
    private func classifyTouch(state: EAppState, value: DragGesture.Value) {
        if !touchStamped {                       // stamp the down once, not every frame
            touchStamped    = true
            touchStartTime  = Date.now
            touchStartPoint = value.startLocation
        }

        let isSecondTap = Date.now.timeIntervalSince(lastTapEndedAt) <= doubleTapWindow
        if isSecondTap {
            commitAnyRunningPresetTransition(state: state)
            stopInertia(state: state)
            beginZoomDrag(state: state, at: lastTapPoint)
            phase = .zoomDragging
        } else if hypot(value.translation.width, value.translation.height) > tapMaxMovement {
            phase = .panning
        }
        // else: still .undecided — wait for movement or lift (tap).
    }

    // MARK: - Double-tap-and-drag zoom (continuous, anchored at the tap)

    private func beginZoomDrag(state: EAppState, at anchor: CGPoint) {
        let size = state.canvasSize
        isZoomDragging      = true
        zoomDragStartScale  = state.scale
        zoomDragAnchorScreen = anchor
        // Same inversion as beginPinchIfNeeded: sky point under the tap.
        zoomDragAnchorSky = CGPoint(
            x: (anchor.x - size.width  / 2 - state.offset.y) / state.scale,
            y: (size.height / 2 + state.offset.x - anchor.y) / state.scale
        )
    }

    private func updateZoomDrag(state: EAppState, value: DragGesture.Value) {
        let size     = state.canvasSize
        guard size.width > 0, size.height > 0 else { return }
        // Drag down (translation.height > 0) → zoom in; up → zoom out.
        let factor   = exp(value.translation.height * zoomDragSensitivity)
        let newScale = clampScale(zoomDragStartScale * factor, state: state)

        // Same reprojection as zoomAroundFingers — keep the tap point fixed.
        state.scale    = newScale
        state.offset.y = zoomDragAnchorScreen.x - size.width  / 2 - zoomDragAnchorSky.x * newScale
        state.offset.x = zoomDragAnchorScreen.y - size.height / 2 + zoomDragAnchorSky.y * newScale
    }

    // MARK: - Pinch to zoom

    func magnificationGesture(state: EAppState) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                self.commitAnyRunningPresetTransition(state: state)
                self.stopInertia(state: state)
                self.beginPinchIfNeeded(state: state, at: value.startAnchor)
                self.zoomAroundFingers(state: state, value: value)
            }
            .onEnded { _ in self.endPinch() }
    }

    // MARK: - Discrete step zoom (quick double-tap, no drag)
    // Reuses the exact pinch anchor math so the tapped point stays pinned,
    // animated via the shared preset transition (crown / stars / Milky Way
    // all track it together).

    private let doubleTapZoomFactor: Double = 2.0

    private func zoomToward(point: CGPoint, state: EAppState) {
        let size = state.canvasSize
        guard size.width > 0, size.height > 0 else { return }

        let ceiling = maximumScale
        let floor   = state.defaultScale.isFinite
            ? Swift.min(state.defaultScale, ceiling) : 1

        // Same inversion as beginPinchIfNeeded: the sky point under the tap.
        let anchorX = (point.x - size.width  / 2 - state.offset.y) / state.scale
        let anchorY = (size.height / 2 + state.offset.x - point.y) / state.scale

        // Zoom in a step; once at the ceiling the next double-tap zooms out.
        let atCeiling = state.scale >= ceiling - 0.5
        let target    = atCeiling
            ? floor
            : Swift.min(state.scale * doubleTapZoomFactor, ceiling)

        // Same reprojection as zoomAroundFingers, so the tap stays fixed.
        var newOffset = CGPoint.zero
        newOffset.y = point.x - size.width  / 2 - anchorX * target
        newOffset.x = point.y - size.height / 2 + anchorY * target

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

    // Order- and NaN-safe scale clamp. Floor = defaultScale but never above
    // the hard ceiling; ceiling = maximumScale. Never constructs a Range, so
    // a degenerate/transient canvasSize can't trip "Range requires
    // lowerBound <= upperBound" (the pinch crash).
    private func clampScale(_ candidate: Double, state: EAppState) -> Double {
        let df    = state.defaultScale
        let floor = df.isFinite ? Swift.min(df, maximumScale) : 1
        guard candidate.isFinite else { return floor }
        return Swift.min(Swift.max(candidate, floor), maximumScale)
    }

    // MARK: - Pan: viewport (.drag mode)

    private func beginPanIfNeeded(state: EAppState) {
        guard !isPanningViewport else { return }
        isPanningViewport = true
        viewportOffsetAtPanStart = state.offset
    }

    private func panViewport(state: EAppState, by translation: CGSize) {
        state.offset.x = viewportOffsetAtPanStart.x + translation.height
        state.offset.y = viewportOffsetAtPanStart.y + translation.width
    }

    private func endPan(state: EAppState) {
        isPanningViewport = false
        state.coupledAxis = nil          // release the axis lock for the next gesture
    }

    // MARK: - Pan: move the observer (.coupled mode)

    // Lock onto the first dominant axis, then walk the observer along it.
    private func moveObserverWithAxisLock(state: EAppState, by value: DragGesture.Value) {
        if state.coupledAxis == nil {
            let dx = abs(value.translation.width)
            let dy = abs(value.translation.height)
            guard dx > coupledAxisLockSlop || dy > coupledAxisLockSlop else { return }
            state.coupledAxis = dx > dy ? .horizontal : .vertical
        }

        let rawLat = state.origin.latitude  - .radians(value.translation.height * coupledSensitivity)
        let newLat = Angle.radians(rawLat.radians.clamped(to: 0.1 ... .pi / 2 - 0.1))
        let rawLon = state.origin.longitude - .radians(value.translation.width  * coupledSensitivity)
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

    // MARK: - Pan: move the observer freely (.origin mode)

    private func moveObserverFreely(state: EAppState, by translation: CGSize) {
        let rawLat = state.origin.latitude  - .radians(translation.height * coupledSensitivity)
        let newLat = Angle.radians(rawLat.radians.clamped(to: -.pi / 2 ... .pi / 2))
        let rawLon = state.origin.longitude - .radians(translation.width  * coupledSensitivity)
        let newLon = Angle.radians(rawLon.radians.truncatingRemainder(dividingBy: 2 * .pi))
        state.origin.latitude  = newLat
        state.origin.longitude = newLon
    }

    // MARK: - Pinch

    private func beginPinchIfNeeded(state: EAppState, at startAnchor: UnitPoint) {
        guard !isPinchingToZoom else { return }
        isPinchingToZoom  = true
        scaleAtPinchStart = state.scale
        let size = state.canvasSize
        let mx = startAnchor.x * size.width
        let my = startAnchor.y * size.height
        // Invert the screen projection to find the sky point under the fingers,
        // so we can keep that exact point pinned while the scale changes.
        skyAnchorUnderFingers = CGPoint(
            x: (mx - size.width  / 2 - state.offset.y) / state.scale,
            y: (size.height / 2 + state.offset.x - my) / state.scale
        )
    }

    private func zoomAroundFingers(state: EAppState, value: MagnifyGesture.Value) {
        let size = state.canvasSize
        let newScale = clampScale(scaleAtPinchStart * Double(value.magnification),
                                  state: state)

        let mx = value.startAnchor.x * size.width
        let my = value.startAnchor.y * size.height
        state.scale    = newScale
        state.offset.y = mx - size.width  / 2 - skyAnchorUnderFingers.x * newScale
        state.offset.x = my - size.height / 2 + skyAnchorUnderFingers.y * newScale
    }

    private func endPinch() {
        isPinchingToZoom = false
    }

    // MARK: - Inertia

    private func startInertiaIfFlung(state: EAppState, velocity: CGSize) {
        let speed = hypot(velocity.width, velocity.height)
        guard speed > minimumFlingSpeed else { return }
        let damp = min(1, maximumFlingSpeed / speed)   // clamp wild flicks
        let now  = Date().timeIntervalSinceReferenceDate
        state._inertiaTransition = EInertiaTransition(
            velX: velocity.height * damp,   // offset.x follows translation.height
            velY: velocity.width  * damp,   // offset.y follows translation.width
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
// distance travelled is identical no matter the frame rate (the old version
// multiplied by a hardcoded 1/60 and ended on the first tick — that was the
// "unnaturally sped / instantly dead" inertia).
struct EInertiaTransition {
    let velX:      Double      // pt/s along offset.x  (follows translation.height)
    let velY:      Double      // pt/s along offset.y  (follows translation.width)
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
