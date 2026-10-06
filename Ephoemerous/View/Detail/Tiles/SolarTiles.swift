import SwiftUI
import LoreKit

// MARK: - Solar-system tiles
// The Sun, Moon, planet and spacecraft sheets' own tiles, in the star
// grid's grammar (`DetailCard`): one fact, one small picture, one plain
// line. Rise & set, Brightness, Position and the HR diagram are shared with
// the stars (`StarTiles`).

private extension Font {
    static let tileValue = Font.title.weight(.medium)
    static let tileLine  = Font.footnote
    static let tileTick  = Font.caption2
}

// MARK: Distance
// How far it is today, between the nearest and farthest it ever gets — a
// planet swings from one side of the Sun to the other; the Moon from
// perigee to apogee. Tap to cycle km → AU → light-time.
struct BodyDistanceTile: View {

    /// Distance from Earth now, km.
    let currentKm: Double?
    /// The swing, km — `nil` hides the bar (a spacecraft has none).
    var range:     ClosedRange<Double>? = nil

    @AppStorage("detail.bodyDistanceUnit") private var unit: BodyDistanceUnit = .kilometres

    var body: some View {
        DetailCard(title: String(localized: "Distance"), symbol: "ruler") {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentKm.map(unit.text) ?? "—")
                    .font(.tileValue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                if let range, let now = currentKm {
                    SwingBar(range: range, now: now, unit: unit)
                        .frame(height: 34)
                }
                Spacer(minLength: 0)
                if let km = currentKm {
                    Text("Its light takes \(BodyDistanceUnit.lightTime(km)) to reach you.")
                        .font(.tileLine)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture { withAnimation(.snappy) { unit = unit.next } }
        .sensoryFeedback(.selection, trigger: unit)
        .accessibilityHint(Text("Changes the distance unit"))
    }
}

/// Nearest ←—●——→ farthest, today's distance as the dot.
private struct SwingBar: View {
    let range: ClosedRange<Double>
    let now:   Double
    let unit:  BodyDistanceUnit

    var body: some View {
        Canvas { ctx, size in
            let bar = CGRect(x: 0, y: 4, width: size.width, height: 6)
            ctx.fill(Path(roundedRect: bar, cornerRadius: 3), with: .color(.white.opacity(0.18)))
            let t = (now - range.lowerBound) / (range.upperBound - range.lowerBound)
            let x = CGFloat(max(0, min(1, t))) * size.width
            ctx.fill(Path(roundedRect: CGRect(x: 0, y: bar.minY, width: x, height: bar.height), cornerRadius: 3),
                     with: .color(.white.opacity(0.55)))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 6, y: bar.midY - 6, width: 12, height: 12)),
                     with: .color(Artist.shared.canvasBackground))
            ctx.stroke(Path(ellipseIn: CGRect(x: x - 5, y: bar.midY - 5, width: 10, height: 10)),
                       with: .color(.white), lineWidth: 2)
            // A wide tile names the ends; a square one has room for the
            // numbers alone.
            let wide = size.width > 250
            let near = unit.short(range.lowerBound), far = unit.short(range.upperBound)
            ctx.draw(Text(wide ? "Nearest \(near)" : near).font(.tileTick).foregroundStyle(.tertiary),
                     at: CGPoint(x: 0, y: bar.maxY + 4), anchor: .topLeading)
            ctx.draw(Text(wide ? "Farthest \(far)" : far).font(.tileTick).foregroundStyle(.tertiary),
                     at: CGPoint(x: size.width, y: bar.maxY + 4), anchor: .topTrailing)
        }
    }
}

/// The solar system's units, one tap apart.
enum BodyDistanceUnit: String, CaseIterable {
    case kilometres, astronomicalUnits, lightTime

    var next: BodyDistanceUnit {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// "384,000 km", "150 million km", "1.52 AU", "8 min 19 s".
    func text(_ km: Double) -> String {
        switch self {
        case .kilometres:        Self.kilometres(km)
        case .astronomicalUnits: "\(Self.threeFigures(km / BodyFacts.kmPerAU)) AU"
        case .lightTime:         Self.lightTime(km)
        }
    }

    /// The compact form for the bar's ends.
    func short(_ km: Double) -> String { text(km) }

    /// Kilometres in words past a million — "228 million km" reads, a
    /// nine-digit number doesn't.
    static func kilometres(_ km: Double) -> String {
        switch km {
        case 1e9...: String(localized: "\(threeFigures(km / 1e9)) billion km")
        case 1e6...: String(localized: "\(threeFigures(km / 1e6)) million km")
        default:     String(localized: "\(Int((km / 100).rounded() * 100).formatted()) km")
        }
    }

    /// How long light takes to cross `km`: "1.3 s", "8 min 19 s", "4 h 10 min".
    static func lightTime(_ km: Double) -> String {
        let s = km / 299_792.458
        if s < 60 { return String(localized: "\(s.formatted(.number.precision(.fractionLength(1)))) s") }
        let m = Int(s / 60), rest = Int(s.rounded()) % 60
        if m < 60 { return String(localized: "\(m) min \(rest) s") }
        return String(localized: "\(m / 60) h \(m % 60) min")
    }

    /// Three significant figures, no trailing noise.
    static func threeFigures(_ v: Double) -> String {
        guard v > 0 else { return "0" }
        let digits = max(0, 2 - Int(floor(log10(v))))
        return v.formatted(.number.precision(.fractionLength(min(digits, 4))))
    }
}

// MARK: Daylight (the Sun)
// How long the Sun is up today, with the day as a strip: the lit hours
// bright, the night dark, a tick for now.
struct DaylightTile: View {

