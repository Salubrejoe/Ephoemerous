import SwiftUI
import simd

// MARK: - ClusterDetailView
// An open cluster's place card (see `PlaceSheet`): the Maps-style header,
// a Find / Constellation row, then the grid —
//
//   [        DISTANCE  (wide)        ]
//   [ RISE & SET   ][  BRIGHTNESS    ]
//   [     SIZE     ][   POSITION     ]
//   [        STARS  (wide roster)    ]
//
// The roster is the cluster's own catalogued stars inside its radius,
// brightest first, each opening its card — the Pleiades' sisters, the
// Hyades' V. No Pin yet: the favourites store only knows stars,
// constellations and the solar system.
struct ClusterDetailView: View {
    @Environment(AppState.self) var state
    let cluster: DeepSkyObject

    /// "Open cluster · M45", "Open cluster · Caldwell 41".
    private var subtitle: String { "\(cluster.kindName) · \(cluster.designation)" }

    var body: some View {
        PlaceSheet(object:   .deepSky(cluster),
                   title:    cluster.label,
                   subtitle: subtitle,
                   leading:  .share) {
            tiles
        } actions: {
            PlaceActionRow {
                FindAction()
                if let c = cluster.constellation {
                    ConstellationAction(constellation: c)
                }
            }
        }
        .navigationDestination(for: Star.self) { s in
            StarDetailView(star: s, showsBackChevron: true)
        }
        .navigationDestination(for: Constellation.self) { c in
            ConstellationDetailView(constellation: c, showsBackChevron: true)
        }
        .onAppear { state.recordViewed(.deepSky(cluster)) }
    }

    private var tiles: some View {
        let a      = Artist.shared
        let date   = state.observationDate
        let object = SkyObject.deepSky(cluster)
        let status = SkyStatus.cached(object: object, date: date, observer: state.placeObserver)
        let path   = StarDayPath(object: object, around: date, observer: state.placeObserver)
        let year   = Calendar.current.component(.year, from: date)
        let stars  = cluster.memberStars
        return VStack(spacing: a.detailGridSpacing) {
            DetailGridLayout(rows: [1, 2, 2]) {
                ClusterDistanceTile(cluster: cluster, year: year)
                RiseSetTile(status: status, path: path)
                BrightnessTile(magnitude: cluster.mag ?? 6)
                ClusterSizeTile(arcminutes: cluster.major)
                PositionTile(raHours: cluster.ra / 15, decDegrees: cluster.dec)
            }
            if !stars.isEmpty {
                ConstellationStarsTile(stars: Array(stars.prefix(12)))
            }
        }
    }
}

/// The tiles' text voices — the same set every tile file declares.
fileprivate extension Font {
    static let tileValue = Font.title.weight(.medium)
    static let tileLine  = Font.footnote
    static let tileTick  = Font.caption2
}

// MARK: - Members

extension DeepSkyObject {
    /// The catalogued stars inside the cluster's radius that have a name or
    /// a designation — the faint "HR" field stars left out — brightest
    /// first. A star in front of the cluster (Aldebaran, before the Hyades)
    /// is listed too: the catalogue can't tell it's not a member.
    var memberStars: [Star] {
        guard let major = major else { return [] }
        let c       = equatorialVector
        let cosEdge = cos(major / 2 * .pi / (180 * 60))
        return StarDatabase.shared.workableStars
            .filter { !$0.name.hasPrefix("HR ") && simd_dot($0.equatorialVector, c) >= cosEdge }
            .sorted { $0.magnitude < $1.magnitude }
    }
}

// MARK: - Distance (wide)
// The number, and the line the star cards draw — Sun on the left, light-
// years out to the right — with the cluster as a soft band at its
// distance. Its members sit on the band; a star with a distance of its
// own sits there instead, and one far off the band is named: Aldebaran,
// well in front of the Hyades it seems to lead.
struct ClusterDistanceTile: View {
    let cluster: DeepSkyObject
    /// The year the sky is drawn for — the light-travel line counts back.
    let year: Int

