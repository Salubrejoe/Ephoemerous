import SwiftUI

// MARK: - LoreSymbol
// LoreKit's curated SF Symbol vocabulary — the set of symbols that any
// of my projects might reach for. A String-raw enum so each case
// pairs a Swift identifier with its SF Symbol name, and a concrete
// `Image(symbol:)` init below turns it into a compile-checked
// `Image(symbol: .checkmark)` everywhere LoreKit is imported.
//
// Why concrete: a *generic* `Image(symbol: S) where S.RawValue == String`
// init still lives at `Image+Symbol.swift` for any project that wants
// to pass its own enum, but Swift can't resolve a leading-dot shorthand
// against a generic constraint. A concrete init taking `LoreSymbol`
// gives every consumer `.checkmark`-style ergonomics with zero
// per-project boilerplate.
//
// Add new cases as the personal toolkit picks up symbols. Keep the raw
// value explicit even when it matches the case name — a few cases
// legitimately differ (`chevronUpDown` → `"chevron.up.chevron.down"`),
// and uniform `case x = "x"` formatting reads as one block at a glance.
public enum LoreSymbol: String, Sendable, CaseIterable {

    case calendar       = "calendar"
    case checkmark      = "checkmark"
    case chevronUpDown  = "chevron.up.chevron.down"
    case circle         = "circle"
    case declination    = "lines.measurement.vertical"
    case cup            = "cup.and.heat.waves"
    case cupEmpty       = "cup.and.saucer"
    case distance       = "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath"
    case drop           = "drop.fill"
    case eyes           = "eyes"
    case flame          = "flame"
    case gearCicleFill  = "gearshape.circle.fill"
    case hrClass        = "thermometer.sun"
    case location       = "location"
    case locationFill   = "location.fill"
    case magnitudeIcon  = "slider.horizontal.below.sun.max"
    case plus           = "plus"
    case rightAscension = "lines.measurement.horizontal"
    case record         = "smallcircle.filled.circle"
    case reset          = "arrow.counterclockwise"
    case resetClock     = "clock.arrow.circlepath"
    case save           = "square.and.arrow.down"
    case scalemass      = "scalemass"
    case search         = "magnifyingglass"
    case sort           = "line.3.horizontal.decrease.circle"
    case sparkles       = "sparkles"
    case sparkle        = "sparkle"
    case star           = "star"
    case starFill       = "star.fill"
    case stopFill       = "stop.fill"
    case target         = "target"
    case timer          = "timer"
    case trash          = "trash"
    case thumbsup       = "hand.thumbsup"
    case warning        = "exclamationmark.triangle.fill"
    case xmark          = "xmark"
    case xmarkCircle    = "xmark.circle"
}

// MARK: - Image(symbol: LoreSymbol)
// Concrete leading-dot-friendly init. Lives next to the enum it's
// specialised on so they ship as one unit.
public extension Image {
    init(symbol: LoreSymbol) {
        self.init(systemName: symbol.rawValue)
    }
}
