import SwiftUI
import LoreKit

// MARK: - Star tiles
// The star sheet's grid (see `StarDetailView`), each tile one fact told
// with a small picture and one plain line:
//
//   [        DISTANCE  (wide)        ]
//   [ RISE & SET   ][  BRIGHTNESS    ]
//   [          TYPE  (wide)          ]
//   [  POSITION    ][ PROPER MOTION  ]
//
// The designation is the hero's subtitle ("α Persei"), not a tile.

/// Shared type scale for the tiles' big numbers and plain lines.
private extension Font {
    static let tileValue = Font.title.weight(.medium)
    static let tileLine  = Font.footnote
    static let tileTick  = Font.caption2
}

// MARK: Distance (wide)
// The star on a line out from the Sun, among its own constellation's
// stars — a constellation is not flat; Perseus's stars sit hundreds of
// light-years apart. Log scale: 3 to 3 000 ly fits every star we hold.
struct StarDistanceTile: View {

    let star: Star

    /// Tap to cycle ly → pc → AU → km. Remembered across stars, so a reader
    /// who thinks in parsecs keeps parsecs.
    @AppStorage("detail.distanceUnit") private var unit: DistanceUnit = .lightYears

    var body: some View {
        let companions = star.distanceCompanions
        DetailCard(title: String(localized: "Distance"), symbol: "ruler") {
            VStack(alignment: .leading, spacing: 6) {
                Text(star.distanceLY.map { unit.text(fromLightYears: $0) } ?? "—")
                    .font(.tileValue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                DistanceLine(star: star, companions: companions.stars)
                    .frame(maxHeight: .infinity)
                if companions.isConstellation, let span = Star.span(of: companions.stars + [star]) {
                    Text("\(star.constellation.localizedName) spans \(unit.number(fromLightYears: span.lowerBound))–\(unit.text(fromLightYears: span.upperBound))")
                        .font(.tileLine)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.snappy) { unit = unit.next }
        }
        .sensoryFeedback(.selection, trigger: unit)
        .accessibilityHint(Text("Changes the distance unit"))
    }
}

/// The distance tile's units, one tap apart.
enum DistanceUnit: String, CaseIterable {
    case lightYears, parsecs, astronomicalUnits, kilometres

    var next: DistanceUnit {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    private var perLightYear: Double {
        switch self {
        case .lightYears:        1
        case .parsecs:           1 / 3.261_563_777
        case .astronomicalUnits: 63_241.077
        case .kilometres:        9.460_730_472_580_8e12
        }
    }

    private var symbol: String {
        switch self {
        case .lightYears:        String(localized: "ly")
        case .parsecs:           String(localized: "pc")
        case .astronomicalUnits: String(localized: "AU")
        case .kilometres:        String(localized: "km")
        }
    }

    /// "510 ly", "156 pc", "3.23 × 10⁷ AU".
    func text(fromLightYears ly: Double) -> String {
        "\(number(fromLightYears: ly)) \(symbol)"
    }

    /// The number alone. Whole numbers from 10 up; one decimal below; past
    /// a million, powers of ten — a star's distance in km is 16 digits of
    /// noise otherwise.
    func number(fromLightYears ly: Double) -> String {
        let v = ly * perLightYear
        if v >= 1_000_000 {
            let exponent = Int(floor(log10(v)))
            let mantissa = v / pow(10, Double(exponent))
            return "\(mantissa.formatted(.number.precision(.fractionLength(2)))) × 10\(Self.superscript(exponent))"
        }
        return v >= 10 ? Int(v.rounded()).formatted() : v.formatted(.number.precision(.fractionLength(1)))
    }

    private static func superscript(_ n: Int) -> String {
        let digits: [Character] = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
        return String(String(n).compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }
}

/// The line itself: the Sun at the left, ticks at 10 / 100 / 1 000 ly, the
/// companions as quiet dots (nearest and farthest named), this star in its
/// own colour.
struct DistanceLine: View {

    /// The star the line is about — `nil` on a constellation's own card,
    /// where every star is a companion and none leads.
    let star:       Star?
    let companions: [Star]
    /// Zoom the line to the companions' own spread instead of running it
    /// from the Sun — a constellation's card, where the stars are the story.
    var zoomed:     Bool = false

    /// The line's reach, log light-years: 3 to 3 000 fits every star we
    /// hold; zoomed, a little past the companions' nearest and farthest.
    private var domain: (lo: Double, hi: Double) {
        let known = companions.compactMap(\.distanceLY)
        guard zoomed, let near = known.min(), let far = known.max() else {
            return (log10(3.0), log10(3_000.0))
        }
        let pad = max(0.08, (log10(far) - log10(near)) * 0.12)
        return (log10(near) - pad, log10(far) + pad)
    }

    var body: some View {
        let domain = domain
        Canvas { ctx, size in
            let a    = Artist.shared
            let y    = size.height * 0.55
            let inset: CGFloat = 8
            func x(_ ly: Double) -> CGFloat {
                let t = (max(domain.lo, min(domain.hi, log10(ly))) - domain.lo) / (domain.hi - domain.lo)
                return inset + CGFloat(t) * (size.width - inset * 2)
            }

            var line = Path()
            line.move(to: CGPoint(x: inset, y: y))
            line.addLine(to: CGPoint(x: size.width - inset, y: y))
            ctx.stroke(line, with: .color(.white.opacity(0.25)), lineWidth: 1)
            if zoomed {
                // The Sun is off the left end — say which way it lies.
                ctx.draw(Text("← Sun").font(.tileTick).foregroundStyle(.tertiary),
                         at: CGPoint(x: 0, y: y + 12), anchor: .topLeading)
            } else {
                // The line, from the Sun outward.
                ctx.stroke(Path(ellipseIn: CGRect(x: inset - 3.5, y: y - 3.5, width: 7, height: 7)),
                           with: .color(.white.opacity(0.6)), lineWidth: 1)
                ctx.draw(Text("Sun").font(.tileTick).foregroundStyle(.tertiary),
                         at: CGPoint(x: 0, y: y + 12), anchor: .topLeading)
            }

            let ticks = Self.ticks(in: domain)
            for tick in ticks {
                let tx = x(tick)
                var t = Path()
                t.move(to: CGPoint(x: tx, y: y - 3))
                t.addLine(to: CGPoint(x: tx, y: y + 3))
                ctx.stroke(t, with: .color(.white.opacity(0.35)), lineWidth: 1)
                // The line's scale is light-years whatever the unit above.
                let label = tick == ticks.last ? "\(tick.formatted()) ly" : tick.formatted()
                ctx.draw(Text(label).font(.tileTick).foregroundStyle(.tertiary),
                         at: CGPoint(x: tx, y: y + 12), anchor: .top)
            }

            // The figure-mates — quiet dots; the two ends of the spread named.
            let known = companions.compactMap { s in s.distanceLY.map { (s, $0) } }
            // Each in its own spectral colour, muted — the figure-mates are
            // stars too, just not the one you're reading about.
            for (s, ly) in known {
                ctx.fill(a.starPath(at: CGPoint(x: x(ly), y: y), radius: 2.8),
                         with: .color(s.spectralClass.color.opacity(0.75)))
            }
            let here = star?.distanceLY.map(x)
            let ends = [known.min { $0.1 < $1.1 }, known.max { $0.1 < $1.1 }].compactMap { $0 }
            for (s, ly) in ends {
                let ex = x(ly)
                guard abs(ex - (here ?? -999)) > 34 else { continue }   // don't crowd the star
                ctx.draw(Text(s.displayName).font(.tileTick).foregroundStyle(.tertiary),
                         at: CGPoint(x: ex, y: y - 9), anchor: .bottom)
            }

            // This star — its own colour, a touch bigger, a soft halo.
            if let star, let hx = here {
                let p = CGPoint(x: hx, y: y)
                ctx.fill(Path(ellipseIn: CGRect(x: hx - 10, y: y - 10, width: 20, height: 20)),
                         with: .radialGradient(Gradient(colors: [star.spectralClass.color.opacity(0.5), .clear]),
                                               center: p, startRadius: 0, endRadius: 10))
                ctx.fill(a.starPath(at: p, radius: 5), with: .color(star.spectralClass.color))
                ctx.stroke(a.starPath(at: p, radius: 5), with: .color(a.poiBadgeCasing), lineWidth: 1)
            }
        }
    }

    /// Round ticks inside the reach, light-years — 10 / 100 / 1 000 for the
    /// full line; on a zoomed one the 1-2-5 steps that fit, at most four,
    /// and never the "Sun" corner.
    private static func ticks(in domain: (lo: Double, hi: Double)) -> [Double] {
        let lo = pow(10, domain.lo), hi = pow(10, domain.hi)
        let margin = (domain.hi - domain.lo) * 0.12
        let decades = Int(floor(domain.lo)) ... Int(ceil(domain.hi))
        for steps in [[1.0], [1, 3], [1, 2, 5], [1, 1.5, 2, 3, 5, 7]].reversed() {
            let all = decades.flatMap { d in steps.map { $0 * pow(10, Double(d)) } }
                .filter { $0 > lo && $0 < hi && log10($0) - domain.lo > margin }
            if all.count <= 4, !all.isEmpty { return all }
        }
        return [10, 100, 1_000].filter { $0 > lo && $0 < hi }
    }
}

// MARK: Rise & set
// Weather's sunset tile for any star: its height across the day as a
// curve, the horizon as a line, a dot for now.
/// Shared by every place sheet — stars, Sun, Moon, planets.
struct RiseSetTile: View {

    let status:   SkyStatus?
    let path:     StarDayPath

    var body: some View {
        DetailCard(title: String(localized: "Rise & set"), symbol: "sunrise") {
            VStack(alignment: .leading, spacing: 2) {
                headline
                DayCurve(path: path)
                    .frame(maxHeight: .infinity)
                if let top = path.culmination {
                    Text("Highest \(Int((top.altitude * 180 / .pi).rounded()))° at \(top.date.formatted(date: .omitted, time: .shortened))")
                        .font(.tileLine)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    /// The next thing the star does: "Sets 18:42", or what it never does.
    @ViewBuilder
    private var headline: some View {
        switch status?.next {
        case .sets(let d):
            event(String(localized: "Sets"), d)
        case .rises(let d):
            event(String(localized: "Rises"), d)
        case .neverSets:
            Text("Never sets").font(.title3.weight(.medium))
        case .neverRises:
            Text("Never rises").font(.title3.weight(.medium))
        default:
            Text(verbatim: "—").font(.tileValue)
        }
    }

    private func event(_ verb: String, _ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verb).font(.caption).foregroundStyle(.secondary)
            Text(date.formatted(date: .omitted, time: .shortened))
                .font(.tileValue)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct DayCurve: View {

    let path: StarDayPath

    var body: some View {
        Canvas { ctx, size in
            guard let first = path.samples.first, let last = path.samples.last else { return }
            let span    = last.date.timeIntervalSince(first.date)
            let horizon = size.height * 0.6
            // Plotted as sin(altitude), not altitude: for any star that's an
            // exact cosine across the day (sin h = sin φ sin δ + cos φ cos δ
            // cos H), so every path is Weather's soft hill. True altitude
            // peaks to a CUSP for a star that passes near the zenith —
            // geometrically right, visually a glitch. Horizon and peak time
            // are unchanged; the numbers in the tile stay true degrees.
            func point(_ s: (date: Date, altitude: Double)) -> CGPoint {
                let x = CGFloat(s.date.timeIntervalSince(first.date) / span) * size.width
                let k = s.altitude >= 0 ? horizon : size.height - horizon
                return CGPoint(x: x, y: horizon - CGFloat(sin(s.altitude)) * k * 0.92)
            }

            var curve = Path()
            for (i, s) in path.samples.enumerated() {
                if i == 0 { curve.move(to: point(s)) } else { curve.addLine(to: point(s)) }
            }
            let above = CGRect(x: 0, y: 0, width: size.width, height: horizon)
            let below = CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)
            var up = ctx;   up.clip(to: Path(above))
            up.stroke(curve, with: .color(.white.opacity(0.85)), style: .init(lineWidth: 2, lineCap: .round))
            var down = ctx; down.clip(to: Path(below))
            down.stroke(curve, with: .color(.white.opacity(0.25)), style: .init(lineWidth: 2, lineCap: .round))

            var line = Path()
            line.move(to: CGPoint(x: 0, y: horizon))
            line.addLine(to: CGPoint(x: size.width, y: horizon))
            ctx.stroke(line, with: .color(.white.opacity(0.3)), lineWidth: 1)

            // Now — the window is centred on it.
            let nowAlt = path.samples.min { abs($0.date.timeIntervalSince(path.now)) < abs($1.date.timeIntervalSince(path.now)) }
            if let n = nowAlt {
                let p = point((path.now, n.altitude))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)),
                         with: .radialGradient(Gradient(colors: [.white.opacity(0.6), .clear]),
                                               center: p, startRadius: 0, endRadius: 9))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)),
                         with: .color(.white))
            }
        }
    }
}

// MARK: Brightness
// Magnitude on the eye's own scale, Sirius to the naked-eye limit — run
// further left for what outshines Sirius (Venus, Jupiter), with Sirius
// marked where it falls.
/// Shared by stars and planets.
struct BrightnessTile: View {

    let magnitude: Double

    private static let sirius    = -1.5
    private static let faintest  =  6.5     // the naked-eye limit

    var body: some View {
        DetailCard(title: String(localized: "Brightness"), symbol: "sparkle") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(magnitude.formatted(.number.precision(.fractionLength(1))))
                        .font(.tileValue)
                        .monospacedDigit()
                    Text("mag").font(.caption).foregroundStyle(.secondary)
                }
                scale
                    .frame(height: 30)
                Spacer(minLength: 0)
                Text(Star.brightnessPhrase(for: magnitude))
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var scale: some View {
        Canvas { ctx, size in
            // The knob's radius in from each end, so it never clips.
            let knob: CGFloat = 6
            let bar   = CGRect(x: 0, y: 4, width: size.width, height: 6)
            let lo    = min(Self.sirius, magnitude)
            func x(_ mag: Double) -> CGFloat {
                let t = (mag - lo) / (Self.faintest - lo)
                return knob + CGFloat(max(0, min(1, t))) * (size.width - knob * 2)
            }
            ctx.fill(Path(roundedRect: bar, cornerRadius: 3),
                     with: .linearGradient(Gradient(colors: [.white, .white.opacity(0.08)]),
                                           startPoint: CGPoint(x: bar.minX, y: 0),
                                           endPoint:   CGPoint(x: bar.maxX, y: 0)))
            // Sirius, where it isn't the left end.
            let sx = x(Self.sirius)
            if sx > knob + 1 {
                var tick = Path()
                tick.move(to: CGPoint(x: sx, y: bar.minY - 2))
                tick.addLine(to: CGPoint(x: sx, y: bar.maxY + 2))
                ctx.stroke(tick, with: .color(Artist.shared.canvasBackground), lineWidth: 1.5)
            }
            let p = CGPoint(x: x(magnitude), y: bar.midY)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)),
                     with: .color(Artist.shared.canvasBackground))
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)),
                       with: .color(.white), lineWidth: 2)
            let sirius = ctx.resolve(Text("Sirius").font(.tileTick).foregroundStyle(.tertiary))
            let half   = sirius.measure(in: size).width / 2
            ctx.draw(sirius, at: CGPoint(x: max(half, sx), y: bar.maxY + 4), anchor: .top)
            ctx.draw(Text("Eye's limit \(Self.faintest.formatted(.number.precision(.fractionLength(1))))")
                        .font(.tileTick).foregroundStyle(.tertiary),
                     at: CGPoint(x: size.width, y: bar.maxY + 4), anchor: .topTrailing)
        }
    }
}

