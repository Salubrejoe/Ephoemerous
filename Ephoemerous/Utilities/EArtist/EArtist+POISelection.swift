import SwiftUI
import LoreKit

// MARK: - POI label selection promotion
//
// Tapping a POI promotes its label: the badge lifts off its precise
// location, scales up, and the name slides to sit centred *under*
// the dot in primary ink. Dead simple — a single `promotion` value
// (0 = flat label, 1 = fully promoted) eased 0→1 over a quick
// scale-up. No wiggle, no overlay, no cache: the brief ease is the
// only thing that wakes the canvas, and it parks again right after.
// The caller derives `promotion` from "seconds since selection"
// via `poiSelectProgress`.
extension EArtist {

    /// Enlarged scale a fully-promoted badge settles at.
    var poiSelectScale: CGFloat { 1.88}
    /// How far the promoted badge lifts above the dot, as a multiple
    /// of `badgeSize`.
    var poiSelectLiftFactor: CGFloat { 1.45 }
    /// Gap between the dot and the top of the dropped-below name.
    var poiSelectNameDrop: CGFloat { 7 }
    /// Radius of the precise-location dot left under a promoted pin.
    var poiSelectDotRadius: CGFloat { 2.5 }
    /// Seconds the promotion takes to ease in / out — a quick scale-up.
    var poiSelectRise: Double { 0.3 }
    /// Seconds after a (de)selection past which the promotion is settled.
    /// It's a plain ease now (no wiggle tail), so this is just the rise:
    /// `EAppState` keeps the canvas ticking for exactly the ease, then
    /// parks — no long redraw window, no stutter.
    var poiSelectSettleDuration: Double { poiSelectRise }

    /// Eased promotion value, lerped `from → to` (0 unselected, 1
    /// selected) over `poiSelectRise` seconds via smoothstep.
    /// `elapsed` is seconds since the selection toggled.
    func poiSelectProgress(from: Double, to: Double, elapsed: Double) -> Double {
        let t = min(max(elapsed / poiSelectRise, 0), 1)
        let e = t * t * (3 - 2 * t)
        return from + (to - from) * e
    }
}
