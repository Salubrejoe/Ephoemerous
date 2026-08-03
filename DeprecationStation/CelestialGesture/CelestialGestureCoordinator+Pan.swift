import SwiftUI

// MARK: - CelestialGestureCoordinator + Pan
// One-finger drag. Rubber-bands past the disc edge, releases into fling
// inertia when flicked. Pinch can run alongside (see arbitration in
// CelestialGestureView) — that's why begin/end snap to/from a clean
// phase rather than touching pinch's anchors.
extension CelestialGestureCoordinator {

    func panBegan(state: EAppState) {
        commitAnyRunningPresetTransition(state: state)
        stopInertia(state: state)
    }

    func panChanged(translation t: CGSize, state: EAppState) {
        beginPanIfNeeded(state: state)
        panViewport(state: state, by: t)
    }

    func panEnded(translation t: CGSize, velocity v: CGSize, state: EAppState) {
        let clamped     = state.hardClampedOffset(state.offset, atScale: state.scale)
        let outOfBounds = hypot(clamped.x - state.offset.x,
                                clamped.y - state.offset.y) > 0.5
        if outOfBounds { settleWithinBounds(state: state) }            // spring back
        else           { startInertiaIfFlung(state: state, velocity: v) }
        endPan(state: state)
    }

    private func beginPanIfNeeded(state: EAppState) {
        guard !isPanningViewport else { return }
        setPanning(true)
        viewportOffsetAtPanStart = state.offset
    }

    private func panViewport(state: EAppState, by t: CGSize) {
        // t.width = horizontal (offset.y), t.height = vertical (offset.x).
        let raw = CGPoint(x: viewportOffsetAtPanStart.x + t.height,
                          y: viewportOffsetAtPanStart.y + t.width)
        state.offset = rubberOffset(raw, state: state, scale: state.scale)
    }

    private func endPan(state: EAppState) {
        setPanning(false)
    }
}
