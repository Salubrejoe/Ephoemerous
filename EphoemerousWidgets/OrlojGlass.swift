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

    /// What the moving parts are made of (see `OrlojMaterial`). ▼ TWEAK ▼
    var material: OrlojMaterial = .glass

    private var palette: OrlojGlassPalette { OrlojGlassPalette(lineArt: lineArt) }
    private var isLarge: Bool              { face.ui >= 0.7 }

    var body: some View {
        ZStack {
            if !lineArt {
                OrlojPlateLight(face: face, palette: palette, material: material)
            }
            OrlojPlateLines(face: face, palette: palette, showsHours: isLarge, material: material)
            OrlojGlassPieces(pieces: plateRingGlass, face: face, palette: palette, material: material)

            if face.numeralRing == .crown {
                OrlojGlassPieces(pieces: [crownGlass], face: face, palette: palette, material: material)
            }
            if face.numeralRing == .contour && !Self.contourInGlass {
                OrlojFlatNumerals(face: face, palette: palette)
            } else {
                // Glass frosts the daylit hours; every other material casts
                // all twenty-four alike.
                OrlojGlassPieces(pieces: numeralGlass(daylit: false), face: face, palette: palette,
                                 material: material)
                OrlojGlassPieces(pieces: numeralGlass(daylit: true),  face: face, palette: palette,
                                 variant: material == .glass ? .regular : .clear, material: material)
            }

            OrlojGlassPieces(pieces: [reteGlass], face: face, palette: palette,
                             material: material, outlined: true)

            // The hands, the Moon's below the Sun's; its lit part frosted.
            OrlojGlassPieces(pieces: piece(face.moonCapsulePath()), face: face, palette: palette,
                             material: material)
            OrlojTintedGlass(path: face.moonLitPath(), tint: moonTint, face: face, palette: palette)
            OrlojGlassPieces(pieces: piece(face.sunCapsulePath()), face: face, palette: palette,
                             material: material)
            OrlojTintedGlass(path: face.sunBadgePath(), tint: sunTint, face: face, palette: palette)
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
    /// piece of glass, the sign glyphs carved through it.
    private var reteGlass: OrlojGlassPiece {
        OrlojGlassPiece(path: face.reteGlassPath(withStarHand: isLarge, carvesGlyphs: isLarge))
    }

    /// The badges' colours — the app's own: the Sun a G-class star, the
    /// Moon's lit face in its silver (the app paints it bottom-lit).
    private var sunTint:  (top: Color, bottom: Color) { Artist.shared.palette.sun }
    private var moonTint: (top: Color, bottom: Color) {
        (Artist.shared.palette.moon.bottom, Artist.shared.palette.moon.top)
    }

    /// A single optional path as a pass of glass.
    private func piece(_ path: Path?) -> [OrlojGlassPiece] {
        path.map { [OrlojGlassPiece(path: $0)] } ?? []
    }
}

// MARK: - Palette
// Every colour is derived in OKLCH from the app's anchors and fitted to
// Display P3 (values checked in-gamut):
//   • night       = the canvas sky (canvas L .20 C .034 h 258, −10% black)
//   • Prague's plate: night navy under the twilight line, the palest blue
//     for AVRORA and CREPVSCVLVM, and the day in twelve light blues — one per
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

    /// AVRORA and CREPVSCVLVM: one step paler than the palest hour.
    static let aurora       = Color(.displayP3, red: 0.792, green: 0.843, blue: 0.867)   // OKLCH L .87  C .020  h 224
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
    let pieces:   [OrlojGlassPiece]
    let face:     OrlojFace
    let palette:  OrlojGlassPalette
    var variant:  OrlojGlassVariant = .clear
    var material: OrlojMaterial     = .glass
    /// Light traces a big piece's outline instead of filling it.
    var outlined: Bool              = false

    var body: some View {
        // A luminance-mapped Home Screen keeps the glass: it survives as alpha.
        switch palette.lineArt ? .glass : material {
        case .glass:    glass
        case .gold:     metal(.gold)
        case .titanium: metal(.titanium(spunAround: unitCentre))
        case .paper:    paper
        case .light:    light
        }
    }

    private var glass: some View {
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

    /// Every piece's outline, stroked.
    private func edges<S: ShapeStyle>(_ style: S, width: CGFloat) -> some View {
        ZStack {
            ForEach(pieces.indices, id: \.self) { i in
                OrlojPath(source: pieces[i].path).stroke(style, lineWidth: width)
            }
        }
    }

    /// The axle, in the widget's unit square — where the spinning is centred.
    private var unitCentre: UnitPoint {
        UnitPoint(x: face.center.x / max(face.camera.size.width,  1),
                  y: face.center.y / max(face.camera.size.height, 1))
    }

    // MARK: Metal
    // A body in the metal's own sheen, a bevel (lit along the top-left
    // edges, shaded along the bottom-right), and a tight shadow. Engraved
    // marks (`.regular`) sink instead: dark, with the bevel reversed.

    private func metal(_ metal: OrlojMetal) -> some View {
        let engraved = variant == .regular
        let bevel    = LinearGradient(colors: [metal.highlight, metal.deep],
                                      startPoint: engraved ? .bottomTrailing : .topLeading,
                                      endPoint:   engraved ? .topLeading     : .bottomTrailing)
        return ZStack {
            Rectangle().fill(engraved ? AnyShapeStyle(metal.engraved) : metal.body)
            edges(bevel, width: 1.8 * face.ui)
        }
        .mask { silhouette }
        .compositingGroup()
        .shadow(color: .black.opacity(engraved ? 0 : 0.5), radius: 1.4 * face.ui, y: 1.1 * face.ui)
    }

    // MARK: Paper
    // Cut card: a flat warm white (engraved marks in navy card), a crisp
    // cut edge, and two shadows — a contact line and a soft lift.

    private var paper: some View {
        let card: Color = variant == .regular ? OrlojMaterial.paperNavy : OrlojMaterial.paperCard
        return ZStack {
            Rectangle().fill(card)
            edges(OrlojMaterial.paperShade, width: 0.8 * face.ui)
        }
        .mask { silhouette }
        .compositingGroup()
        .shadow(color: .black.opacity(0.22), radius: 0.5 * face.ui, y: 0.5 * face.ui)
        .shadow(color: .black.opacity(0.30), radius: 3.5 * face.ui, y: 2.5 * face.ui)
    }

    // MARK: Light
    // No body at all: a white-hot core in each piece's shape (or tracing
    // its outline, for the rete), and a warm glow bleeding round it.

    private var light: some View {
        ZStack {
            tube(OrlojMaterial.lightGlow).blur(radius: 5 * face.ui).opacity(0.9)
            tube(OrlojMaterial.lightGlow).blur(radius: 1.6 * face.ui)
            tube(OrlojMaterial.lightCore)
        }
    }

    @ViewBuilder
    private func tube(_ colour: Color) -> some View {
        if outlined {
            edges(colour, width: 1.1 * face.ui + 0.3)
        } else {
            Rectangle().fill(colour).mask { silhouette }
        }
    }
}

// MARK: - Materials
// What the moving parts are cast in. The plate is the same enamel under
// all of them; the materials differ in how a piece's outline is filled,
// edged and lifted off it — using only what a widget can draw (fills,
// gradients, masks, blur, shadows).

enum OrlojMaterial: Equatable {
    /// Hand-rolled glass: the plate seen frosted through each piece.
    case glass
    /// Satin gold — Prague's own gilt rete on its painted plate.
    case gold
    /// Spun titanium — brushed in circles round the axle.
    case titanium
    /// Cut card, layered like a shadow box.
    case paper
    /// No material: lines of light.
    case light

    /// The plate's hairlines in this material — gold and titanium wires,
    /// cloisonné-style; nil keeps the ink.
    var wire: Color? {
        switch self {
        case .gold:     return OrlojMetal.goldMid.opacity(0.75)
        case .titanium: return OrlojMetal.tiHigh.opacity(0.55)
        default:        return nil
        }
    }

    static let paperCard  = Color(.displayP3, red: 0.966, green: 0.953, blue: 0.923)   // OKLCH L .965 C .012 h  85
    static let paperShade = Color(.displayP3, red: 0.859, green: 0.843, blue: 0.806)   //       L .88  C .015 h  85
    static let paperNavy  = Color(.displayP3, red: 0.158, green: 0.219, blue: 0.331)   //       L .34  C .060 h 258
    static let lightCore  = Color(.displayP3, red: 0.995, green: 0.974, blue: 0.909)   //       L .98  C .025 h  90
    static let lightGlow  = Color(.displayP3, red: 0.919, green: 0.801, blue: 0.583)   //       L .86  C .090 h  80
}

/// A metal's palette: its body sheen, bevel ends and engraving.
struct OrlojMetal {
    let body:      AnyShapeStyle
    let highlight: Color
    let deep:      Color
    let engraved:  Color

    /// Satin gold: soft diagonal bands of sheen, lit from the top left.
    static let gold = OrlojMetal(
        body: AnyShapeStyle(LinearGradient(stops: [.init(color: goldHigh, location: 0),
                                                   .init(color: goldMid,  location: 0.30),
                                                   .init(color: goldDeep, location: 0.52),
                                                   .init(color: goldMid,  location: 0.72),
                                                   .init(color: goldHigh, location: 0.88),
                                                   .init(color: goldMid,  location: 1)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)),
        highlight: goldHigh, deep: goldDeep, engraved: goldEngraved)

    /// Spun titanium: the light caught in rings of brushing round the
    /// axle — an angular sheen, repeating, centred on `centre`.
    static func titanium(spunAround centre: UnitPoint) -> OrlojMetal {
        let sweep: [Color] = [tiHigh, tiMid, tiDeep, tiMid]
        let stops = (0..<6).flatMap { _ in sweep } + [tiHigh]
        return OrlojMetal(body: AnyShapeStyle(AngularGradient(colors: stops, center: centre)),
                          highlight: tiHigh, deep: tiDeep, engraved: tiEngraved)
    }

    static let goldHigh     = Color(.displayP3, red: 0.954, green: 0.894, blue: 0.711)   // OKLCH L .92  C .070 h  90
    static let goldMid      = Color(.displayP3, red: 0.860, green: 0.724, blue: 0.416)   //       L .80  C .120 h  84
    static let goldDeep     = Color(.displayP3, red: 0.587, green: 0.451, blue: 0.225)   //       L .58  C .100 h  76
    static let goldEngraved = Color(.displayP3, red: 0.357, green: 0.258, blue: 0.124)   //       L .40  C .070 h  70
    static let tiHigh       = Color(.displayP3, red: 0.900, green: 0.910, blue: 0.923)   //       L .93  C .006 h 250
    static let tiMid        = Color(.displayP3, red: 0.680, green: 0.696, blue: 0.716)   //       L .76  C .010 h 250
    static let tiDeep       = Color(.displayP3, red: 0.441, green: 0.459, blue: 0.481)   //       L .56  C .012 h 250
    static let tiEngraved   = Color(.displayP3, red: 0.266, green: 0.283, blue: 0.304)   //       L .40  C .012 h 250
}

// MARK: - Tinted glass

/// A badge in coloured glass: its colour run top to bottom across the
/// badge itself, a specular bloom at the top left, the rim light — so it
/// reads as glass that has colour, not paint on glass.
struct OrlojTintedGlass: View {
    let path:    Path?
    let tint:    (top: Color, bottom: Color)
    let face:    OrlojFace
    let palette: OrlojGlassPalette

    /// How much of the colour the glass carries. ▼ TWEAK ▼
    private static let density: Double = 0.88

    var body: some View {
        if let path, !palette.lineArt {
            let box = path.boundingRect
            ZStack {
                OrlojPath(source: path)
                    .fill(LinearGradient(colors: [tint.top, tint.bottom],
                                         startPoint: unit(box.midX, box.minY),
                                         endPoint:   unit(box.midX, box.maxY)))
                    .opacity(Self.density)
                OrlojPath(source: path)
                    .fill(RadialGradient(colors: [palette.ink.opacity(0.55), .clear],
                                         center: unit(box.minX + box.width * 0.32,
                                                      box.minY + box.height * 0.28),
                                         startRadius: 0, endRadius: box.width * 0.45))
                OrlojPath(source: path).stroke(palette.rim, lineWidth: 0.9)
            }
        }
    }

    /// A point on the face as a unit point of the widget.
    private func unit(_ x: CGFloat, _ y: CGFloat) -> UnitPoint {
        UnitPoint(x: x / max(face.camera.size.width,  1),
                  y: y / max(face.camera.size.height, 1))
    }
}

// MARK: - Plate

/// The plate's light: day, then each altitude field painted over the
/// last down to night — inside the crown, or filling the whole widget
/// under the Contour ring. Flat colour, crisp edges.
struct OrlojPlateLight: View {
    let face:     OrlojFace
    let palette:  OrlojGlassPalette
    var material: OrlojMaterial = .glass

    /// In paper, each field is its own sheet and lifts off the one below.
    private var layerShadow: Color { .black.opacity(material == .paper ? 0.28 : 0) }

    var body: some View {
        ZStack {
            Rectangle().fill(palette.day)
            ForEach(Array(face.unequalHourSections().enumerated()), id: \.offset) { k, section in
                OrlojPath(source: section).fill(OrlojGlassPalette.hour(k))
            }
            ForEach(face.altitudeFields(), id: \.altitude) { field in
                OrlojPath(source: field.path).fill(palette.field(below: field.altitude))
                    .shadow(color: layerShadow, radius: 3 * face.ui, y: 2 * face.ui)
            }
            // The centre is open: the widget's own ground, as if the plate
            // were cut away inside the inner tropic.
            OrlojPath(source: face.earthDiscPath()).fill(Artist.shared.canvasBackground)
                .shadow(color: layerShadow, radius: 3 * face.ui, y: 2 * face.ui)
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
    var material:   OrlojMaterial = .glass

    private var wire: Color { material.wire ?? palette.ink }

    var body: some View {
        ZStack {
            if showsHours {
                OrlojPath(source: face.unequalHoursPath())
                    .stroke(wire.opacity(material.wire == nil ? 0.14 : 0.5), lineWidth: 0.5)
            }
            // The horizon and the twilight line; the orange runs unbroken between.
            ForEach(face.altitudeFields().filter { $0.altitude.degrees.truncatingRemainder(dividingBy: 18) == 0 },
                    id: \.altitude) { field in
                OrlojPath(source: field.path)
                    .stroke(wire.opacity(field.altitude == .zero ? 0.6 : 0.18),
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
