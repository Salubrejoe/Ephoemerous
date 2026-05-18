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

    private var viewportOffsetAtPanStart: CGPoint = .zero
    private var scaleAtPinchStart:        Double  = 0
    private var skyAnchorUnderFingers:    CGPoint = .zero

    /// True while the user is actively manipulating the canvas. The
    /// timeline reads this to stay at 60 fps for the duration.
    var isInteracting: Bool { isPanningViewport || isPinchingToZoom }

    // MARK: Tuning

    private let coupledSensitivity:     Double = 0.0001
    private let coupledAxisLockSlop:    Double = 6      // pt before an axis locks
    private let minimumFlingSpeed:      Double = 150    // pt/s, below this: no inertia
    private let maximumFlingSpeed:      Double = 4000   // pt/s, clamp wild flicks

    // MARK: - Single-finger drag

    func viewportDragGesture(state: EAppState) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                // Pinch owns the viewport while two fingers are down.
                guard !self.isPinchingToZoom else { return }
                self.commitAnyRunningPresetTransition(state: state)
                self.stopInertia(state: state)
                self.beginPanIfNeeded(state: state)

                switch state.projectionMode {
                case .drag:    self.panViewport(state: state, by: value.translation)
                case .coupled: self.moveObserverWithAxisLock(state: state, by: value)
                case .origin:  self.moveObserverFreely(state: state, by: value.translation)
                }
            }
            .onEnded { value in
                // Inertia only makes sense when panning the viewport itself —
                // a flung observer in coupled / origin mode would be disorienting.
                if state.projectionMode == .drag && !self.isPinchingToZoom {
                    self.startInertiaIfFlung(state: state, velocity: value.velocity)
                }
                self.endPan(state: state)
            }
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
        let minScale: Double = state.defaultScale
        let maxScale: Double = size.height / 4
        let newScale = (scaleAtPinchStart * Double(value.magnification))
            .clamped(to: minScale ... maxScale)

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
