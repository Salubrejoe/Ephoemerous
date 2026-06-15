import SwiftUI
import UIKit

// MARK: - SkyLabGestureView
// UIKit recogniser layer for the SkyLab — duplicated from the production
// CelestialGestureView (the robust, proven touch-arbitration part), but
// pointed at SkyLabGestureCoordinator.
//
// Recognisers:
//   • pan   — 1 finger → live pan
//   • pinch — 2 fingers → live scale (+ centroid pan)
//   • rotation — 2 fingers → live rotation (runs with pinch)
//   • hold  — 1 tap then press-and-hold (taps=1, press=0) → double-tap-
//             hold-drag zoom; a quick release with no drag = step zoom.
// pan.require(toFail: hold) so a tap-then-drag is zoom, not pan.
struct SkyLabGestureView: UIViewRepresentable {

    let coordinator: SkyLabGestureCoordinator

    func makeCoordinator() -> Coordinator { Coordinator(coordinator) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let c = context.coordinator

        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handlePan))
        pan.maximumNumberOfTouches = 1
        pan.delegate = c

        let pinch = UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.handlePinch))
        pinch.delegate = c

        let rotation = UIRotationGestureRecognizer(target: c, action: #selector(Coordinator.handleRotation))
        rotation.delegate = c

        let hold = UILongPressGestureRecognizer(target: c, action: #selector(Coordinator.handleHold))
        hold.numberOfTapsRequired = 1                          // a tap, THEN the press
        hold.minimumPressDuration = 0
        hold.allowableMovement    = .greatestFiniteMagnitude   // dragging mustn't fail it
        hold.delegate             = c
        pan.require(toFail: hold)                              // tap-then-drag ≠ pan

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(rotation)
        view.addGestureRecognizer(hold)
        c.trackedView = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.sky = coordinator
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var sky: SkyLabGestureCoordinator
        weak var trackedView: UIView?
        private var holdStart: CGPoint = .zero
        private var holdStartTime: Date = .distantPast

        init(_ sky: SkyLabGestureCoordinator) { self.sky = sky }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let v = trackedView else { return }
            let t = g.translation(in: v)
            switch g.state {
            case .began:   sky.panBegan()
            case .changed: sky.panChanged(CGSize(width: t.x, height: t.y))
            case .ended, .cancelled, .failed:
                let vel = g.velocity(in: v)
                sky.panEnded(velocity: CGSize(width: vel.x, height: vel.y))
            default: break
            }
        }

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard let v = trackedView else { return }
            let c = g.location(in: v)
            switch g.state {
            case .began: sky.pinchBegan(centroid: c)
            case .changed:
                guard g.numberOfTouches >= 2 else { return }   // ignore lone-finger frame
                sky.pinchChanged(scale: g.scale, centroid: c)
            case .ended, .cancelled, .failed: sky.pinchEnded()
            default: break
            }
        }

        @objc func handleRotation(_ g: UIRotationGestureRecognizer) {
            switch g.state {
            case .began: sky.rotationBegan()
            case .changed:
                guard g.numberOfTouches >= 2 else { return }
                sky.rotationChanged(Double(g.rotation))
            case .ended, .cancelled, .failed: sky.rotationEnded()
            default: break
            }
        }

        @objc func handleHold(_ g: UILongPressGestureRecognizer) {
            guard let v = trackedView else { return }
            let p = g.location(in: v)
            switch g.state {
            case .began:
                holdStart = p
                holdStartTime = Date()
                sky.holdBegan(at: p)
            case .changed:
                sky.holdChanged(CGSize(width: p.x - holdStart.x, height: p.y - holdStart.y))
            case .ended, .cancelled, .failed:
                let moved  = hypot(p.x - holdStart.x, p.y - holdStart.y)
                let wasTap = moved <= 10 && Date().timeIntervalSince(holdStartTime) <= 0.3
                sky.holdEnded(wasTap: wasTap)
            default: break
            }
        }

        // Pan + pinch + rotation run simultaneously (Maps pattern). Hold
        // stays exclusive — the pan already requires it to fail.
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            if g is UILongPressGestureRecognizer || other is UILongPressGestureRecognizer {
                return false
            }
            return true
        }
    }
}
