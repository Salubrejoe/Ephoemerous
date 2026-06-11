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
    var poiSelectRise: Double { 0.7 }
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

    /// Spring damping for the badge-scale bounce. LOWER = looser, bigger
    /// overshoot, more visible wobble; higher = settles faster. ~5 is a
    /// lively-but-tasteful spring; drop toward 3 for a real boing.
    var poiSelectSpringDamping: Double { 4 }
    /// Number of half-swings in the spring — effectively the bounce count.
    /// 1 = a single overshoot; 2 = overshoot + a little undershoot; 3+ =
    /// more wobble. Rounded to an integer so the curve lands exactly on its
    /// settled size at the end.
    var poiSelectSpringBounces: Double { 3 }

    /// Badge-scale promotion fraction as a DAMPED COSINE — the symbol
    /// overshoots and springs to rest instead of easing flatly. Mapped from
    /// the smooth `promo` (0→1):
    ///
    ///   f(p) = 1 − e^(−damping·p) · cos(freq·p),   freq = (bounces+½)·π
    ///
    /// `f(0) = 0` and — because `cos(freq) == 0` by construction —
    /// `f(1) == 1` EXACTLY, so the badge lands on its settled size the
    /// instant the canvas parks (no residual, no snap, no extra frames).
    /// The overshoot/wobble amplitude is the physical spring response, set
    /// by `poiSelectSpringDamping`. Only the badge SCALE rides this; lift,
    /// name slide and opacities stay on the plain `promo`.
    func poiSelectScaleFraction(_ promo: Double) -> CGFloat {
        let p    = min(max(promo, 0), 1)
        let freq = (poiSelectSpringBounces.rounded() + 0.5) * .pi
        return CGFloat(1 - exp(-poiSelectSpringDamping * p) * cos(freq * p))
    }
}