// MARK: Type
// A pocket HR diagram: every star we know the distance of, hot to cool
// across, bright to faint down; the Sun for scale, this star in its colour.
struct StarTypeTile: View {

    let star: Star

    var body: some View {
        DetailCard(title: String(localized: "Type"), symbol: "thermometer.medium") {
            VStack(alignment: .leading, spacing: 4) {
                MiniHRDiagram(star: star)
                    .frame(maxHeight: .infinity)
                Text(star.sizeAndColour.capitalizedSentence)
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct MiniHRDiagram: View {

    /// The star to place; `nil` puts the SUN in the spotlight (its sheet).
    let star: Star?

    /// O → M, hot to cool — the classic HR abscissa.
    private static let classes: [HRClass] = [.O, .B, .A, .F, .G, .K, .M]
    /// Absolute magnitude span, brightest at the top.
    private static let top = -8.0, bottom = 12.0
    private static let sunAbsMag = 4.83

    private struct Dot { let x: Double; let y: Double; let color: Color }

    /// The catalogue's measured stars, placed once: class column + a
    /// stable in-band jitter (from RA, so it never shuffles), against
    /// absolute magnitude.
    @MainActor private static let field: [Dot] = StarDatabase.shared.workableStars.compactMap { place($0) }

    private static func place(_ s: Star) -> Dot? {
        guard let i = classes.firstIndex(of: s.spectralClass),
              let M = s.absoluteMagnitude else { return nil }
        let jitter = 0.15 + 0.7 * (s.rightAscension.degrees.truncatingRemainder(dividingBy: 7.3) / 7.3)
        return Dot(x: Double(i) + jitter, y: M, color: s.spectralClass.color)
    }

    var body: some View {
        Canvas { ctx, size in
            let a = Artist.shared
            let plot = CGRect(x: 0, y: 2, width: size.width, height: size.height - 14)
            func p(_ d: Dot) -> CGPoint {
                CGPoint(x: plot.minX + CGFloat(d.x / Double(Self.classes.count)) * plot.width,
                        y: plot.minY + CGFloat((d.y - Self.top) / (Self.bottom - Self.top)) * plot.height)
            }
            // The classic diagram's colour: hot blue on the left through
            // to cool red on the right — muted, so this star leads.
            for d in Self.field {
                let q = p(d)
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - 1, y: q.y - 1, width: 2, height: 2)),
                         with: .color(d.color.opacity(0.4)))
            }
            for (i, c) in Self.classes.enumerated() {
                ctx.draw(Text(c.rawValue).font(.tileTick).foregroundStyle(.tertiary),
                         at: CGPoint(x: plot.minX + (CGFloat(i) + 0.5) / CGFloat(Self.classes.count) * plot.width,
                                     y: size.height), anchor: .bottom)
            }
            // The Sun — a G dwarf, for scale; the subject on its own sheet.
            let sun = p(Dot(x: Double(Self.classes.firstIndex(of: .G)!) + 0.5, y: Self.sunAbsMag, color: .white))
            if star == nil {
                let gold = Artist.shared.palette.sun.bottom
                ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 10, y: sun.y - 10, width: 20, height: 20)),
                         with: .radialGradient(Gradient(colors: [gold.opacity(0.6), .clear]),
                                               center: sun, startRadius: 0, endRadius: 10))
                ctx.fill(a.starPath(at: sun, radius: 5), with: .color(gold))
                ctx.stroke(a.starPath(at: sun, radius: 5), with: .color(a.poiBadgeCasing), lineWidth: 1)
            } else {
                ctx.stroke(Path(ellipseIn: CGRect(x: sun.x - 3, y: sun.y - 3, width: 6, height: 6)),
                           with: .color(.white.opacity(0.7)), lineWidth: 1)
            }
            ctx.draw(Text("Sun").font(.tileTick).foregroundStyle(.tertiary),
                     at: CGPoint(x: sun.x + (star == nil ? 9 : 6), y: sun.y), anchor: .leading)
            // This star.
            if let star, let d = Self.place(star) {
                let q = p(d)
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - 9, y: q.y - 9, width: 18, height: 18)),
                         with: .radialGradient(Gradient(colors: [star.spectralClass.color.opacity(0.5), .clear]),
                                               center: q, startRadius: 0, endRadius: 9))
                ctx.fill(a.starPath(at: q, radius: 4.5), with: .color(star.spectralClass.color))
                ctx.stroke(a.starPath(at: q, radius: 4.5), with: .color(a.poiBadgeCasing), lineWidth: 1)
            }
        }
    }
}

