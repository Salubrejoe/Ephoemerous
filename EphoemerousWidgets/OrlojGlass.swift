import SwiftUI
import LoreKit

// MARK: - OrlojGlassLayers
// The 2.0 face: the Prague mechanism, cast in glass.
//
// The PLATE is light — fixed altitude fields (day, civil, nautical,
// astronomical, night) softened like light behind frosted glass. They
// never change colour; the Sun hand moves through them. Every MOVING
// part — crown, zodiac band, the rete's cross, the three hands, the axle —
// is a lens over that light: the plate blurred and lifted inside the
// part's outline, a whisper of body, a rim lit from above.
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

            OrlojGlassPieces(pieces: reteGlass, face: face, palette: palette)
            OrlojCrownNumerals(face: face, palette: palette)
            OrlojZodiacMarks(face: face, palette: palette, showsGlyphs: false)

            OrlojGlassPieces(pieces: handGlass, face: face, palette: palette)
            OrlojHubEarth(face: face, palette: palette)
        }
        .scaleEffect(0.95)
        .dynamicTypeSize(.large)
    }

    /// The crown, and the rete — band, cross, hub and (large only) the
    /// star hand as one piece of glass.
    private var reteGlass: [OrlojGlassPiece] {
        [OrlojGlassPiece(path: face.dialBandPath(), eoFill: true),
         OrlojGlassPiece(path: face.reteGlassPath(withStarHand: isLarge))]
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
//   • the fields climb in L and swing in hue from the navy toward the
//     star ramp's amber: indigo → mulberry → K-class amber → sky blue
//   • glass ink   = `Artist.ink`, the cool near-white; never pure white
//   • the Sun     = a G-class star, like any other (`palette.sun`)
struct OrlojGlassPalette {
    let lineArt: Bool

    var ink:   Color { Artist.shared.ink }
    var night: Color { Artist.shared.skyColor }

    /// The day — the plate's ground, everything above the horizon.
    var day: LinearGradient {
        LinearGradient(colors: [Self.dayHigh, Self.dayLow], startPoint: .top, endPoint: .bottom)
    }

    /// Field colour for the sky BELOW `altitude` (inside its circle).
    func field(below altitude: Angle) -> Color {
        switch Int(altitude.degrees.rounded()) {
        case   0: return Self.civil
        case  -6: return Self.nautical
        case -12: return Self.astronomical
        default:  return night
        }
    }


    static let astronomical = Color(.displayP3, red: 0.175, green: 0.143, blue: 0.321)   // OKLCH L .30  C .085  h 290
    static let nautical     = Color(.displayP3, red: 0.442, green: 0.236, blue: 0.445)   //       L .45  C .120  h 330
    static let civil        = Color(.displayP3, red: 0.853, green: 0.604, blue: 0.352)   //       L .74  C .130  h  62
    static let dayHigh      = Color(.displayP3, red: 0.463, green: 0.700, blue: 0.891)   //       L .74  C .110  h 238
    static let dayLow       = Color(.displayP3, red: 0.257, green: 0.410, blue: 0.656)   //       L .52  C .120  h 255
    static let earthHigh    = Color(.displayP3, red: 0.414, green: 0.673, blue: 0.733)   //       L .70  C .090  h 210
    static let earthLow     = Color(.displayP3, red: 0.097, green: 0.213, blue: 0.294)   //       L .32  C .060  h 235

    // ▼ TWEAK the glass recipe here ▼
    var plateSoftness:  CGFloat { 3.5 }     // pt of blur on the light, × ui
    var frostBlur:      CGFloat { 5 }       // pt of extra blur inside a lens, × ui
    var frostSaturation: Double { 1.15 }
    var frostLift:       Double { 0.06 }
    var bodyOpacity:     Double { lineArt ? 0.10 : 0.07 }

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

    var body: some View {
        ZStack {
            ZStack {
                if !palette.lineArt {
                    OrlojPlateLight(face: face, palette: palette)
                        .blur(radius: palette.frostBlur * face.ui)
                        .saturation(palette.frostSaturation)
                        .brightness(palette.frostLift)
                }
                palette.ink.opacity(palette.bodyOpacity)
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
/// last down to night, clipped to the plate and softened.
struct OrlojPlateLight: View {
    let face:    OrlojFace
    let palette: OrlojGlassPalette

    var body: some View {
        ZStack {
            Rectangle().fill(palette.day)
            ForEach(face.altitudeFields(), id: \.altitude) { field in
                OrlojPath(source: field.path).fill(palette.field(below: field.altitude))
            }
        }
        .clipShape(OrlojPath(source: face.plateDiscPath()))
        .blur(radius: palette.plateSoftness * face.ui)
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
            ForEach(face.altitudeFields(), id: \.altitude) { field in
                OrlojPath(source: field.path)
                    .stroke(palette.ink.opacity(field.altitude == .zero ? 0.6 : 0.18),
                            lineWidth: field.altitude == .zero ? 0.9 * face.ui + 0.1 : 0.5)
            }
        }
        .clipShape(OrlojPath(source: face.plateDiscPath()))
    }
}

// MARK: - Crown & rete marks

/// Roman numerals on the glass crown. Daylit hours in full ink, night
/// hours dimmer: the crown echoes the plate.
struct OrlojCrownNumerals: View {
    let face:    OrlojFace
    let palette: OrlojGlassPalette

    var body: some View {
        ForEach(face.dialNumerals(), id: \.id) { numeral in
            Text(numeral.text)
                .font(.system(size: 9 * face.type, weight: .semibold, design: .serif))
                .foregroundStyle(palette.ink.opacity(numeral.isDay ? 0.95 : 0.55))
                .shadow(color: .black.opacity(palette.lineArt ? 0 : 0.35), radius: 1)
                .rotationEffect(numeral.rotation)
                .position(numeral.position)
        }
    }
}

/// Sign dividers and glyphs on the zodiac band.
struct OrlojZodiacMarks: View {
    let face:        OrlojFace
    let palette:     OrlojGlassPalette
    let showsGlyphs: Bool

    var body: some View {
        ZStack {
            OrlojPath(source: face.zodiacTicksPath())
                .stroke(palette.ink.opacity(0.55), lineWidth: 0.7)
            if showsGlyphs {
                ForEach(face.zodiacGlyphs(), id: \.id) { glyph in
                    Text(glyph.symbol)
                        .font(.system(size: 10 * face.type, weight: .semibold))
                        .foregroundStyle(palette.ink.opacity(0.85))
                        .rotationEffect(glyph.rotation)
                        .position(glyph.position)
                }
            }
        }
    }
}

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
