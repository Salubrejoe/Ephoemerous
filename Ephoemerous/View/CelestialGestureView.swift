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
//   • pinch — two fingers. Maps-style: scale + translate via the live
//     centroid, in one reprojection (no separate two-finger pan).
//   • hold — one tap then press-and-hold. A quick second tap = discrete
//     step zoom; held + dragged = continuous zoom.
//
// Arbitration: pan and pinch may run simultaneously (Maps feel); a held
// second tap suppresses the pan (pan requires the hold to fail).
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

        // MARK: Two-finger pinch (scale + translate via live centroid)

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard let v = trackedView else { return }
            let centroid = g.location(in: v)            // midpoint of the 2 touches
            switch g.state {
            case .began:
                gestures.pinchBegan(centroid: centroid, state: state)
            case .changed:
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

        // Pan + pinch together = Maps feel. The hold is exclusive (pan
        // already requires it to fail; keep pinch off it too).
        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            let pinchPan =
                (g is UIPinchGestureRecognizer && other is UIPanGestureRecognizer) ||
                (g is UIPanGestureRecognizer  && other is UIPinchGestureRecognizer)
            return pinchPan
        }
    }
}
