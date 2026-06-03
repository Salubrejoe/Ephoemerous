import SwiftUI

// MARK: - CelestialGestureCoordinator + Rotation
// Two-finger twist → spins the whole celestial canvas (writes
// `state.canvasRotation`, the same field the dev slider drives). Runs
// simultaneously with pinch + pan (Maps pattern), so a single two-finger
// move can zoom, pan AND rotate at once — they write independent state
// fields and never fight.
//
// North detent (the "realign right" behaviour): there's a dead-zone of
// ±`rotationSnapThreshold` around aligned (0°). While the live rotation is
// inside it, the sky is held EXACTLY at North and a single haptic tick
// fires on entry — so rotating back toward upright clicks into place
// instead of leaving the sky a degree or two off. Leaving the zone
// resumes free rotation. On release, a let-go close to North also springs
// the last sliver back to aligned.
extension CelestialGestureCoordinator {

    func rotationBegan(state: EAppState) {
        commitAnyRunningPresetTransition(state: state)
        stopInertia(state: state)
        guard !isRotatingCanvas else { return }
        setRotating(true)
        // Snap any in-flight compass spin-back to its committed end so the
        // twist starts from where the sky actually is, not mid-animation.
        state._rotationTransition = nil
        canvasRotationAtStart = state.canvasRotation
        // If we begin already aligned, we're starting inside the detent —
        // don't re-tick the haptic until the user leaves and returns.
        northDetentEngaged = abs(state.canvasRotation.degrees) <= rotationSnapThreshold.degrees
        rotationHaptic.prepare()
    }

    /// `rotation` is the recogniser's cumulative twist in radians (CW+),
    /// measured from gesture start. Negated so the sky follows the fingers
    /// — UIKit's CW+ is the opposite sense of `canvasRotation` as applied
    /// in `toScreen` (which flips Y), so without this the sky spins against
    /// the twist.
    func rotationChanged(rotation radians: Double, state: EAppState) {
        let raw = normalizedDegrees(
            canvasRotationAtStart.degrees - radians * 180 / .pi
        )

        if abs(raw) <= rotationSnapThreshold.degrees {
            // Inside the North detent → stick to aligned, tick once on entry.
            if !northDetentEngaged {
                northDetentEngaged = true
                rotationHaptic.impactOccurred()
            }
            state.canvasRotation = .zero
        } else {
            northDetentEngaged = false
            state.canvasRotation = .degrees(raw)
        }
    }

    func rotationEnded(state: EAppState) {
        setRotating(false)
        northDetentEngaged = false
        // Safety realign: a release within the detent springs the last bit
        // back to aligned (usually already 0 from the detent above, but
        // covers a finger lift mid-snap).
        if abs(state.canvasRotation.degrees) <= rotationSnapThreshold.degrees {
            withAnimation(.snappy) { state.canvasRotation = .zero }
        }
    }

    /// Fold any angle into (−180°, 180°] so the detent test and the stored
    /// rotation never wind past a full turn.
    private func normalizedDegrees(_ d: Double) -> Double {
        var x = d.truncatingRemainder(dividingBy: 360)
        if x >  180 { x -= 360 }
        if x < -180 { x += 360 }
        return x
    }
}
