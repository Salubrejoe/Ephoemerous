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
//   • pan  — one finger only. Viewport / observer move + fling.
//   • pinch — two fingers. Drives BOTH the Maps-style scale + centroid
//     reprojection AND the two-finger origin nudge (centroid translation
//     → origin shift, springs back on release). A separate
//     `UIPanGestureRecognizer(numberOfTouches: 2)` would, in practice,
//     never transition out of Possible because pinch claims the same two
//     touches first; piggy-backing on pinch is the standard fix.
//   • hold — one tap then press-and-hold. A quick second tap = discrete
//     step zoom; held + dragged = continuous zoom.
//
// Arbitration: pan + pinch may run simultaneously (Maps feel); a held
// second tap suppresses the one-finger pan.
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

        let hold = UILongPressGestureRecognizer(target: c, action: #selector(Coordinator.handleHold))
        hold.numberOfTapsRequired = 1                          // a tap, then the press
        hold.minimumPressDuration = 0                          // begin on the 2nd touch-down
        hold.allowableMovement    = .greatestFiniteMagnitude   // dragging must not fail it
        hold.delegate             = c

        pan.require(toFail: hold)                              // a held tap ≠ a pan

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
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

        // MARK: Two-finger pinch (scale + centroid reprojection + origin nudge)

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

        // Multi-touch recognisers all run simultaneously (Maps / Photos
        // pattern). Without this, pinch claims the two touches first and
        // the two-finger pan never transitions out of Possible — the
        // delegate has to whitelist *both* directions (pinch-asks-about-
        // pan AND pan-asks-about-pinch) for either to start. The 1-finger
        // pan and 2-finger pan don't overlap by touch count anyway, so
        // letting them recognise together is harmless. Hold stays
        // exclusive (1-finger pan already requires it to fail).
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
