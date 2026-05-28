import Foundation

// MARK: - EPlanet + Mythology
// Mythological role + astronomical glyph for each planet — used by the
// detail-sheet header to give planets a subtitle parallel to the
// constellation "Hero in the Perseus Myth" framing. Same source of
// truth for both the spoken/displayed identity and the Unicode glyph
// the canvas already uses for badges.
extension EPlanet {

    /// Roman / Greek mythological role — shown as the detail-sheet
    /// subtitle so the planet detail matches the constellation detail
    /// in voice (a one-line "what this is, mythologically").
    var mythology: String {
        switch name {
        case Strings.Planets.mercury: return "Messenger of the Roman Gods"
        case Strings.Planets.venus:   return "Roman Goddess of Love"
        case Strings.Planets.mars:    return "Roman God of War"
        case Strings.Planets.jupiter: return "King of the Roman Gods"
        case Strings.Planets.saturn:  return "Roman God of Time"
        case Strings.Planets.uranus:  return "Greek God of the Sky"
        case Strings.Planets.neptune: return "Roman God of the Sea"
        default:                      return "Planet"
        }
    }

    /// Astronomical Unicode glyph — same characters the canvas badge
    /// system uses (`POIGlyph.unicode(...)` in EArtist+POILabel).
    var astronomicalGlyph: String {
        switch name {
        case Strings.Planets.mercury: return "☿"
        case Strings.Planets.venus:   return "♀"
        case Strings.Planets.mars:    return "♂"
        case Strings.Planets.jupiter: return "♃"
        case Strings.Planets.saturn:  return "♄"
        case Strings.Planets.uranus:  return "♅"
        case Strings.Planets.neptune: return "♆"
        default:                      return "•"
        }
    }
}
