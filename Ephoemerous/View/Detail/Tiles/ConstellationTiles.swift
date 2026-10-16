import SwiftUI
import LoreKit
import simd

// MARK: - Constellation tiles
// The constellation card's own tiles. A constellation isn't a point — it's
// a drawing, a story and a region — so its tiles are about those: the
// figure itself (tap a star to open it), its depth, when it's up in the
// evening, its brightest star, its share of the sky, and the roster.

private extension Font {
    static let tileValue = Font.title.weight(.medium)
    static let tileLine  = Font.footnote
    static let tileTick  = Font.caption2
}

/// Opens a star from inside a constellation card: pushed onto the sheet's
/// stack (back chevron home), or — in the iPad's floating panel, which has
/// no stack — selected, so the panel becomes the star's card.
struct StarLink<Label: View>: View {
    @Environment(AppState.self)    private var state
    @Environment(\.detailInPanel)  private var inPanel
    let star: Star
    @ViewBuilder let label: () -> Label

    var body: some View {
        if inPanel {
            Button { state.focus(on: .star(star)) } label: { label() }
                .buttonStyle(.plain)
        } else {
            NavigationLink(value: star) { label() }
                .buttonStyle(.plain)
        }
    }
}

// MARK: Story (wide, its own height)
// "How did it get there?" — the curated catasterism, how the figure was
// set among the stars; the modern ones say plainly that no myth did.
struct ConstellationStoryTile: View {

    let constellation: Constellation

