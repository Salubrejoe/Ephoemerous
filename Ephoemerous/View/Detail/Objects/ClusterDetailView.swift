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

    var body: some View {
        PlaceSheet(object:   .deepSky(cluster),
                   title:    cluster.label,
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
        let stars  = cluster.memberStars
        return VStack(spacing: a.detailGridSpacing) {
            DetailGridLayout(rows: [1, 2, 2]) {
                ClusterDistanceTile(cluster: cluster)
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

extension DeepSkyObject {
    /// The stars the header picks out: the catalogued ones inside its
    /// radius that sit at its distance — a confirmed member, or a measured
    /// distance within a quarter of the cluster's. Aldebaran, well in front
    /// of the Hyades, stays in the field.
    var heroMembers: [Star] {
        guard let ly = lightYears else { return memberStars }
        return memberStars.filter { s in
            isMember(s) || s.distanceLY.map { abs($0 / ly - 1) <= 0.25 } == true
        }
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

    var body: some View {
        DetailCard(title: String(localized: "Distance"), symbol: "ruler") {
            VStack(alignment: .leading, spacing: 6) {
                Text(cluster.lightYears.map { "\(Int($0.rounded()).formatted()) ly" } ?? "—")
                    .font(.tileValue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let ly = cluster.lightYears {
                    ClusterDistanceLine(cluster: cluster, lightYears: ly)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

struct ClusterDistanceLine: View {
    let cluster:    DeepSkyObject
    let lightYears: Double

    /// How far off the cluster's distance a star must be to count as in
    /// front of it or behind it.
    private static let outlier = 0.25
    /// Neighbours from the same constellation drawn for scale — its
    /// brightest stars with a distance, and its other clusters.
    private static let neighbours = 5

    /// Something on the line: a star, or another cluster.
    private struct Mark {
        let ly:    Double
        let name:  String?
        let color: Color
        let kind:  Kind
        enum Kind { case member, star, neighbour, cluster }
    }

    /// Where the line runs, as a share of the tile's height.
    private static let axis: CGFloat = 0.55
    private static let inset: CGFloat = 8

    var body: some View {
        let marks = Self.marks(for: cluster, at: lightYears)
        // LINEAR, Sun to a little past the farthest mark — so the gap
        // between Aldebaran and the Hyades reads as the gulf it is.
        let far   = max(lightYears, marks.map(\.ly).max() ?? lightYears) * 1.12
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                line(marks: marks, far: far)
                // A named nebula sits on the line as its own badge, the way
                // a star's card draws the star.
                if let n = cluster.namedNebula {
                    POILabelView(category: n.category, text: "", nameReveal: 0, sizeScale: 1.1)
                        .position(x: Self.x(lightYears, far: far, width: geo.size.width),
                                  y: geo.size.height * Self.axis)
                }
            }
        }
    }

    private static func x(_ ly: Double, far: Double, width: CGFloat) -> CGFloat {
        inset + CGFloat(min(ly, far) / far) * (width - inset * 2)
    }

    private func line(marks: [Mark], far: Double) -> some View {
        Canvas { ctx, size in
            let a     = Artist.shared
            let y     = size.height * Self.axis
            let inset = Self.inset
            let step  = Self.tickStep(for: far)
            func x(_ ly: Double) -> CGFloat { Self.x(ly, far: far, width: size.width) }

            var line = Path()
            line.move(to: CGPoint(x: inset, y: y))
            line.addLine(to: CGPoint(x: size.width - inset, y: y))
            ctx.stroke(line, with: .color(.white.opacity(0.25)), lineWidth: 1)
            ctx.stroke(Path(ellipseIn: CGRect(x: inset - 3.5, y: y - 3.5, width: 7, height: 7)),
                       with: .color(.white.opacity(0.6)), lineWidth: 1)
            ctx.draw(Text("Sun").font(.tileTick).foregroundStyle(.tertiary),
                     at: CGPoint(x: 0, y: y + 12), anchor: .topLeading)
            var tick = step
            while tick < far {
                let tx = x(tick)
                var t = Path()
                t.move(to: CGPoint(x: tx, y: y - 3))
                t.addLine(to: CGPoint(x: tx, y: y + 3))
                ctx.stroke(t, with: .color(.white.opacity(0.35)), lineWidth: 1)
                let last = tick + step >= far
                ctx.draw(Text(last ? "\(Int(tick).formatted()) ly" : Int(tick).formatted())
                            .font(.tileTick).foregroundStyle(.tertiary),
                         at: CGPoint(x: tx, y: y + 12), anchor: .top)
                tick += step
            }

            // This cluster: a soft patch, its members a little swarm in it
            // (a sunflower spiral — a dozen at one distance still read as a
            // dozen). A nebula's patch is in its own glow.
            let cx     = x(lightYears)
            let tint   = cluster.namedNebula.map { a.nebulaPaint(a.nebulaMainPaint($0)).1 }
                         ?? a.deepSkyGradient(.cluster).bottom
            let swarm  = marks.filter { $0.kind == .member }.count
            let spread: CGFloat = 2.7
            let r      = max(7, spread * CGFloat(Double(swarm).squareRoot()) + 4)
            if cluster.namedNebula == nil {
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: y - r, width: 2 * r, height: 2 * r)),
                         with: .color(tint.opacity(0.25)))
            }

            var onBand = 0
            // Label room taken, as spans along the line — the cluster's own
            // patch first, so nothing is named on top of it.
            var taken: [ClosedRange<CGFloat>] = [(cx - r)...(cx + r)]
            for m in marks {
                var p = CGPoint(x: x(m.ly), y: y)
                switch m.kind {
                case .member:
                    let k = Double(onBand); onBand += 1
                    let turn = k * 2.39996, rad = Double(spread) * k.squareRoot()
                    p = CGPoint(x: cx + CGFloat(rad * cos(turn)), y: y + CGFloat(rad * sin(turn)))
                    ctx.fill(a.starPath(at: p, radius: 2.8), with: .color(m.color.opacity(0.85)))
                case .star:
                    ctx.fill(a.starPath(at: p, radius: 2.8), with: .color(m.color.opacity(0.85)))
                case .neighbour:
                    ctx.fill(a.starPath(at: p, radius: 2.2), with: .color(m.color.opacity(0.45)))
                case .cluster:
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: y - 5, width: 10, height: 10)),
                             with: .color(tint.opacity(0.22)))
                }
                // Names where there's room — measured, never on top of
                // another, and kept inside the tile (Vega at the far left).
                if let name = m.name {
                    let label = ctx.resolve(Text(name).font(.tileTick)
                                    .foregroundStyle(m.kind == .star ? .secondary : .tertiary))
                    let w     = label.measure(in: size).width
                    let mid   = min(max(p.x, w / 2), size.width - w / 2)
                    let span  = (mid - w / 2 - 4)...(mid + w / 2 + 4)
                    if !taken.contains(where: { $0.overlaps(span) }) {
                        taken.append(span)
                        ctx.draw(label, at: CGPoint(x: mid, y: y - 9), anchor: .bottom)
                    }
                }
            }
        }
    }

    /// Everything the line shows, nearest first.
    private static func marks(for cluster: DeepSkyObject, at ly: Double) -> [Mark] {
        var marks: [Mark] = []
        var used  = Set<String>()
        // Its own stars: a measured distance where we have one, else the
        // cluster's if it's a confirmed member, else left off.
        for s in cluster.memberStars {
            if let own = s.distanceLY {
                let off = abs(own / ly - 1) > outlier
                marks.append(Mark(ly: own, name: off ? s.displayName : nil,
                                  color: s.spectralClass.color, kind: off ? .star : .member))
            } else if cluster.isMember(s) {
                marks.append(Mark(ly: ly, name: nil, color: s.spectralClass.color, kind: .member))
            } else { continue }
            used.insert(s.id)
        }
        // Neighbours for scale: the constellation's brightest stars with a
        // distance, and its other clusters on the sky — nothing past a few
        // times the cluster's own distance, so the line stays about it.
        if let c = cluster.constellation {
            let stars = c.catalogueStars
                .filter { !used.contains($0.id) && $0.distanceLY != nil && $0.distanceLY! <= ly * 2.5 }
                .prefix(neighbours)
            for s in stars {
                marks.append(Mark(ly: s.distanceLY!, name: s.displayName,
                                  color: s.spectralClass.color, kind: .neighbour))
            }
            for other in DeepSkyCatalog.objects
            where other.isShownCluster && other.id != cluster.id && other.constellation == c {
                if let d = other.distance, d <= ly * 2.5 {
                    marks.append(Mark(ly: d, name: other.label, color: .clear, kind: .cluster))
                }
            }
        }
        // Clusters and named outliers first, so they win the label slots.
        return marks.sorted { rank($0.kind) < rank($1.kind) }
    }

    private static func rank(_ k: Mark.Kind) -> Int {
        switch k { case .star: 0; case .cluster: 1; case .neighbour: 2; case .member: 3 }
    }

    /// A round tick spacing giving three to five ticks.
    private static func tickStep(for far: Double) -> Double {
        for step in [10.0, 20, 25, 50, 100, 200, 250, 500, 1_000] where far / step <= 5 { return step }
        return 2_000
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
