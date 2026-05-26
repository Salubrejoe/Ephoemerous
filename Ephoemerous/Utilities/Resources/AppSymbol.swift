import Foundation

// MARK: - AppSymbol
// The app's SF Symbol vocabulary — a String-raw enum that turns
// stringly-typed `Image(systemName: "checkmark")` into compile-checked
// `Image(symbol: .checkmark)` via the specialised init in
// `Image+init.swift`. The underlying generic plumbing
// (`Image(symbol: S) where S.RawValue == String`) lives in LoreKit.
//
// Naming: singular per Swift convention (`Color.red`, `Edge.top`); a
// future MenuSymbol / ToolbarSymbol would coexist cleanly.
//
// Add new cases as the app picks up symbols. Keep the raw value
// explicit even when it matches the case name — a few cases legitimately
// differ (`chevronUpDown` → `"chevron.up.chevron.down"`), and uniform
// `case x = "x"` formatting reads as one block at a glance.
enum AppSymbol: String {

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
