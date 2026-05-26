import SwiftUI

// MARK: - CelestialGestureCoordinator + DoubleHold
// Double-tap-and-hold-drag zoom (continuous, anchored at the tap). A quick
// double-tap with no real drag falls through to a discrete step-zoom via
// `zoomToward(point:)`. The anchor math is shared with the pinch gesture —
// both pin a sky point under a screen point at the new scale.
extension CelestialGestureCoordinator {

    func doubleHoldBegan(at anchor: CGPoint, state: EAppState) {
        commitAnyRunningPresetTransition(state: state)
        stopInertia(state: state)
        setZoomDragging(true)
        zoomDragStartScale   = state.scale
        zoomDragLastScale    = state.scale
        zoomDragAnchorScreen = anchor
        zoomDragAnchorSky    = skyPoint(under: anchor, state: state)
    }

    func doubleHoldChanged(translation t: CGSize, state: EAppState) {
        // Drag up (t.height < 0) → zoom in; down → zoom out.
        let target = zoomDragStartScale * exp(-t.height * zoomDragSensitivity)

        // De-gain: cap |Δln(scale)| per event so a single spurious sample
        // can't be amplified through the anchor lever into a huge offset
        // jump. With clean recogniser input this never binds.
        let prev    = zoomDragLastScale > 0 ? zoomDragLastScale : zoomDragStartScale
        let safeTgt = target.isFinite ? target : prev
        let lo      = prev * exp(-zoomDragMaxStep)
        let hi      = prev * exp( zoomDragMaxStep)
        let limited = Swift.min(Swift.max(safeTgt, lo), hi)

        let newScale = rubberScale(limited, state: state)
        zoomDragLastScale = newScale
        let pinned   = screenPin(sky: zoomDragAnchorSky,
                                 under: zoomDragAnchorScreen,
                                 scale: newScale, state: state)
        state.scale  = newScale
        state.offset = rubberOffset(homedTowardDefault(pinned,
                                                       rawScale: limited,
                                                       state: state),
                                    state: state, scale: newScale)
    }

    func doubleHoldEnded(translation t: CGSize, duration: Double,
                         state: EAppState) {
        let moved  = hypot(t.width, t.height)
        let wasTap = moved <= tapMaxMovement && duration <= tapMaxDuration
        // Quick double-tap (no real drag) → discrete step zoom. A real
        // drag applied continuous zoom live → just spring any overshoot back.
        if wasTap { zoomToward(point: zoomDragAnchorScreen, state: state) }
        else      { settleWithinBounds(state: state) }
        setZoomDragging(false)
    }

    // MARK: - Discrete step zoom (quick double-tap)
    // Reuses the pinch anchor math so the tapped point stays pinned,
    // animated via the shared preset transition.
    private func zoomToward(point: CGPoint, state: EAppState) {
        let size = state.canvasSize
        guard size.width > 0, size.height > 0 else { return }

        let ceiling = maximumScale
        let floor   = state.defaultScale.isFinite
            ? Swift.min(state.defaultScale, ceiling) : 1
        let anchor  = skyPoint(under: point, state: state)

        // Zoom in a step; once at the ceiling the next double-tap zooms out.
        let atCeiling = state.scale >= ceiling - 0.5
        let target    = atCeiling
            ? floor
            : Swift.min(state.scale * doubleTapZoomFactor, ceiling)

        let newOffset = state.hardClampedOffset(
            screenPin(sky: anchor, under: point, scale: target, state: state),
            atScale: target)

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
}
