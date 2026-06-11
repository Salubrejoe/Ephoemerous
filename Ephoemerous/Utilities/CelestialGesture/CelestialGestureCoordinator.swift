import SwiftUI
import UIKit
import LoreKit

// MARK: - CelestialGestureCoordinator
// A pure transform engine. It owns the tuning constants and the transient
// anchors a gesture needs across callbacks (pan origin, pinch sky anchor)
// and translates already-resolved UIKit recogniser deltas into writes on
// EAppState. It contains NO SwiftUI gesture: touch classification, tap
// timing and arbitration all live in CelestialGestureView's UIKit
// recognisers. Keeping the math here and the recognisers there is what
// kills the old per-frame feedback loop — these methods run on the main
// thread OUTSIDE the SwiftUI body rebuild, so a state write can no longer
// pollute the next finger sample.
//
// Gesture set (single source of truth — keep this list in sync with
// CelestialGestureView's recogniser list):
//   • Drag (1 finger)   — pans the viewport. Releases into fling inertia
//                          if velocity exceeds `minimumFlingSpeed`.
//   • Pinch (2 fingers) — Maps-style: the sky point under the live
//                          two-finger centroid stays under the centroid
//                          throughout. One reprojection per callback
//                          gives scale-around-fingers AND pan-with-
//                          fingers in a single pass.
//   • Double-tap-hold-drag — anchor at the tap, drag up to zoom in /
//                          down to zoom out. A quick double-tap with no
//                          real drag = discrete step zoom.
//
// File layout (this folder):
//   CelestialGestureCoordinator.swift            — class shell + state + tuning
//   CelestialGestureCoordinator+Pan.swift        — one-finger pan
//   CelestialGestureCoordinator+Pinch.swift      — two-finger pinch
//   CelestialGestureCoordinator+DoubleHold.swift — double-tap-hold-drag zoom
//   CelestialGestureCoordinator+Math.swift       — screen⇄sky projection helpers
//   CelestialGestureCoordinator+Rubber.swift     — rubber-band / settle math
//   CelestialGestureCoordinator+Inertia.swift    — fling-inertia plumbing
//   CelestialGestureView.swift                   — UIKit recogniser surface
@Observable
final class CelestialGestureCoordinator {

    // MARK: Transient interaction state

    private(set) var isPanningViewport = false
    private(set) var isPinchingToZoom  = false
    private(set) var isZoomDragging    = false
    private(set) var isRotatingCanvas  = false

    var viewportOffsetAtPanStart: CGPoint = .zero
    var scaleAtPinchStart:        Double  = 0
    var skyAnchorUnderFingers:    CGPoint = .zero

    /// Canvas rotation captured at the start of a two-finger rotate, so
    /// the gesture's cumulative `rotation` adds onto where the sky already
    /// sat rather than snapping to an absolute. See +Rotation.
    var canvasRotationAtStart: Angle = .zero
    /// True while the live rotation is held inside the North detent (the
    /// snap-to-aligned dead-zone). Tracked so the detent haptic fires once
    /// on entry, not every frame the fingers wiggle inside it.
    @ObservationIgnored var northDetentEngaged = false
    /// Light tick when the rotation snaps into the North detent. Rigid =
    /// the same crisp feel as the DayCapsule now-detent.
    @ObservationIgnored
    let rotationHaptic = UIImpactFeedbackGenerator(style: .rigid)

    var zoomDragStartScale:   Double  = 0
    var zoomDragLastScale:    Double  = 0
    var zoomDragAnchorSky:    CGPoint = .zero   // sky point pinned under the tap
    var zoomDragAnchorScreen: CGPoint = .zero   // fixed screen point (the double-tap)

    /// True while the user is actively manipulating the canvas. The
    /// timeline reads this to stay at 60 fps for the duration.
    var isInteracting: Bool {
        isPanningViewport || isPinchingToZoom || isZoomDragging || isRotatingCanvas
    }

    // MARK: Tuning

    let minimumFlingSpeed:      Double = 150    // pt/s, below this: no inertia
    let maximumFlingSpeed:      Double = 4000   // pt/s, clamp wild flicks
    let flingDecayRate:         Double = 16     // 1/s; lower = longer glide (more inertia). LoreKit default 80; travel ≈ v/k
    let tapMaxMovement:         Double = 10     // pt: beyond this it's a drag
    let tapMaxDuration:         Double = 0.30   // s: longer (still) isn't a tap
    let zoomDragSensitivity:    Double = 0.005  // scale e-fold per pt dragged
    let zoomDragMaxStep:        Double = 0.40   // max |Δln(scale)| per event (de-gain)
    let minimumScale:           Double = 50     // hard zoom-out floor for all gestures — independent of launch scale
    let maximumScale:           Double = 1200    // hard zoom-in ceiling — must clear the named-star textIn (360) with headroom
    let rubberC:                Double = 0.55   // iOS scroll rubber-band constant
    let scaleOvershootFraction: Double = 0.18   // damped zoom-past-ceiling room
    let doubleTapZoomFactor:    Double = 2.0
    let rotationSnapThreshold:  Angle  = .degrees(7)  // within this of North → snap aligned

    // MARK: - Phase setters (kept here so the `private(set)` flags are
    // writeable from extensions in this folder)

    func setPanning(_ v: Bool)  { isPanningViewport = v }
    func setPinching(_ v: Bool) { isPinchingToZoom  = v }
    func setZoomDragging(_ v: Bool) { isZoomDragging = v }
    func setRotating(_ v: Bool) { isRotatingCanvas = v }

    // MARK: - Shared helpers

    /// Snap any in-flight preset slerp to its current rendered position so
    /// a fresh gesture can begin from "where the user sees" without fighting
    /// an animation behind it. Called at the start of every gesture.
    func commitAnyRunningPresetTransition(state: EAppState) {
        guard state._activeTransition != nil else { return }
        state.scale  = state.renderedScale
        state.offset = state.renderedOffset
        state._activeTransition = nil
    }
}
