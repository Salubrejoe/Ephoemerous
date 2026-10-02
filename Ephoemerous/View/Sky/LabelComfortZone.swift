import SwiftUI

// MARK: - LabelComfortZone
// The calm middle of the screen, where names are allowed to speak. Outside
// it the sky still shows every badge and dot, but unpromoted TEXT — star
// and planet names, constellation names, Bayer letters — fades away toward
// the edges. The eye reads the centre; a rim of half-cut names at the edges
// is what made the map feel busy. (Maps does the same thing by density: the
// labels you see are the ones near where you're looking.)
//
// The zone is a squircle, feathered over its outer band, measured against
// where a label actually lands ON SCREEN — through the live pinch, rotation
// and pan the layers ride — so it holds still while the sky moves under it.
// The promoted pin and a selected constellation are exempt; they are the
// answer to "what did I just pick", and that's never noise.
struct LabelComfortZone {

    /// Canvas centre — the pivot the live pinch and rotation turn about.
    let pivot:    CGPoint
    /// The on-screen window, in canvas coordinates.
    let visible:  CGRect
    let pinch:    CGFloat
    let rotation: Angle
    let offset:   CGSize

    /// A zone with no edges, for previews and callers that opt out.
    static let everywhere = LabelComfortZone(pivot: .zero, visible: .infinite,
                                             pinch: 1, rotation: .zero, offset: .zero)

    /// Where a canvas point lands on screen (in the canvas's own frame):
    /// scale, then rotate, about the canvas centre, then pan — the order
    /// MainView applies them in. Labels are drawn upright at constant size
    /// at this point, which is what makes it the right space to compare
    /// them in (see `StarLabelLayout`).
    func screenPoint(_ sc: CGPoint) -> CGPoint {
        let dx = (sc.x - pivot.x) * pinch
        let dy = (sc.y - pivot.y) * pinch
        let c  = cos(rotation.radians), s = sin(rotation.radians)
        return CGPoint(x: pivot.x + dx * c - dy * s + offset.width,
                       y: pivot.y + dx * s + dy * c + offset.height)
    }

    /// 1 inside the calm middle, easing to 0 across the feathered rim.
    func nameVisibility(at sc: CGPoint) -> Double {
        guard !visible.isInfinite else { return 1 }
        let a      = Artist.shared
        let p      = screenPoint(sc)
        // Squircle distance from the window's centre, 1 at the zone's edge.
        let hw     = visible.width  * a.labelComfortWidth  / 2
        let hh     = visible.height * a.labelComfortHeight / 2
        let u      = abs(p.x - visible.midX) / hw
        let v      = abs(p.y - visible.midY) / hh
        let d      = pow(pow(u, 4) + pow(v, 4), 0.25)
        let t      = min(1, max(0, (1 - d) / a.labelComfortFeather))
        return t * t * (3 - 2 * t)
    }
}
