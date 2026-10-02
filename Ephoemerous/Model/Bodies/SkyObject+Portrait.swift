import SwiftUI

// MARK: - Portrait
// One line that says what a sky object IS, for the search sheet's
// remembered list:
//
//   Betelgeuse        →  Red supergiant in Orion
//   Ursa Minor        →  7 stars
//
// Deliberately NOT the old "STAR · ORION" caption. That repeated what
// the badge beside it already said; this earns its line by carrying
// something the row doesn't otherwise show.
//
// Lives in the model rather than the view because it is astronomy, not
// layout — absolute magnitude, spectral colour, the figure's star
// count. The row just prints `obj.portrait`.

extension SkyObject {

    /// The subtitle under the object's name in the remembered list.
    var portrait: String {
        switch self {
        case .star(let s):          return s.portrait
        case .constellation(let c): return c.portrait
        case .sun:                  return String(localized: "Yellow dwarf, 1 AU away")
        case .moon:                 return String(localized: "Earth's only natural satellite")
        case .planet(let p):        return p.mythology
        case .spacecraft(let c):    return c.portrait
        }
    }
}

// MARK: - Star

extension Star {

    /// "Red supergiant in Orion" — colour from the spectral class, size
    /// from the absolute magnitude, home from the Bayer designation.
    var portrait: String {
        String(localized: "\(sizeAndColour) in \(constellation.localizedName)")
    }

    /// "Red supergiant" / "White star". Sentence case: this is a
    /// description, not a title.
    private var sizeAndColour: String {
        "\(spectralClass.colourWord) \(luminosityWord)"
    }

    /// Absolute magnitude — how bright the star would look from a
    /// standard 10 parsecs. `M = m − 5·(log₁₀ d[pc] − 1)`, the same
    /// arithmetic `HRDiagramView` plots its scatter with.
    ///
    /// `nil` for the many catalogue stars we hold no distance for; a
    /// portrait falls back to a plain "star" rather than guessing a size.
    var absoluteMagnitude: Double? {
        guard let ly = distanceLY, ly > 0 else { return nil }
        let parsecs = ly / 3.26156
        return magnitude - 5 * (log10(parsecs) - 1)
    }

    /// Supergiant / giant / plain star, from absolute magnitude.
    ///
    /// Three bands, not the full Yerkes ladder. Luminosity class really
    /// depends on spectral class as well as brightness, and a
    /// three-band read is the part that stays true across the whole
    /// catalogue: Rigel and Betelgeuse land on supergiant, Aldebaran on
    /// giant, Sirius and Vega on star — which is what each of them is.
    /// Splitting finer than the data supports would invent precision.
    private var luminosityWord: String {
        guard let m = absoluteMagnitude else { return String(localized: "star") }
        if m <= -5 { return String(localized: "supergiant") }
        if m <=  0 { return String(localized: "giant") }
        return String(localized: "star")
    }
}

// MARK: - Constellation

extension Constellation {

    /// "7 stars" — how many stars the stick figure actually draws
    /// through. Not every star the catalogue files inside the
    /// constellation's boundary: the figure's count is the one that
    /// matches what the user can see on the canvas.
    var portrait: String {
        let count = ConstellationLines.shared.figureStarCount(of: self)
        return count == 1
            ? String(localized: "1 star")
            : String(localized: "\(count) stars")
    }
}

// MARK: - Spectral colour

extension HRClass {

    /// The colour a class actually looks, in plain words. Harvard
    /// classes run hot-blue to cool-red; these are the standard
    /// readings, and they are what makes "Red supergiant" mean
    /// something to someone who has never heard of an M-class star.
    var colourWord: String {
        switch self {
        case .O:       return String(localized: "Blue")
        case .B:       return String(localized: "Blue-white")
        case .A:       return String(localized: "White")
        case .F:       return String(localized: "Yellow-white")
        case .G:       return String(localized: "Yellow")
        case .K:       return String(localized: "Orange")
        case .M:       return String(localized: "Red")
        case .unknown: return String(localized: "Unclassified")
        }
    }
}

// MARK: - Spacecraft

extension Spacecraft {

    /// Where it lives, in the terms that make it findable: the two
    /// low-orbit craft by their height, Webb by how far out it waits.
    var portrait: String {
        switch self {
        case .iss:    return String(localized: "Crewed station, 420 km up")
        case .hubble: return String(localized: "Space telescope, 530 km up")
        case .jwst:   return String(localized: "Infrared telescope at L2")
        case .tiangong: return String(localized: "Crewed station, 390 km up")
        }
    }
}
