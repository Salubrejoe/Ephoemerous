import SwiftUI
import Charts

// MARK: - HRDiagramView
// Hertzsprung–Russell diagram of the catalogue, full-screen and fully
// self-contained: pulls every star with a known distance from
// `StarKnownData`, computes absolute magnitudes, and scatters them by
// spectral class (hot O left → cool M right) against luminosity
// (bright at the top — the classic reversed-magnitude axis). The Sun
// anchors the main sequence; the famous giants and dwarfs are
// captioned so the shape of the diagram tells its own story.
//
// Data note: the catalogue stores one-letter spectral classes, so the
// x-axis is seven class bands; each star spreads inside its band with
// a deterministic jitter derived from its RA — stable across opens,
// no two neighbours stacked.
struct HRDiagramView: View {

    @Environment(\.dismiss)     private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Zoomed-out reading: the scatter collapses into one bar per
    /// spectral class spanning its brightest → faintest star, so the
    /// main sequence's drift (hot classes bright, cool classes faint)
    /// reads at a glance. Toggled by pinching the chart (out = group,
    /// in = scatter) or the header button.
    @State private var grouped = false

    // MARK: Data

    private struct HRPoint: Identifiable {
        let id:     String
        let name:   String      // display name, for the famous captions
        let xClass: Double      // class index + in-band jitter
        let absMag: Double
        let cls:    HRClass
        let isSun:  Bool
    }

    /// O → M, hot to cool — the classic HR abscissa.
    private static let classOrder: [HRClass] = [.O, .B, .A, .F, .G, .K, .M]

    /// Household names worth a caption, spread across the diagram —
    /// supergiants top-right, white main-sequence anchors, the pole star.
    private static let famous: Set<String> = [
        "Sirius", "Betelgeuse", "Rigel", "Vega",
        "Polaris", "Aldebaran", "Antares", "Deneb",
    ]

    private let points: [HRPoint] = Self.makePoints()

    /// Per-class magnitude distribution for the grouped (zoomed-out)
    /// reading — a box plot: full min→max whisker, interquartile body,
    /// median tick. The medians stagger down the diagonal even where
    /// giants stretch a class's full range — the main sequence,
    /// distilled.
    private struct ClassRange: Identifiable {
        let id:     String
        let index:  Double      // class column centre
        let cls:    HRClass
        let minMag: Double      // brightest (most negative)
        let maxMag: Double      // faintest
        let q1:     Double      // bright quartile
        let median: Double
        let q3:     Double      // faint quartile
        let count:  Int
    }

    private var classRanges: [ClassRange] {
        Self.classOrder.enumerated().compactMap { i, cls in
            let mags = points.filter { $0.cls == cls && !$0.isSun }
                .map(\.absMag).sorted()
            guard let lo = mags.first, let hi = mags.last else { return nil }
            return ClassRange(id:     cls.rawValue,
                              index:  Double(i),
                              cls:    cls,
                              minMag: lo,
                              maxMag: hi,
                              q1:     Self.quantile(mags, 0.25),
                              median: Self.quantile(mags, 0.50),
                              q3:     Self.quantile(mags, 0.75),
                              count:  mags.count)
        }
    }

    /// Linear-interpolated quantile of an already-sorted array.
    private static func quantile(_ sorted: [Double], _ p: Double) -> Double {
        guard sorted.count > 1 else { return sorted.first ?? 0 }
        let pos  = p * Double(sorted.count - 1)
        let i    = Int(pos)
        let frac = pos - Double(i)
        guard i + 1 < sorted.count else { return sorted[i] }
        return sorted[i] * (1 - frac) + sorted[i + 1] * frac
    }

    // MARK: Textbook regions

    /// The classic HR geography, hardcoded — these soft bands under the
    /// data are what make the diagram instantly recognisable. Each is a
    /// polyline of (class-index, bright-edge, faint-edge) samples,
    /// smoothed by catmull-rom. Values are the standard luminosity-class
    /// loci (V main sequence, III giants, I supergiants, D white dwarfs).
    /// The white-dwarf corner stays empty of points — honestly so: at
    /// M ≈ +11 they're far too faint for a bright-star catalogue.
    private struct HRRegion: Identifiable {
        let id:         String
        let label:      LocalizedStringResource
        let labelX:     Double
        let labelY:     Double
        let labelAngle: Double                       // degrees, screen CW
        let band:       [(x: Double, lo: Double, hi: Double)]
    }