    var body: some View {
        DetailCard(title: String(localized: "How did it get there?"), symbol: "book") {
            if let line = ConstellationCatasterism.shared.catasterism(for: constellation) {
                Text(line)
                    .font(.callout)
                    .fontDesign(.serif)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                Text("A modern constellation, charted to fill the gaps between the ancient figures — no ancient myth set it among the stars.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Season
// When it's up in the evening (21:00), month by month, from where you stand
// — the question everyone asks of a constellation. Tap for later in the
// night: midnight, 3 am, then back to the evening.
struct ConstellationSeasonTile: View {

    let constellation: Constellation
    let year:          Int
    let month:         Int          // 1…12, now
    let observer:      SatelliteSky.Observer

    /// Hours past 9 pm the bars are drawn for. ▼ TWEAK the steps ▼
    @State private var later = 0
    private static let steps = [0, 3, 6]

    private var altitudes: [Double] {
        constellation.eveningAltitudes(year: year, later: later, from: observer)
    }

    var body: some View {
        let altitudes = altitudes
        DetailCard(title: String(localized: "Season"), symbol: "calendar") {
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.headline(altitudes))
                    .font(.title3.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                bars(altitudes).frame(maxHeight: .infinity)
                Text(hourLine)
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            let i = Self.steps.firstIndex(of: later) ?? 0
            withAnimation(.snappy) { later = Self.steps[(i + 1) % Self.steps.count] }
        }
        .sensoryFeedback(.selection, trigger: later)
        .accessibilityHint(Text("Shows later in the night"))
    }

    /// "Evenings at 9 pm", "At midnight", "Nights at 3 am".
    private var hourLine: String {
        switch later {
        case 0: return String(localized: "Evenings at 9 pm")
        case 3: return String(localized: "At midnight")
        default:
            let hour = Calendar.current.date(from: DateComponents(hour: (21 + later) % 24)) ?? .now
            return String(localized: "Nights at \(hour.formatted(.dateTime.hour()))")
        }
    }

    private static func headline(_ altitudes: [Double]) -> String {
        let best = (altitudes.indices.max { altitudes[$0] < altitudes[$1] } ?? 0) + 1
        let deg  = altitudes.map { $0 * 180 / .pi }
        if deg.allSatisfy({ $0 < 10 }) { return String(localized: "Low all year") }
        if deg.allSatisfy({ $0 > 20 }) { return String(localized: "Up all year") }
        return String(localized: "Best in \(Calendar.current.monthSymbols[best - 1])")
    }

    private func bars(_ altitudes: [Double]) -> some View {
        Canvas { ctx, size in
            let n = 12, gap: CGFloat = 3
            let w = (size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            let labelH: CGFloat = 12
            let h = size.height - labelH - 2
            let letters = Calendar.current.veryShortMonthSymbols
            for i in 0 ..< n {
                let up = max(0, sin(altitudes[i]))                       // 0 at the horizon, 1 overhead
                let barH = max(2, CGFloat(up) * h)
                let x = CGFloat(i) * (w + gap)
                let isNow = i + 1 == month
                ctx.fill(Path(roundedRect: CGRect(x: x, y: h - barH, width: w, height: barH), cornerRadius: w / 2),
                         with: .color(isNow ? .white : .white.opacity(up > 0 ? 0.4 : 0.12)))
                ctx.draw(Text(letters[i]).font(.tileTick).foregroundStyle(isNow ? .primary : .tertiary),
                         at: CGPoint(x: x + w / 2, y: size.height), anchor: .bottom)
            }
        }
    }
}

// MARK: Depth (wide)
// Its stars at their real distances on one line out from the Sun — a
// constellation is a trick of perspective, not a thing.
struct ConstellationDepthTile: View {

    let constellation: Constellation

    var body: some View {
        let stars = constellation.measuredStars
        let span  = Star.span(of: stars)
        DetailCard(title: String(localized: "Depth"), symbol: "cube.transparent") {
            VStack(alignment: .leading, spacing: 6) {
                if let span {
                    Text("\(DistanceUnit.lightYears.number(fromLightYears: span.lowerBound))–\(DistanceUnit.lightYears.text(fromLightYears: span.upperBound))")
                        .font(.tileValue)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                DistanceLine(star: nil, companions: stars, zoomed: true)
                    .frame(maxHeight: .infinity)
                Text(span.map { Self.phrase($0) } ?? String(localized: "No measured distances"))
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    /// "1,300 light-years apart."
    private static func phrase(_ span: ClosedRange<Double>) -> String {
        let apart = DistanceUnit.lightYears.number(fromLightYears: span.upperBound - span.lowerBound)
        return String(localized: "\(apart) light-years apart")
    }
}

// MARK: Brightest
struct ConstellationBrightestTile: View {

    let star: Star

    var body: some View {
        StarLink(star: star) {
            DetailCard(title: String(localized: "Brightest"), symbol: "sparkle") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 10) {
                        POILabelView(category: .followedStar(star), text: "", labelStyle: .star,
                                     nameReveal: 0, sizeScale: 2)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                    Spacer(minLength: 0)
                    Text(star.displayName)
                        .font(.title3.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Magnitude \(star.magnitude.formatted(.number.precision(.fractionLength(1))))")
                        .font(.tileLine)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: Size
// Its share of the sky, by the IAU's own boundaries: all 88 as bars,
// largest at the left, this one lit — and a few everyone knows marked
// above theirs, so the place on the chart means something.
struct ConstellationSizeTile: View {

    let constellation: Constellation

    /// The familiar ones marked on the chart, spread from big to small.
    /// ▼ TWEAK ▼
    private static let references: [Constellation] = [.UMa, .Ori, .Lyr, .Cru]

    var body: some View {
        DetailCard(title: String(localized: "Size"), symbol: "square.dashed") {
            VStack(alignment: .leading, spacing: 4) {
                if let area = constellation.areaSquareDegrees, let rank = constellation.sizeRank {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Int(area.rounded()).formatted())
                            .font(.tileValue)
                            .monospacedDigit()
                        Text("sq°").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    chart(rank).frame(height: 48)
                    Text("\((area / Constellation.wholeSkySquareDegrees * 100).formatted(.number.precision(.fractionLength(1))))% of the whole sky")
                        .font(.tileLine)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    /// 88 bars as tall as their areas, this one lit; the references' figures
    /// over their bars.
    private func chart(_ rank: Int) -> some View {
        Canvas { ctx, size in
            let areas = Constellation.areasLargestFirst
            let top   = areas.first ?? 1
            let icon: CGFloat = 14
            let barsH = size.height - icon - 4
            let w     = size.width / CGFloat(areas.count)
            func mid(_ r: Int) -> CGFloat { (CGFloat(r) - 0.5) * w }
            for (i, area) in areas.enumerated() {
                let lit = i + 1 == rank
                let h   = max(1.5, CGFloat(area / top) * barsH)
                ctx.fill(Path(CGRect(x: CGFloat(i) * w, y: size.height - h, width: max(1, w - 0.6), height: h)),
                         with: .color(lit ? .white : .white.opacity(0.22)))
            }
            // This one's bar, picked out to the top — a short one is easy
            // to lose.
            var stem = Path()
            stem.move(to: CGPoint(x: mid(rank), y: icon + 4))
            stem.addLine(to: CGPoint(x: mid(rank), y: size.height))
            ctx.stroke(stem, with: .color(.white.opacity(0.7)), lineWidth: 1)
            ctx.draw(Artist.shared.constellationFigure(constellation)
                        .resizable().renderingMode(.template),
                     in: CGRect(x: mid(rank) - icon / 2, y: 0, width: icon, height: icon))
            // The references, quieter, where they don't crowd this one.
            for ref in Self.references where ref != constellation {
                guard let r = ref.sizeRank, abs(mid(r) - mid(rank)) > icon + 2 else { continue }
                let x = min(max(mid(r), icon / 2), size.width - icon / 2)
                var g = ctx
                g.opacity = 0.45
                g.draw(Artist.shared.constellationFigure(ref).resizable().renderingMode(.template),
                       in: CGRect(x: x - icon / 2, y: 0, width: icon, height: icon))
            }
        }
        .foregroundStyle(.white)
        .accessibilityHidden(true)
    }
}

// MARK: Stars (wide, its own height)
// The roster: its brightest stars as rows, each opening its own card.
struct ConstellationStarsTile: View {

    let stars: [Star]

    var body: some View {
        DetailCard(title: String(localized: "Stars"), symbol: "list.bullet") {
            VStack(spacing: 0) {
                ForEach(Array(stars.enumerated()), id: \.element.id) { i, star in
                    if i > 0 { Divider().opacity(0.4) }
                    StarLink(star: star) {
                        HStack(spacing: 12) {
                            POILabelView(category: .followedStar(star), text: "", labelStyle: .star, nameReveal: 0)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(star.displayName).font(.body)
                                Text(star.designation).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(star.magnitude.formatted(.number.precision(.fractionLength(1))))
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                    }
                }
            }
        }
    }
}
