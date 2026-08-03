import SwiftUI
import UIKit

// MARK: - CelestialGestureView
// The UIKit gesture layer. A transparent UIView pinned over the canvas owns
// real UIGestureRecognizers. They live independently of the SwiftUI body
// rebuild, so finger deltas can no longer be corrupted by the state writes
// they trigger (the old SwiftUI feedback loop). All math is delegated to
// CelestialGestureCoordinator; this file is touch plumbing and arbitration.
//
// Recognisers:
//   • pan   — one finger only. Pans the viewport + fling inertia.
//   • pinch — two fingers. Maps-style scale + pan-with-centroid.
//   • hold  — one tap then press-and-hold. A quick second tap = discrete
//             step zoom; held + dragged = continuous zoom.
//
// Arbitration: pan + pinch run simultaneously (Maps / Photos pattern).
// Hold stays exclusive.
struct CelestialGestureView: UIViewRepresentable {

    let gestures: CelestialGestureCoordinator
    let state:    EAppState

    func makeCoordinator() -> Coordinator {
        Coordinator(gestures: gestures, state: state)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor          = .clear
        view.isUserInteractionEnabled = true
        let c = context.coordinator

        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handlePan))
        pan.maximumNumberOfTouches = 1
        pan.delegate               = c

        let pinch = UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.handlePinch))
        pinch.delegate = c

        let rotation = UIRotationGestureRecognizer(target: c, action: #selector(Coordinator.handleRotation))
        rotation.delegate = c

        let hold = UILongPressGestureRecognizer(target: c, action: #selector(Coordinator.handleHold))
        hold.numberOfTapsRequired = 1                          // a tap, then the press
        hold.minimumPressDuration = 0                          // begin on the 2nd touch-down
        hold.allowableMovement    = .greatestFiniteMagnitude   // dragging must not fail it
        hold.delegate             = c

        pan.require(toFail: hold)                              // a held tap ≠ a pan

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(rotation)
        view.addGestureRecognizer(hold)
        c.trackedView = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.gestures = gestures
        context.coordinator.state    = state
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        var gestures: CelestialGestureCoordinator
        var state:    EAppState
        weak var trackedView: UIView?

        private var holdStartLocation: CGPoint = .zero
        private var holdStartTime:     Date    = .distantPast

        init(gestures: CelestialGestureCoordinator, state: EAppState) {
            self.gestures = gestures
            self.state    = state
        }

        // MARK: One-finger pan

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let v = trackedView else { return }
            let t = g.translation(in: v)
            switch g.state {
            case .began:
                gestures.panBegan(state: state)
            case .changed:
                gestures.panChanged(translation: CGSize(width: t.x, height: t.y),
                                    state: state)
            case .ended, .cancelled, .failed:
                let vel = g.velocity(in: v)
                gestures.panEnded(translation: CGSize(width: t.x, height: t.y),
                                  velocity:    CGSize(width: vel.x, height: vel.y),
                                  state: state)
            default:
                break
            }
        }

        // MARK: Two-finger pinch (scale + pan via live-centroid reprojection)

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard let v = trackedView else { return }
            let centroid = g.location(in: v)            // midpoint of the 2 touches
            switch g.state {
            case .began:
                gestures.pinchBegan(centroid: centroid, state: state)
            case .changed:
                // When one finger lifts before the other, the recogniser
                // emits a .changed whose centroid has snapped from the
                // two-finger midpoint to the lone remaining finger. Feeding
                // that to pinchChanged re-pins the sky anchor under the
                // jumped centroid → the view lurches. Ignore any sub-two-
                // touch frame; the gesture ends right after anyway.
                guard g.numberOfTouches >= 2 else { return }
                gestures.pinchChanged(scale: Double(g.scale),
                                      centroid: centroid, state: state)
            case .ended, .cancelled, .failed:
                gestures.pinchEnded(state: state)
            default:
                break
            }
        }

        // MARK: Two-finger rotation (spins the canvas; North detent)

        @objc func handleRotation(_ g: UIRotationGestureRecognizer) {
            switch g.state {
            case .began:
                gestures.rotationBegan(state: state)
            case .changed:
                // Same sub-two-touch guard as pinch: when one finger lifts
                // the recogniser can emit a stray .changed before ending.
                guard g.numberOfTouches >= 2 else { return }
                gestures.rotationChanged(rotation: Double(g.rotation), state: state)
            case .ended, .cancelled, .failed:
                gestures.rotationEnded(state: state)
            default:
                break
            }
        }

        // MARK: Double-tap-and-hold (step zoom / continuous zoom)

        @objc func handleHold(_ g: UILongPressGestureRecognizer) {
            guard let v = trackedView else { return }
            let p = g.location(in: v)
            switch g.state {
            case .began:
                holdStartLocation = p
                holdStartTime     = .now
                gestures.doubleHoldBegan(at: p, state: state)
            case .changed:
                gestures.doubleHoldChanged(
                    translation: CGSize(width:  p.x - holdStartLocation.x,
                                        height: p.y - holdStartLocation.y),
                    state: state)
            case .ended, .cancelled, .failed:
                gestures.doubleHoldEnded(
                    translation: CGSize(width:  p.x - holdStartLocation.x,
                                        height: p.y - holdStartLocation.y),
                    duration: Date.now.timeIntervalSince(holdStartTime),
                    state: state)
            default:
                break
            }
        }

        // MARK: Arbitration

        // Pan + pinch run simultaneously (Maps / Photos pattern). Without
        // this, whichever recogniser claims the touches first locks out
        // the other. Hold stays exclusive — the 1-finger pan already
        // requires it to fail.
        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            if g is UILongPressGestureRecognizer
            || other is UILongPressGestureRecognizer {
                return false
            }
            return true
        }
    }
}
