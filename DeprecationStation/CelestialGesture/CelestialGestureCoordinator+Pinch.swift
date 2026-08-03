import SwiftUI

// MARK: - CelestialGestureCoordinator + Pinch
// Two-finger pinch, Maps-style: scale AND translate in one pass. The sky
// point under the two-finger centroid at gesture start is pinned to the
// *live* centroid every callback. Because the centroid moves with the
// fingers, that single reprojection gives scale-about-centroid AND
// pan-follows-centroid at once — no second recogniser, no double-count.
extension CelestialGestureCoordinator {

    func pinchBegan(centroid c: CGPoint, state: EAppState) {
        commitAnyRunningPresetTransition(state: state)
        stopInertia(state: state)
        guard !isPinchingToZoom else { return }
        setPinching(true)
        scaleAtPinchStart     = state.scale
        skyAnchorUnderFingers = skyPoint(under: c, state: state)
    }

    func pinchChanged(scale magnification: Double, centroid c: CGPoint,
                      state: EAppState) {
        let rawScale = scaleAtPinchStart * magnification
        let newScale = rubberScale(rawScale, state: state)
        let pinned   = screenPin(sky: skyAnchorUnderFingers,
                                 under: c,
                                 scale: newScale, state: state)
        state.scale  = newScale
        state.offset = rubberOffset(homedTowardDefault(pinned,
                                                       rawScale: rawScale,
                                                       state: state),
                                    state: state, scale: newScale)
    }

    func pinchEnded(state: EAppState) {
        setPinching(false)
        settleWithinBounds(state: state)        // spring back from overshoot
    }
}
