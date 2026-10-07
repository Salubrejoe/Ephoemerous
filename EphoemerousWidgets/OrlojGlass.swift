import SwiftUI
import LoreKit

// MARK: - OrlojGlassLayers
// The 2.0 face: the Prague mechanism, cast in glass.
//
// The PLATE is light — fixed altitude fields (day, civil, nautical,
// astronomical, night) in flat colour. They never change colour; the Sun
// hand moves through them. Every other part — the crown and its numerals,
// the rete (band, cross, star hand), its glyphs, the hands — is a lens over
// that light: the plate blurred and lifted inside the part's outline, a
// body of ink, a rim lit from above.
//
// `.glassEffect` doesn't render in the widget process, so the glass is
// built from parts that rasterise anywhere (see `OrlojGlassPiece`).
//
// No badges, no stars: nothing on this face looks tappable, because
// nothing on a widget is.
struct OrlojGlassLayers: View {
    let face: OrlojFace

    /// The host renders the widget as a luminance map (tinted / Clear
    /// Home Screen). The coloured plate would come back solid white, so
    /// it goes; the glass keeps its alpha and reads as clear glass.
    var lineArt: Bool = false

    private var palette: OrlojGlassPalette { OrlojGlassPalette(lineArt: lineArt) }
    private var isLarge: Bool              { face.ui >= 0.7 }

    var body: some View {
        ZStack {
            if !lineArt {
                OrlojPlateLight(face: face, palette: palette)
            }
            OrlojPlateLines(face: face, palette: palette, showsHours: isLarge)
            OrlojGlassPieces(pieces: plateRingGlass, face: face, palette: palette)

            if face.numeralRing == .crown {
                OrlojGlassPieces(pieces: [crownGlass], face: face, palette: palette)
            }
            if face.numeralRing == .contour && !Self.contourInGlass {
                OrlojFlatNumerals(face: face, palette: palette)
            } else {
                OrlojGlassPieces(pieces: numeralGlass(daylit: false), face: face, palette: palette)
                OrlojGlassPieces(pieces: numeralGlass(daylit: true),  face: face, palette: palette,
                                 variant: .regular)
            }

            OrlojGlassPieces(pieces: [reteGlass], face: face, palette: palette)
            if isLarge {
                OrlojGlassPieces(pieces: glyphGlass, face: face, palette: palette, variant: .regular)
            }

            OrlojGlassPieces(pieces: handGlass, face: face, palette: palette)
            OrlojHubEarth(face: face, palette: palette)
        }
        // A round dial keeps a breath of the widget's ground round it.
        .scaleEffect(face.numeralRing == .contour ? 1 : 0.95)
        .dynamicTypeSize(.large)
    }

    /// The Contour numerals in glass, or flat ink while their layout is
    /// being tuned. The Roman rings are always glass. ▼ TWEAK ▼
    private static let contourInGlass = false

    /// The tropics and the equator — thin rings of clear glass on the plate.
    private var plateRingGlass: [OrlojGlassPiece] {
        face.plateRingPaths().map { OrlojGlassPiece(path: $0) }
    }

    /// The crown band — even-odd, so the plate shows through its middle.
    private var crownGlass: OrlojGlassPiece {
        OrlojGlassPiece(path: face.dialBandPath(), eoFill: true)
    }

    /// The hours in glass: daylit hours frosted (regular), night hours
    /// clear — the ring echoes the plate.
    private func numeralGlass(daylit: Bool) -> [OrlojGlassPiece] {
        let numerals = face.numeralRing == .contour
            ? face.contourNumerals().map { (path: $0.path, isDay: $0.isDay) }
            : face.numeralGlassPaths()
        return numerals
            .filter { $0.isDay == daylit }
            .map    { OrlojGlassPiece(path: $0.path) }
    }

    /// The rete — band, cross, hub and (large only) the star hand as one
    /// piece of glass.
    private var reteGlass: OrlojGlassPiece {
        OrlojGlassPiece(path: face.reteGlassPath(withStarHand: isLarge))
    }

