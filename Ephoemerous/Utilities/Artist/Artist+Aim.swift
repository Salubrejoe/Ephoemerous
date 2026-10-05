import SwiftUI

// MARK: - Where you face
// The dot-and-cone was the Maps metaphor — you HERE on the ground, facing
// THAT way. Under the sky you are underneath all of it, and a chart you
// read doesn't point: what it owes you is which way you're facing. So the
// stretch of horizon rim you face lights softly, like a dive-watch bezel
// (`FacingBezel`). Pointing belongs to a window you look THROUGH, not a
// map you read.
extension Artist {

    // MARK: Facing bezel ▼ TWEAK ▼

    /// Half-span of the lit stretch — the compass's own accuracy, clamped
    /// so a confident compass is still a visible arc and a lost one still
    /// says roughly where.
    var bezelMinHalfAngleDeg: Double  { 10 }
    var bezelMaxHalfAngleDeg: Double  { 40 }
    var bezelLineWidth:       CGFloat { 3 }
    /// The full span is the hush; the middle `bezelCoreFraction` of it is
    /// drawn again, brighter — where you face exactly.
    var bezelOpacity:         Double  { 0.28 }
    var bezelCoreOpacity:     Double  { 0.55 }
    var bezelCoreFraction:    Double  { 0.4 }
    var bezelInk:             Color   { .primary }

    // MARK: Look mode ▼ TWEAK ▼
    // Lift the phone and the chart opens into a WINDOW: the sky centres on
    // where the phone's back points and moves with the hand, one degree of
    // turn for one degree of sky. A crosshair stays fixed at the centre and
    // locks onto anything you could tap.

    /// The window's vertical field of view — roughly the phone camera's.
    var lookFieldOfViewDeg:   Double  { 60 }
    /// Crosshair ring radius (pt) at rest — also the lock radius.
    var crosshairRadius:       CGFloat { 26 }
    var crosshairLineWidth:    CGFloat { 1.5 }
    /// Resting ink — quiet glass, never the accent until something locks.
    var crosshairRestOpacity:  Double  { 0.55 }
    /// Below this much of the window, nothing locks.
    var crosshairLockBlend:    Double  { 0.9 }

    // Locked: the ring grows a touch and OPENS — the name written into the
    // top of the circle, the distance into the bottom, each in the gap its
    // own letters leave. A bezel inscription, not a caption under a ring.

    /// Ring radius once locked — the floor; a long name grows it further.
    var crosshairLockedRadius: CGFloat { 34 }
    /// Widest arc (degrees) one inscription may take before the ring grows
    /// to fit it instead.
    var crosshairMaxArcDeg:    Double  { 150 }
    /// Clear space (pt) between the letters and each cut end of the ring.
    var crosshairArcPadding:   CGFloat { 5 }
    /// Letter spacing (pt) of the inscriptions.
    var crosshairTracking:     CGFloat { 1.4 }
    /// The distance reads quieter than the name.
    var crosshairDistanceOpacity: Double { 0.75 }

    /// Camera scale that fits `lookFieldOfViewDeg` into a screen this tall.
    /// Stereographic: an angle θ off-centre lands at 2·tan(θ/2)·scale.
    func lookScale(screenHeight h: CGFloat) -> CGFloat {
        let half = lookFieldOfViewDeg / 2 * .pi / 180
        return (h / 2) / CGFloat(2 * tan(half / 2))
    }
}