    private static let regions: [HRRegion] = [
        .init(id:         "main",
              label:      "MAIN SEQUENCE",
              labelX:     1.9, labelY: 2.6, labelAngle: 42,
              band: [(-0.5, -8.0, -4.6), (0, -7.2, -4.0), (1, -3.6, -0.4),
                     (2, -0.5,  3.0),    (3,  1.8,  5.0), (4,  3.4,  6.6),
                     (5,  5.2,  8.8),    (6,  8.8, 13.2), (6.6, 11.0, 15.5)]),
        .init(id:         "giants",
              label:      "GIANTS",
              labelX:     5.6, labelY: 2.0, labelAngle: 0,
              band: [(3.6, 0.6, 1.6), (4.2, -0.6, 2.4), (5, -1.2, 2.6),
                     (6, -1.0, 2.2),  (6.6, -0.8, 1.6)]),
        .init(id:         "supergiants",
              label:      "SUPERGIANTS",
              labelX:     4.6, labelY: -7.6, labelAngle: 0,
              band: [(-0.2, -7.6, -5.2), (2, -8.2, -4.8),
                     (4, -8.4, -4.8),    (6.6, -8.2, -4.6)]),
        .init(id:         "dwarfs",
              label:      "WHITE DWARFS",
              labelX:     2.2, labelY: 13.4, labelAngle: 0,
              band: [(0.6, 9.2, 11.4), (1.6, 8.6, 12.6),
                     (2.8, 9.0, 12.8), (3.6, 9.8, 12.2)]),
    ]