// MARK: Position
// Right ascension IS measured in hours, so it gets a clock hand; declination
// is a latitude on the sky, so it gets a meridian arc.
/// Shared by every place sheet with a fixed-sky position.
struct PositionTile: View {

    /// Right ascension in hours, declination in degrees.
    let raHours:    Double
    let decDegrees: Double

    var body: some View {
        let hours = raHours
        let dec   = decDegrees
        DetailCard(title: String(localized: "Position"), symbol: "scope") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    RADial(hours: hours).frame(width: 44, height: 44)
                    DecArc(degrees: dec).frame(width: 44, height: 44)
                }
                Spacer(minLength: 0)
                coordinate(String(localized: "RA"),  Self.raText(hours))
                coordinate(String(localized: "Dec"), dec.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())) + "°")
            }
        }
    }

    private func coordinate(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value).font(.headline).monospacedDigit()
        }
    }

    private static func raText(_ hours: Double) -> String {
        let h = Int(hours), m = Int((hours - Double(h)) * 60)
        return String(format: "%dh %02dm", h, m)
    }
}

private struct RADial: View {
    let hours: Double
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 1
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                       with: .color(.white.opacity(0.3)), lineWidth: 1)
            for h in 0 ..< 24 {
                let a = Double(h) / 24 * 2 * .pi - .pi / 2
                let inner = r - (h % 6 == 0 ? 6 : 3)
                var t = Path()
                t.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner))
                t.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r))
                ctx.stroke(t, with: .color(.white.opacity(h % 6 == 0 ? 0.6 : 0.3)), lineWidth: 1)
            }
            let a = hours / 24 * 2 * .pi - .pi / 2
            var hand = Path()
            hand.move(to: c)
            hand.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r - 4), y: c.y + CGFloat(sin(a)) * (r - 4)))
            ctx.stroke(hand, with: .color(.white), style: .init(lineWidth: 2, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)), with: .color(.white))
        }
    }
}