    let path: StarDayPath

    var body: some View {
        let up = Double(path.samples.filter { $0.altitude > 0 }.count) * StarDayPath.step
        DetailCard(title: String(localized: "Daylight"), symbol: "sun.max") {
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.hours(up))
                    .font(.tileValue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                strip.frame(height: 14)
                Spacer(minLength: 0)
                Text(path.alwaysUp   ? String(localized: "The Sun doesn't set today")
                   : path.alwaysDown ? String(localized: "The Sun doesn't rise today")
                                     : String(localized: "of sunlight across this day"))
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var strip: some View {
        Canvas { ctx, size in
            let n = path.samples.count
            guard n > 1 else { return }
            let w = size.width / CGFloat(n)
            let gold = Artist.shared.palette.sun.bottom
            for (i, s) in path.samples.enumerated() {
                let a = max(0, min(1, (s.altitude * 180 / .pi + 6) / 12))   // dusk blends over twilight
                ctx.fill(Path(CGRect(x: CGFloat(i) * w, y: 0, width: w + 0.5, height: size.height)),
                         with: .color(gold.opacity(0.08 + 0.7 * a)))
            }
            var tick = Path()
            tick.move(to: CGPoint(x: size.width / 2, y: -3))
            tick.addLine(to: CGPoint(x: size.width / 2, y: size.height + 3))
            ctx.stroke(tick, with: .color(.white), lineWidth: 2)
        }
        .clipShape(.capsule)
    }

    private static func hours(_ seconds: Double) -> String {
        let m = Int((seconds / 60).rounded())
        return String(localized: "\(m / 60) h \(m % 60) min")
    }
}

// MARK: Phase (the Moon)
// Tonight's face, drawn — the lit part in the Moon's own gradient, the dark
// in black, like its badge — with its name, how much is lit, and what's
// next: full or new, whichever comes first.
struct MoonPhaseTile: View {

    let phase:    LunarPhase
    let fraction: Double
    let date:     Date

    var body: some View {
        let next = MoonPosition.nextFullAndNew(after: date)
        DetailCard(title: String(localized: "Phase"), symbol: "moonphase.waxing.crescent") {
            HStack(spacing: 18) {
                POILabelView(category: .moon, text: "", nameReveal: 0, phase: phase,
                             sizeScale: Artist.shared.moonPhaseTileScale)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.name)
                        .font(.title3.weight(.medium))
                    Text("\(Int((fraction * 100).rounded()))% lit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    ForEach(Self.upcoming(next, from: date), id: \.self) { line in
                        Text(line)
                            .font(.tileLine)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
        }
    }

    /// "Full Moon in 4 days", "New Moon in 18 days" — soonest first.
    private static func upcoming(_ next: (full: Date?, new: Date?), from date: Date) -> [String] {
        var events: [(Date, String)] = []
        if let f = next.full { events.append((f, String(localized: "Full Moon \(days(f, from: date))"))) }
        if let n = next.new  { events.append((n, String(localized: "New Moon \(days(n, from: date))"))) }
        return events.sorted { $0.0 < $1.0 }.map(\.1)
    }

    private static func days(_ d: Date, from now: Date) -> String {
        let n = Int((d.timeIntervalSince(now) / 86_400).rounded())
        switch n {
        case 0:  return String(localized: "today")
        case 1:  return String(localized: "tomorrow")
        default: return String(localized: "in \(n) days")
        }
    }
}

// MARK: Orbit (a planet)
// The planet and the Earth on their orbits round the Sun, where they are
// today — radii on a square-root scale, so Neptune's orbit and Earth's both
// fit — beside how long a lap takes and how far out it runs.
struct OrbitTile: View {

    let planet: Planet
    let facts:  BodyFacts
    let date:   Date

    var body: some View {
        DetailCard(title: String(localized: "Orbit"), symbol: "circle.dashed") {
            HStack(spacing: 16) {
                OrbitDiagram(planet: planet, date: date, a: facts.semiMajorAU ?? 1)
                    .aspectRatio(1, contentMode: .fit)
                VStack(alignment: .leading, spacing: 4) {
                    if let period = facts.periodPhrase {
                        Text(period).font(.title3.weight(.medium))
                        Text("for one lap of the Sun").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let a = facts.semiMajorAU {
                        Text("\(BodyDistanceUnit.threeFigures(a)) AU from the Sun on average")
                            .font(.tileLine)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct OrbitDiagram: View {
    let planet: Planet
    let date:   Date
    let a:      Double

    var body: some View {
        Canvas { ctx, size in
            let c    = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2 - 6
            let top  = sqrt(max(a, 1))
            func r(_ au: Double) -> CGFloat { CGFloat(sqrt(au) / top) * maxR }
            func ring(_ radius: CGFloat, _ opacity: Double) {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(.white.opacity(opacity)), lineWidth: 1)
            }
            func dot(_ lon: Double, _ radius: CGFloat, _ color: Color, _ d: CGFloat) {
                let p = CGPoint(x: c.x + radius * CGFloat(cos(lon)), y: c.y - radius * CGFloat(sin(lon)))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)), with: .color(color))
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)),
                           with: .color(Artist.shared.poiBadgeCasing), lineWidth: 1)
            }
            let gold = Artist.shared.palette.sun.bottom
            ring(r(1), 0.25)
            ring(r(a), 0.45)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(gold))
            let earth = PlanetPosition.earthHeliocentric(date: date)
            dot(earth.longitude, r(earth.radius), Color(red: 0.45, green: 0.65, blue: 1), 7)
            if let h = PlanetPosition.heliocentric(planet, date: date) {
                dot(h.longitude, r(h.radius), Artist.shared.planetGradient(planet).top, 10)
            }
        }
    }
}

// MARK: Size
// The body beside the Earth, to scale — the Sun swallows the frame, the
// Moon is a quarter of us — with its diameter.
struct SizeTile: View {

    let facts: BodyFacts
    let color: Color

    var body: some View {
        DetailCard(title: String(localized: "Size"), symbol: "circle.circle") {
            VStack(alignment: .leading, spacing: 6) {
                Text(BodyDistanceUnit.kilometres(facts.diameterKm))
                    .font(.title2.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Canvas { ctx, size in
                    let ratio = facts.diameterKm / BodyFacts.earthDiameterKm
                    let big   = min(size.height * 0.85, size.width * 0.5)
                    let body  = ratio >= 1 ? big : max(3, big * CGFloat(ratio))
                    let earth = ratio >= 1 ? max(3, big / CGFloat(ratio)) : big
                    let y = size.height / 2
                    let bx = body / 2
                    ctx.fill(Path(ellipseIn: CGRect(x: 0, y: y - body / 2, width: body, height: body)), with: .color(color))
                    let ex = bx + body / 2 + 10 + earth / 2
                    // The Earth is the yardstick, not the subject — a quiet disc.
                    ctx.fill(Path(ellipseIn: CGRect(x: ex - earth / 2, y: y - earth / 2, width: earth, height: earth)),
                             with: .color(Color(red: 0.45, green: 0.65, blue: 1).opacity(0.35)))
                    ctx.stroke(Path(ellipseIn: CGRect(x: ex - earth / 2, y: y - earth / 2, width: earth, height: earth)),
                               with: .color(Color(red: 0.45, green: 0.65, blue: 1).opacity(0.7)), lineWidth: 1)
                    ctx.draw(Text("Earth").font(.tileTick).foregroundStyle(.tertiary),
                             at: CGPoint(x: ex + earth / 2 + 4, y: y), anchor: .leading)
                }
                .frame(maxHeight: .infinity)
                Text(facts.sizePhrase)
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

// MARK: Passes (a spacecraft)
// The next times it crosses your sky lit by the Sun against a dark one —
// the only times you'll see it. Tap one to roll the sky to its peak.
struct PassesTile: View {

    let passes: [SatellitePass]
    let jump:   (SatellitePass) -> Void

    var body: some View {
        DetailCard(title: String(localized: "Visible passes"), symbol: "binoculars") {
            VStack(alignment: .leading, spacing: 10) {
                if passes.isEmpty {
                    Text("None in the next few days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(passes.prefix(3)) { pass in
                    Button { jump(pass) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(SpacecraftFacts.whenText(pass)).font(.subheadline.weight(.semibold))
                            Text(SpacecraftFacts.summaryText(pass))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: Facts (a spacecraft, right now)
// Where it is and how it's moving at this moment — label / value rows.
struct FactsTile: View {

    let title:  String
    let symbol: String
    let stats:  [DetailStat]

    var body: some View {
        DetailCard(title: title, symbol: symbol) {
            VStack(spacing: 6) {
                ForEach(stats) { stat in
                    HStack(alignment: .firstTextBaseline) {
                        Text(stat.label).font(.footnote).foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(stat.value).font(.footnote.weight(.medium)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }
}

// MARK: - Knobs
extension Artist {
    /// How large the Moon's face is drawn in its phase tile. ▼ TWEAK ▼
    var moonPhaseTileScale: CGFloat { 5.2 }
}
