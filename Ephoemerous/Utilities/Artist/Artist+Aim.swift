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
}
