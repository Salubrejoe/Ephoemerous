import SwiftUI
import LoreKit

// MARK: - ESymbol
// Ephoemerous-specific SF Symbol vocabulary — the astronomy/domain glyphs
// that don't belong in LoreKit's cross-project `LoreSymbol` toolkit
// (bodies, moon phases, constellation-entity silhouettes, the
// longitude-bucketed globes). Same String-raw-enum + concrete
// `Image(symbol:)` pattern as `LoreSymbol`, so call sites get
// `Image(symbol: .sunMaxFill)` ergonomics.
//
// Case names are kept DISTINCT from every `LoreSymbol` case so the
// overloaded `Image(symbol:)` / `POIGlyph.symbol(_:)` resolve a leading-
// dot literal unambiguously (`.starFill` → LoreSymbol, `.sunMaxFill` →
// ESymbol). When two enums could legitimately share a glyph, prefer the
// LoreSymbol one (e.g. `.sparkles`) and don't duplicate it here.
enum ESymbol: String, CaseIterable {

    // Bodies
    case sunMax     = "sun.max"
    case sunMaxFill = "sun.max.fill"
    case moon       = "moon"
    case moonFill   = "moon.fill"

    // Moon phases (illuminated-fraction buckets) — see EArtist+Moon
    case moonNew            = "moonphase.new.moon"
    case moonWaxingCrescent = "moonphase.waxing.crescent"
    case moonFirstQuarter   = "moonphase.first.quarter"
    case moonWaxingGibbous  = "moonphase.waxing.gibbous"
    case moonFull           = "moonphase.full.moon"

    // Constellation-entity silhouettes — see EArtist+ConstellationEntity
    case entityHero       = "figure.stand"
    case entityAnimal     = "pawprint.fill"
    case entityCreature   = "tortoise.fill"
    case entityObject     = "diamond.fill"
    case entityInstrument = "ruler.fill"
    case entityDeity      = "crown.fill"
    case entityFallback   = "sparkles"

    // Longitude-bucketed globes — see EArtist+UserLocation
    case globeEuropeAfrica  = "globe.europe.africa.fill"
    case globeSouthAsia     = "globe.central.south.asia.fill"
    case globeAsiaAustralia = "globe.asia.australia.fill"
    case globeAmericas      = "globe.americas.fill"
    
    
    // Stats
    case rightAscension = "arrow.left.arrow.right"
    case declination    = "arrow.up.arrow.down"
    case distance       = "ruler"
    case magnitude      = "sparkle"
    case hrClass        = "thermometer.medium"
    case diameter       = "circle.dashed"
    case period         = "calendar"
}

// MARK: - Image(symbol: ESymbol)
// Concrete leading-dot-friendly init, mirroring LoreKit's
// `Image(symbol: LoreSymbol)`. A *generic* RawRepresentable init can't
// resolve `.case` shorthand, so each enum needs its own concrete one.
extension Image {
    init(symbol: ESymbol) {
        self.init(systemName: symbol.rawValue)
    }
}