    private static func makePoints() -> [HRPoint] {
        var pts: [HRPoint] = StarDatabase.shared.listableStars.compactMap { star in
            guard let ly = star.distanceLY, ly > 0,
                  let i  = classOrder.firstIndex(of: star.spectralClass)
            else { return nil }
            // M = m − 5·(log₁₀ d[pc] − 1)
            let parsec = ly / 3.26156
            let absMag = star.magnitude - 5 * (log10(parsec) - 1)
            // Deterministic in-band jitter from the star's RA, so the
            // seven class columns read as a scatter, not bar codes.
            let frac = (star.rightAscension.degrees * 0.731)
                .truncatingRemainder(dividingBy: 1)
            return HRPoint(id:     star.name,
                           name:   star.displayName,
                           xClass: Double(i) + (frac - 0.5) * 0.72,
                           absMag: absMag,
                           cls:    star.spectralClass,
                           isSun:  false)
        }
        // The Sun — G2, M = 4.83 — the point the whole diagram pivots on.
        pts.append(HRPoint(id:     "sun",
                           name:   SkyObject.sun.displayName,
                           xClass: 4.0,
                           absMag: 4.83,
                           cls:    .G,
                           isSun:  true))
        return pts
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Artist.shared.canvasBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 4) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                chart
                    .padding(.horizontal, 16)
                    .padding(.vertical,   20)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Hertzsprung–Russell")
                    .font(.title2.weight(.bold))
                    .fontDesign(.serif)
                Text("Stars by colour and luminosity")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Scatter ⇄ grouped toggle — shows the mode you'd switch TO.
            // The pinch on the chart drives the same flag.
            Button {
                withAnimation(.snappy(duration: 0.35)) { grouped.toggle() }
            } label: {
                Image(systemName: grouped ? "chart.dots.scatter" : "chart.bar.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Chart

    private var chart: some View {
        Chart {
            // Textbook geography first, under everything.
            ForEach(Self.regions) { region in
                ForEach(region.band, id: \.x) { seg in
                    AreaMark(
                        x:      .value("Class", seg.x),
                        yStart: .value("lo",    seg.lo),
                        yEnd:   .value("hi",    seg.hi),
                        series: .value("Region", region.id)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.primary.opacity(0.055))
                }
                PointMark(
                    x: .value("Class", region.labelX),
                    y: .value("M",     region.labelY)
                )
                .symbolSize(0)
                .annotation(position: .overlay) {
                    Text(region.label)
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(region.labelAngle))
                }
            }

            if grouped {
                // Zoomed out: a box plot per class. Thin whisker over the
                // full brightest→faintest span, interquartile body, and a
                // solid median tick — the ticks stair-step down O→M even
                // where giants stretch a class's whisker, which is the
                // main sequence's slope, distilled.
                ForEach(classRanges) { r in
                    let tint = r.cls.adaptiveColor(for: colorScheme)
                    // Whisker: full range, quiet.
                    BarMark(
                        x:      .value("Class",     r.index),
                        yStart: .value("Brightest", r.minMag),
                        yEnd:   .value("Faintest",  r.maxMag),
                        width:  .fixed(3)
                    )
                    .foregroundStyle(tint.opacity(0.30))
                    .cornerRadius(1.5)
                    .annotation(position: .top, spacing: 4) {
                        // Reversed axis → "top" is the BRIGHT end.
                        Text(verbatim: "\(r.count)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    // Body: the interquartile half of the class.
                    BarMark(
                        x:      .value("Class", r.index),
                        yStart: .value("Q1",    r.q1),
                        yEnd:   .value("Q3",    r.q3),
                        width:  .fixed(26)
                    )
                    .foregroundStyle(tint.opacity(0.55))
                    .cornerRadius(13)
                    // Median tick: where the class typically lives.
                    RectangleMark(
                        x:      .value("Class",  r.index),
                        y:      .value("Median", r.median),
                        width:  .fixed(26),
                        height: .fixed(3)
                    )
                    .foregroundStyle(tint)
                    .cornerRadius(1.5)
                }
            }
            ForEach(grouped ? points.filter(\.isSun) : points) { p in
                if p.isSun || Self.famous.contains(p.name) {
                    mark(p)
                        .annotation(position: p.xClass > 5.6 ? .leading : .trailing,
                                    spacing: 5) {
                            Text(p.name)
                                .font(.caption2)
                                .fontDesign(.serif)        // sky-object name → serif
                                .foregroundStyle(p.isSun ? .primary : .secondary)
                        }
                } else {
                    mark(p)
                }
            }
        }
        // Pinch: out (shrink) collapses to the grouped bars, in returns
        // to the scatter — same flag the header toggle drives.
        .gesture(
            MagnifyGesture()
                .onEnded { value in
                    withAnimation(.snappy(duration: 0.35)) {
                        if      value.magnification < 0.85 { grouped = true  }
                        else if value.magnification > 1.15 { grouped = false }
                    }
                }
        )
        .chartXScale(domain: -0.7...6.7)
        // Fixed, descending domain (an array keeps the order, which is how
        // Charts does a reversed axis): astronomers put BRIGHT (negative M)
        // at the top, and the full −10…+15 textbook span is what gives the
        // regions their iconic geography — including the empty white-dwarf
        // corner the catalogue can't reach.
        .chartYScale(domain: [16.5, -11.0])
        .chartXAxis {
            AxisMarks(values: (0...6).map(Double.init)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel(anchor: .top) {
                    if let v = value.as(Double.self) {
                        let cls = Self.classOrder[Int(v)]
                        Text(cls.rawValue)
                            .font(.callout.weight(.bold))
                            .fontDesign(.serif)
                            .foregroundStyle(cls.adaptiveColor(for: colorScheme))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading,
                      values: [-10.0, -5, 0, 5, 10, 15]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            axisCaption("SPECTRAL CLASS")
        }
        .chartYAxisLabel(position: .leading, alignment: .center) {
            axisCaption("ABSOLUTE MAGNITUDE")
        }
    }

    private func mark(_ p: HRPoint) -> some ChartContent {
        PointMark(
            x: .value("Class", p.xClass),
            y: .value("M",     p.absMag)
        )
        .foregroundStyle(
            p.cls.adaptiveColor(for: colorScheme)
                .opacity(p.isSun ? 1 : 0.8)
        )
        .symbolSize(p.isSun ? 28 : symbolArea(p.absMag))
    }

    /// Marker area from luminosity — brighter stars draw bigger, the
    /// same magnitude-to-size language the canvas speaks. (symbolSize is
    /// an AREA: these are ¼ the original values, i.e. half the radius —
    /// right for the ~460-star population.)
    private func symbolArea(_ absMag: Double) -> CGFloat {
        CGFloat(max(3.5, (15 - absMag) * 2.25))
    }

    private func axisCaption(_ key: LocalizedStringResource) -> some View {
        Text(key)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HRDiagramView()
}

#Preview("Dark") {
    HRDiagramView()
        .preferredColorScheme(.dark)
}
#endif
