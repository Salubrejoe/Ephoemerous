import SwiftUI
import simd
import LoreKit

// MARK: - AppState + Look
// LOOK mode: the phone held up as a WINDOW onto the sky — the view centres
// on where the phone's back points and moves with the hand, one degree of
// turn for one degree of sky (see `Projection.Viewpoint.look`).
//
// It takes intent both ways:
//   • IN — long-press the projection button, or hold the phone overhead,
//     belly down (screen facing you from above), for `lookArmDuration`.
//     Nobody reads a phone like that, so it can't fire by accident; the
//     arming ring shows the hold filling, and lowering early cancels.
//   • OUT — a tap on the projection button, and only that. Once open, the
//     window holds through any pose, so you can look along the horizon
//     and under it without the mode dropping out. It lands back on the
//     chart you opened it from (NorthIN or NorthOUT), at that chart's home
//     framing — MainView reseeds it while the window still covers it.
// Both directions play on the canvas clock, never scrubbed by the tilt.
extension AppState {

    /// Hold time (s) that arms the window. ▼ TWEAK ▼
    var lookArmDuration:   Double { 0.6 }
    /// Chart ↔ window transition (s). ▼ TWEAK ▼
    var lookMorphDuration: Double { 0.8 }

    // MARK: Transition

    /// Displayed openness of the window, 0 = chart, 1 = window — eased by
    /// the canvas clock, so a pure getter.
    var lookMorph: Double {
        if let t = _lookTransition, !t.isFinished(at: animationTime) {
            return t.value(at: animationTime)
        }
        return isLooking ? 1 : 0
    }

    /// How open the window is right now — `lookMorph`, but only where you
    /// stand and with a gyro to steer it. Reads no motion.
    var lookBlend: Double {
        guard isAtDeviceLocation, MotionService.shared.isAvailable else { return 0 }
        return lookMorph
    }

    /// The window's pose in the projection's earth-fixed frame — `nil` on
    /// the chart. Reads the 60 Hz pose ONLY while the window is open, so
    /// the chart never redraws for a moving hand.
    var look: Projection.Viewpoint.Look? {
        let blend = lookBlend
        guard blend > 0, let pose = MotionService.shared.pose else { return nil }
        // Local (north, west, up) → earth-fixed, on the same basis
        // `skyPoint(azimuth:altitude:)` uses.
        let (north, west) = originVector.baseVectors()
        func earth(_ v: SIMD3<Double>) -> SIMD3<Double> {
            v.x * north + v.y * west + v.z * originVector
        }
        return .init(direction: earth(pose.back), up: earth(pose.up), blend: blend)
    }

    // MARK: In / out

    /// The window needs you standing where you are and a gyro to steer it.
    var canLook: Bool { isAtDeviceLocation && MotionService.shared.isAvailable }

    /// Open the window. Seeds from the displayed value, so a reversal
    /// mid-flight glides from where it is.
    func enterLook() {
        guard !isLooking, canLook else { return }
        cancelLookArming()
        animateLook(to: 1)
        isLooking = true
    }

    /// Back to the chart — the projection button's job, and only its.
    /// The projection stays whatever it was; the window eases out onto that
    /// chart's home framing (see MainView's `isLooking` onChange).
    func exitLook() {
        guard isLooking else { return }
        animateLook(to: 0)
        isLooking = false
    }

    /// Start the transition from what's on screen NOW. Call BEFORE flipping
    /// `isLooking`: at rest `lookMorph` reads it, so flipping first made the
    /// start equal the target — a zero-length transition, i.e. a snap.
    private func animateLook(to target: Double) {
        let current = lookMorph
        _lookTransition = MorphTransition(from:      current,
                                          to:        target,
                                          startTime: Date.now.timeIntervalSinceReferenceDate,
                                          duration:  lookMorphDuration * abs(target - current))
    }

    // MARK: Arming

    /// The overhead pose came or went (`MotionService.raisedToSky`, which
    /// carries its own hysteresis). Coming: start the hold. Going: cancel.
    func raisedToSkyChanged(_ raised: Bool) {
        guard raised else { cancelLookArming(); return }
        guard !isLooking, isAtDeviceLocation, MotionService.shared.isAvailable,
              !isShowingDatePicker, !isShowingLocationPicker
        else { return }

        isArmingLook = true
        _lookArmTask?.cancel()
        _lookArmTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.lookArmDuration))
            guard !Task.isCancelled, self.isArmingLook else { return }
            self.enterLook()
        }
    }

    private func cancelLookArming() {
        _lookArmTask?.cancel()
        _lookArmTask = nil
        if isArmingLook { isArmingLook = false }
    }
}
