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
// "How did it get there?" — the catasterism, retold on-device in a chosen
// voice where Apple Intelligence runs, or the curated line verbatim.
struct ConstellationStoryTile: View {

    let constellation: Constellation
    @State private var storyteller = MythStoryteller()
    @State private var tone: MythStoryteller.Tone = .cosy

    var body: some View {
        DetailCard(title: String(localized: "How did it get there?"), symbol: "book") {
            VStack(alignment: .leading, spacing: 12) {
                if MythStoryteller.isAvailable {
                    Picker("Tone", selection: $tone) {
                        ForEach(MythStoryteller.Tone.allCases) { t in Text(t.label).tag(t) }
                    }
                    .pickerStyle(.segmented)
                    told
                        .task(id: tone) { storyteller.tell(constellation, tone: tone) }
                } else {
                    curated
                }
            }
        }
    }

    @ViewBuilder
    private var told: some View {
        switch storyteller.phase {
        case .idle, .generating:
            HStack(spacing: 10) {
                ProgressView()
                Text("Just a sec…").font(.callout).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        case .ready, .fallback:
            if storyteller.text.isEmpty { curated } else { prose(storyteller.text) }
        }
    }

    @ViewBuilder
    private var curated: some View {
        if let line = ConstellationCatasterism.shared.catasterism(for: constellation) {
            prose(line)
        } else {
            Text("A modern constellation, charted to fill the gaps between the ancient figures — no ancient myth set it among the stars.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func prose(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .fontDesign(.serif)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}

// MARK: Season
// When it's up in the evening (21:00), month by month, from where you stand
// — the question everyone asks of a constellation.
struct ConstellationSeasonTile: View {

    /// One altitude per month, radians.
    let altitudes: [Double]
    let month:     Int          // 1…12, now

    private var best: Int { (altitudes.indices.max { altitudes[$0] < altitudes[$1] } ?? 0) + 1 }

    var body: some View {
        DetailCard(title: String(localized: "Season"), symbol: "calendar") {
            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.title3.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                bars.frame(maxHeight: .infinity)
                Text("Evenings at 9 pm")
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var headline: String {
        let deg = altitudes.map { $0 * 180 / .pi }
        if deg.allSatisfy({ $0 < 10 }) { return String(localized: "Low all year") }
        if deg.allSatisfy({ $0 > 20 }) { return String(localized: "Up all year") }
        return String(localized: "Best in \(Calendar.current.monthSymbols[best - 1])")
    }

    private var bars: some View {
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
                DistanceLine(star: nil, companions: stars)
                    .frame(maxHeight: .infinity)
                Text(span.map { Self.phrase($0) } ?? String(localized: "No measured distances"))
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    /// "Neighbours on the sky, 1,300 light-years apart in depth."
    private static func phrase(_ span: ClosedRange<Double>) -> String {
        let apart = DistanceUnit.lightYears.number(fromLightYears: span.upperBound - span.lowerBound)
        return String(localized: "Neighbours on the sky, \(apart) light-years apart in depth.")
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
// Its share of the sky, by the IAU's own boundaries, and its rank of 88.
struct ConstellationSizeTile: View {

    let constellation: Constellation

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
                    Text(Self.rankText(rank))
                        .font(.headline)
                    Spacer(minLength: 0)
                    rankBar(rank).frame(height: 8)
                    Text("\((area / Constellation.wholeSkySquareDegrees * 100).formatted(.number.precision(.fractionLength(1))))% of the whole sky")
                        .font(.tileLine)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    private static func rankText(_ rank: Int) -> String {
        switch rank {
        case 1:  String(localized: "The largest of 88")
        case 88: String(localized: "The smallest of 88")
        default: String(localized: "\(rank.formatted(.number)) of 88 by size")
        }
    }

    /// 88 ticks, largest at the left; this one lit.
    private func rankBar(_ rank: Int) -> some View {
        Canvas { ctx, size in
            let w = size.width / 88
            for i in 0 ..< 88 {
                let lit = i + 1 == rank
                ctx.fill(Path(CGRect(x: CGFloat(i) * w, y: lit ? 0 : 2, width: max(1, w - 1), height: lit ? size.height : size.height - 4)),
                         with: .color(lit ? .white : .white.opacity(0.2)))
            }
        }
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
