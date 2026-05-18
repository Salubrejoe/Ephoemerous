import SwiftUI

// MARK: - EAppState + CanvasClock
// Per-frame bookkeeping the celestial canvas used to do inline: advance the
// animation clock and step any in-flight inertia / origin transitions.
// State writes are dispatched async because the Canvas closure runs inside
// a view update, where synchronous mutation of observed state is illegal.
extension EAppState {

    /// Called once per Canvas frame with the timeline time and canvas size.
    func advanceCanvasClock(to time: Double, canvasSize size: CGSize) {
        animationTime = time
        advanceInertiaTransition(at: time)
        advanceOriginTransition(at: time)
        if canvasSize != size {
            DispatchQueue.main.async { self.canvasSize = size }
        }
    }

    private func advanceInertiaTransition(at time: Double) {
        guard var transition = _inertiaTransition else { return }
        let (dx, dy, finished) = transition.advance(to: time)
        let advanced = transition
        DispatchQueue.main.async {
            self.offset.x += dx
            self.offset.y += dy
            self._inertiaTransition = finished ? nil : advanced
        }
    }

    private func advanceOriginTransition(at time: Double) {
        guard let transition = _originTransition else { return }
        let (lat, lon) = transition.interpolated(at: time)
        let finished   = transition.isFinished(at: time)
        DispatchQueue.main.async {
            self.setOrigin(lat: .radians(lat), lon: .radians(lon))
            if finished { self._originTransition = nil }
        }
    }
}