    /// The sign glyphs, warped into the band — regular glass on the
    /// band's clear glass, so they read.
    private var glyphGlass: [OrlojGlassPiece] {
        face.zodiacGlyphPaths().map { OrlojGlassPiece(path: $0) }
    }

    /// The Sun and Moon hands, front of the stack — plain glass.
    private var handGlass: [OrlojGlassPiece] {
        [face.moonCapsulePath(), face.sunCapsulePath()]
            .compactMap { $0.map { OrlojGlassPiece(path: $0) } }
    }
}

// MARK: - Palette
// Every colour is derived in OKLCH from the app's anchors and fitted to
// Display P3 (values checked in-gamut):
//   • night       = the canvas sky (canvas L .20 C .034 h 258, −10% black)
//   • Prague's plate: night navy under the twilight line, one orange for
//     AVRORA and CREPVSCVLVM, and the day in twelve light blues — one per
//     unequal hour, gaining colour toward noon — round the Earth's disc
//   • glass ink   = `Artist.ink`, the cool near-white; never pure white
//   • the Sun     = a G-class star, like any other (`palette.sun`)
struct OrlojGlassPalette {
    let lineArt: Bool

    var ink:   Color { Artist.shared.ink }
    var night: Color { Artist.shared.skyColor }

    /// The day — the plate's ground, everything above the horizon.
    var day: Color { Self.dayLight }

    /// Field colour for the sky BELOW `altitude` (inside its circle).
    func field(below altitude: Angle) -> Color {
        altitude.degrees > -18 ? Self.aurora : night
    }

    /// The `k`th unequal hour's blue (0 = the first after sunrise): palest
    /// at the horizons, richest at noon.
    static func hour(_ k: Int) -> Color {
        hourBlues[min(k, 11 - k)]
    }

    static let aurora       = Color(.displayP3, red: 0.844, green: 0.569, blue: 0.304)   // OKLCH L .72  C .140  h  60
    static let earth        = Color(.displayP3, red: 0.530, green: 0.737, blue: 0.802)   //       L .76  C .075  h 215
    /// ▼ TWEAK the day's blues — horizon first, noon last ▼
    static let hourBlues: [Color] = [
        Color(.displayP3, red: 0.725, green: 0.812, blue: 0.857),                       //       L .84  C .035  h 225
        Color(.displayP3, red: 0.657, green: 0.781, blue: 0.846),                       //       L .81  C .050  h 226
        Color(.displayP3, red: 0.590, green: 0.748, blue: 0.838),                       //       L .78  C .065  h 228
        Color(.displayP3, red: 0.524, green: 0.714, blue: 0.830),                       //       L .75  C .080  h 230
        Color(.displayP3, red: 0.457, green: 0.680, blue: 0.824),                       //       L .72  C .095  h 232
        Color(.displayP3, red: 0.391, green: 0.644, blue: 0.818),                       //       L .69  C .110  h 234
    ]
    static let dayLight     = Color(.displayP3, red: 0.351, green: 0.554, blue: 0.774)   //       L .63  C .115  h 246
    static let earthHigh    = Color(.displayP3, red: 0.414, green: 0.673, blue: 0.733)   //       L .70  C .090  h 210
    static let earthLow     = Color(.displayP3, red: 0.097, green: 0.213, blue: 0.294)   //       L .32  C .060  h 235

    // ▼ TWEAK the glass recipe here ▼
    var frostBlur:      CGFloat { 5 }       // pt of extra blur inside a lens, × ui
    var frostSaturation: Double { 1.15 }
    var frostLift:       Double { 0.06 }

    /// The body of a lens: a whisper on clear glass; on regular glass a
    /// frosted veil of ink, so a glyph reads against the glass behind it.
    func bodyOpacity(_ variant: OrlojGlassVariant) -> Double {
        switch variant {
        case .clear:   return lineArt ? 0.10 : 0.07
        case .regular: return lineArt ? 0.45 : 0.42
        }
    }