    var body: some View {
        DetailCard(title: String(localized: "Distance"), symbol: "ruler") {
            VStack(alignment: .leading, spacing: 6) {
                Text(cluster.distance.map { "\(Int($0.rounded()).formatted()) ly" } ?? "—")
                    .font(.tileValue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let ly = cluster.distance {
                    ClusterDistanceLine(cluster: cluster, lightYears: ly)
                        .frame(maxHeight: .infinity)
                    Text("The light you see left it around \(String(year - Int(ly.rounded()))).")
                        .font(.tileLine)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}

struct ClusterDistanceLine: View {
    let cluster:    DeepSkyObject
    let lightYears: Double

    private static let domain = (lo: log10(3.0), hi: log10(3_000.0))
    /// How far off the cluster's distance a star must be to be named as
    /// in front of it or behind it.
    private static let outlier = 0.25

    var body: some View {
        // Each star once: its own distance where we have one, else the
        // cluster's if it's a confirmed member, else left off.
        let placed: [(star: Star, ly: Double)] = cluster.memberStars.compactMap { s in
            if let own = s.distanceLY { return (s, own) }
            return cluster.isMember(s) ? (s, lightYears) : nil
        }
        Canvas { ctx, size in
            let a     = Artist.shared
            let y     = size.height * 0.55
            let inset: CGFloat = 8
            func x(_ ly: Double) -> CGFloat {
                let t = (log10(max(3, min(3_000, ly))) - Self.domain.lo) / (Self.domain.hi - Self.domain.lo)
                return inset + CGFloat(t) * (size.width - inset * 2)
            }

            var line = Path()
            line.move(to: CGPoint(x: inset, y: y))
            line.addLine(to: CGPoint(x: size.width - inset, y: y))
            ctx.stroke(line, with: .color(.white.opacity(0.25)), lineWidth: 1)
            ctx.stroke(Path(ellipseIn: CGRect(x: inset - 3.5, y: y - 3.5, width: 7, height: 7)),
                       with: .color(.white.opacity(0.6)), lineWidth: 1)
            ctx.draw(Text("Sun").font(.tileTick).foregroundStyle(.tertiary),
                     at: CGPoint(x: 0, y: y + 12), anchor: .topLeading)
            for tick in [10.0, 100, 1_000] {
                let tx = x(tick)
                var t = Path()
                t.move(to: CGPoint(x: tx, y: y - 3))
                t.addLine(to: CGPoint(x: tx, y: y + 3))
                ctx.stroke(t, with: .color(.white.opacity(0.35)), lineWidth: 1)
                let label = tick == 1_000 ? "\(tick.formatted()) ly" : tick.formatted()
                ctx.draw(Text(label).font(.tileTick).foregroundStyle(.tertiary),
                         at: CGPoint(x: tx, y: y + 12), anchor: .top)
            }

            // The stars on the cluster gather as a little swarm round its
            // point — a sunflower spiral, so a dozen at one distance still
            // read as a dozen — inside a soft patch of the cluster tint.
            let cx     = x(lightYears)
            let tint   = a.deepSkyGradient(.cluster).bottom
            let swarm  = placed.filter { abs($0.ly / lightYears - 1) <= Self.outlier }.count
            let spread: CGFloat = 2.7
            let r      = max(7, spread * CGFloat(Double(swarm).squareRoot()) + 4)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: y - r, width: 2 * r, height: 2 * r)),
                     with: .color(tint.opacity(0.25)))

            var onBand = 0
            for (s, ly) in placed {
                let off   = abs(ly / lightYears - 1) > Self.outlier
                var p     = CGPoint(x: x(ly), y: y)
                if !off {
                    let k = Double(onBand); onBand += 1
                    let turn = k * 2.39996, rad = Double(spread) * k.squareRoot()
                    p = CGPoint(x: cx + CGFloat(rad * cos(turn)), y: y + CGFloat(rad * sin(turn)))
                }
                ctx.fill(a.starPath(at: p, radius: 2.8), with: .color(s.spectralClass.color.opacity(0.85)))
                if off {
                    ctx.draw(Text(s.displayName).font(.tileTick).foregroundStyle(.secondary),
                             at: CGPoint(x: p.x, y: y - 9), anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Size (square)
// How wide it looks, measured against the full Moon — the yardstick
// everyone carries.
struct ClusterSizeTile: View {
    let arcminutes: Double?

    /// The full Moon's mean apparent diameter.
    private static let moonArcminutes = 31.1

    var body: some View {
        DetailCard(title: String(localized: "Size"), symbol: "circle.dashed") {
            VStack(alignment: .leading, spacing: 4) {
                if let am = arcminutes {
                    Text(am >= 60 ? "\((am / 60).formatted(.number.precision(.fractionLength(1))))°"
                                  : "\(Int(am.rounded()))′")
                        .font(.tileValue)
                        .monospacedDigit()
                    Spacer(minLength: 0)
                    Text(moons(am))
                        .font(.tileLine)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                } else {
                    Text("—").font(.tileValue)
                }
            }
        }
    }

    private func moons(_ am: Double) -> String {
        let n = am / Self.moonArcminutes
        if n < 0.75 { return String(localized: "Smaller than the full Moon") }
        if n < 1.5  { return String(localized: "About as wide as the full Moon") }
        return String(localized: "About \(Int(n.rounded())) full Moons across")
    }
}