private struct DecArc: View {
    let degrees: Double
    var body: some View {
        Canvas { ctx, size in
            // A meridian seen side-on: the celestial pole at the top, the
            // equator across the middle, the south pole at the bottom.
            let r = min(size.width, size.height) / 2 - 1
            let c = CGPoint(x: size.width / 2 - r * 0.4, y: size.height / 2)
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            ctx.stroke(arc, with: .color(.white.opacity(0.3)), lineWidth: 1)
            var equator = Path()
            equator.move(to: c)
            equator.addLine(to: CGPoint(x: c.x + r, y: c.y))
            ctx.stroke(equator, with: .color(.white.opacity(0.3)), style: .init(lineWidth: 1, dash: [2, 2]))
            let a = -degrees * .pi / 180
            let p = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            var ray = Path()
            ray.move(to: c)
            ray.addLine(to: p)
            ctx.stroke(ray, with: .color(.white), style: .init(lineWidth: 2, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(.white))
        }
    }
}

// MARK: Proper motion
// Which way the star drifts across the sky, and how slowly — in the sky's
// own convention, north up and EAST TO THE LEFT (we look up at it).
struct StarProperMotionTile: View {

    let star: Star

    var body: some View {
        let total = star.properMotionTotalMas
        DetailCard(title: String(localized: "Proper motion"), symbol: "arrow.up.right") {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Int(total.rounded()).formatted())
                        .font(.tileValue)
                        .monospacedDigit()
                    Text("mas a year").font(.caption).foregroundStyle(.secondary)
                }
                if let heading = star.driftHeading {
                    Text("Drifting \(heading)")
                        .font(.headline)
                }
                Spacer(minLength: 0)
                Text(Self.moonLine(star.yearsToCrossMoonWidth))
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    /// "Moves a full Moon's width in ~52,000 years."
    private static func moonLine(_ years: Double?) -> String {
        guard let years else { return String(localized: "No measured drift") }
        let rounded = Self.twoFigures(years)
        return String(localized: "Moves a full Moon's width in ~\(rounded.formatted()) years")
    }

    private static func twoFigures(_ v: Double) -> Int {
        guard v >= 100 else { return Int(v.rounded()) }
        let p = pow(10, floor(log10(v)) - 1)
        return Int((v / p).rounded() * p)
    }
}

private extension String {
    /// "yellow-white giant" → "Yellow-white giant".
    var capitalizedSentence: String { prefix(1).uppercased() + dropFirst() }
}