    /// Rim light — bright top-left, dim across the middle, a bounce at
    /// the bottom-right. The badges' "lit from above".
    var rim: LinearGradient {
        LinearGradient(stops: [.init(color: ink.opacity(0.95), location: 0),
                               .init(color: ink.opacity(0.14), location: 0.5),
                               .init(color: ink.opacity(0.50), location: 1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Glass

/// Liquid Glass's two variants, hand-rolled: `.clear` lets the plate's
/// light through almost untouched; `.regular` is frosted, for marks that
/// must read on top of other glass.
enum OrlojGlassVariant {
    case clear
    case regular
}

struct OrlojGlassPiece {
    let path:   Path
    var eoFill: Bool = false
}

/// One pass of glass: the plate's light seen through every piece's
/// outline (blurred, saturated, lifted), a thin body, one shadow for the
/// whole pass, then each piece's rim.
struct OrlojGlassPieces: View {
    let pieces:  [OrlojGlassPiece]
    let face:    OrlojFace
    let palette: OrlojGlassPalette
    var variant: OrlojGlassVariant = .clear

    var body: some View {
        ZStack {
            ZStack {
                if !palette.lineArt {
                    OrlojPlateLight(face: face, palette: palette)
                        .blur(radius: palette.frostBlur * face.ui)
                        .saturation(palette.frostSaturation)
                        .brightness(palette.frostLift)
                }
                palette.ink.opacity(palette.bodyOpacity(variant))
            }
            .mask { silhouette }
            .compositingGroup()
            .shadow(color: .black.opacity(palette.lineArt ? 0 : 0.45),
                    radius: 2 * face.ui, y: 1.6 * face.ui)

            ForEach(pieces.indices, id: \.self) { i in
                OrlojPath(source: pieces[i].path)
                    .stroke(palette.rim, lineWidth: 0.9)
            }
        }
    }

    private var silhouette: some View {
        ZStack {
            ForEach(pieces.indices, id: \.self) { i in
                OrlojPath(source: pieces[i].path)
                    .fill(.white, style: FillStyle(eoFill: pieces[i].eoFill))
            }
        }
    }
}

// MARK: - Plate

/// The plate's light: day, then each altitude field painted over the
/// last down to night — inside the crown, or filling the whole widget
/// under the Contour ring. Flat colour, crisp edges.
struct OrlojPlateLight: View {
    let face:    OrlojFace
    let palette: OrlojGlassPalette

    var body: some View {
        ZStack {
            Rectangle().fill(palette.day)
            ForEach(Array(face.unequalHourSections().enumerated()), id: \.offset) { k, section in
                OrlojPath(source: section).fill(OrlojGlassPalette.hour(k))
            }
            ForEach(face.altitudeFields(), id: \.altitude) { field in
                OrlojPath(source: field.path).fill(palette.field(below: field.altitude))
            }
            OrlojPath(source: face.earthDiscPath()).fill(OrlojGlassPalette.earth)
        }
        .clipShape(OrlojPath(source: face.plateFillPath()))
    }
}

/// Hairlines on the plate: the field edges, the horizon brightest, and
/// the unequal hours where there's room for them.
struct OrlojPlateLines: View {
    let face:       OrlojFace
    let palette:    OrlojGlassPalette
    let showsHours: Bool

    var body: some View {
        ZStack {
            if showsHours {
                OrlojPath(source: face.unequalHoursPath())
                    .stroke(palette.ink.opacity(0.14), lineWidth: 0.5)
            }
            // The horizon and the twilight line; the orange runs unbroken between.
            ForEach(face.altitudeFields().filter { $0.altitude.degrees.truncatingRemainder(dividingBy: 18) == 0 },
                    id: \.altitude) { field in
                OrlojPath(source: field.path)
                    .stroke(palette.ink.opacity(field.altitude == .zero ? 0.6 : 0.18),
                            lineWidth: field.altitude == .zero ? 0.9 * face.ui + 0.1 : 0.5)
            }
        }
        // The Earth's disc is painted over the lines, as on the original.
        .clipShape(OrlojPath(source: face.plateFillPath().subtracting(face.earthDiscPath())))
    }
}

// MARK: - Numerals

/// The Contour numerals as flat ink — no glass — for judging their layout.
struct OrlojFlatNumerals: View {
    let face:    OrlojFace
    let palette: OrlojGlassPalette

    var body: some View {
        ForEach(Array(face.contourNumerals().enumerated()), id: \.offset) { _, numeral in
            OrlojPath(source: numeral.path).fill(palette.ink)
        }
    }
}

// MARK: - Bodies on the band

/// The five naked-eye planets as glowing beads, in their own colours.
struct OrlojPlanetBeads: View {
    let face:    OrlojFace
    let palette: OrlojGlassPalette

    private static let hidden: Set<String> = [Strings.Planets.uranus, Strings.Planets.neptune]

    var body: some View {
        ForEach(face.planetMarks().filter { !Self.hidden.contains($0.id) }, id: \.id) { mark in
            let colour = Artist.shared.planetGradient(mark.planet).top
            Circle()
                .fill(palette.lineArt ? palette.ink.opacity(0.85) : colour)
                .frame(width: 4.4 * face.ui + 1, height: 4.4 * face.ui + 1)
                .shadow(color: colour.opacity(palette.lineArt ? 0 : 0.9), radius: 2.5 * face.ui)
                .position(mark.position)
        }
    }
}

// MARK: - Bodies on the hands

/// The axle: the Earth, seen from above the pole, inside the hub's glass.
struct OrlojHubEarth: View {
    let face:    OrlojFace
    let palette: OrlojGlassPalette

    var body: some View {
        Circle()
            .fill(palette.lineArt
                  ? AnyShapeStyle(palette.ink.opacity(0.5))
                  : AnyShapeStyle(RadialGradient(colors: [OrlojGlassPalette.earthHigh,
                                                          OrlojGlassPalette.earthLow],
                                                 center: UnitPoint(x: 0.36, y: 0.30),
                                                 startRadius: 0,
                                                 endRadius: face.hubRadius * 1.5)))
            .frame(width: face.hubRadius * 1.44, height: face.hubRadius * 1.44)
            .position(face.center)
    }
}

/// The Moon's ball: dark glass with the lit part in ink, at the real phase.
struct OrlojMoonBall: View {
    let face:    OrlojFace
    let palette: OrlojGlassPalette

    var body: some View {
        if let point = face.moonPoint {
            let size  = 15 * face.ui
            let phase = MoonPosition.phase(for: face.date, latitude: face.latitude)
            ZStack {
                Circle().fill(palette.night.opacity(palette.lineArt ? 0.2 : 0.7))
                Circle().stroke(palette.rim, lineWidth: 0.8)
                if !phase.isNew {
                    MoonPhaseShape(phase: phase).fill(palette.ink)
                }
            }
            .frame(width: size, height: size)
            .position(point)
        }
    }
}

/// The Sun — a G-class star like any other, as a twelve-lobed disc
/// (the crown's own scallop, small), glowing.
struct OrlojSunDisc: View {
    let face:    OrlojFace
    let palette: OrlojGlassPalette

    var body: some View {
        if let point = face.sunPoint {
            let sun  = Artist.shared.palette.sun
            let size = 22 * face.ui
            Squircle(corners: 12, bulge: 1.3)
                .fill(palette.lineArt
                      ? AnyShapeStyle(palette.ink)
                      : AnyShapeStyle(RadialGradient(colors: [sun.top, sun.bottom],
                                                     center: .center,
                                                     startRadius: 0,
                                                     endRadius: size / 2)))
                .frame(width: size, height: size)
                .shadow(color: sun.bottom.opacity(palette.lineArt ? 0 : 0.9), radius: 5 * face.ui)
                .position(point)
        }
    }
}
