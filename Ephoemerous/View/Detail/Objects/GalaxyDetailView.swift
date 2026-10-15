import SwiftUI
import LoreKit

// MARK: - GalaxyDetailView
// A Local Group galaxy's place card (see `PlaceSheet`): the Maps-style
// header with the galaxy's own badge pinned on the sky, a Find /
// Constellation row, then the grid —
//
//   [        DISTANCE  (wide)        ]   the Local Group on one line
//   [ RISE & SET   ][  BRIGHTNESS    ]
//   [     SIZE     ][   POSITION     ]   on the sky, in full Moons
//   [        ACROSS  (wide)          ]   its true width beside the Milky Way
//   [        GALAXY  (facts)         ]   class, stars, what it orbits
//   [        LOCAL GROUP  (roster)   ]   the other five, each opening its card
//
// No Pin yet: the favourites store only knows stars, constellations and the
// solar system. All the numbers live in `GalaxyFacts`.
struct GalaxyDetailView: View {
    @Environment(AppState.self) var state
    @Environment(\.dismiss) var dismiss
    let galaxy: LocalGalaxy
    let object: DeepSkyObject
    /// `true` when pushed from another galaxy's roster — the header's
    /// leading corner becomes the way back instead of Share.
    var showsBackChevron: Bool = false

    /// "Barred spiral galaxy · M31", "Magellanic spiral galaxy · Dorado".
    private var subtitle: String {
        let place = object.isMessier ? object.id : (object.constellation?.localizedName ?? object.id)
        return "\(galaxy.kindName) · \(place)"
    }

    var body: some View {
        PlaceSheet(object:   .deepSky(object),
                   title:    object.label,
                   subtitle: subtitle,
                   leading:  showsBackChevron ? .button(.chevronBackward, { dismiss() }) : .share) {
            tiles
        } actions: {
            PlaceActionRow {
                FindAction()
                if let c = object.constellation {
                    ConstellationAction(constellation: c)
                }
            }
        }
        .navigationDestination(for: DeepSkyObject.self) { d in
            if let g = d.galaxy { GalaxyDetailView(galaxy: g, object: d, showsBackChevron: true) }
        }
        .navigationDestination(for: Constellation.self) { c in
            ConstellationDetailView(constellation: c, showsBackChevron: true)
        }
        .onAppear { state.recordViewed(.deepSky(object)) }
    }

    private var tiles: some View {
        let a      = Artist.shared
        let date   = state.observationDate
        let sky    = SkyObject.deepSky(object)
        let status = SkyStatus.cached(object: sky, date: date, observer: state.placeObserver)
        let path   = StarDayPath(object: sky, around: date, observer: state.placeObserver)
        return VStack(spacing: a.detailGridSpacing) {
            DetailGridLayout(rows: [1, 2, 2, 1]) {
                GalaxyDistanceTile(galaxy: galaxy)
                RiseSetTile(status: status, path: path)
                BrightnessTile(magnitude: object.mag ?? 6)
                ClusterSizeTile(arcminutes: object.major)
                PositionTile(raHours: object.ra / 15, decDegrees: object.dec)
                GalaxyAcrossTile(galaxy: galaxy)
            }
            FactsTile(title:  String(localized: "Galaxy"),
                      symbol: "hurricane",
                      stats:  galaxy.stats)
            GalaxyNeighboursTile(neighbours: LocalGalaxy.allCases
                .filter { $0 != galaxy }
                .sorted { $0.distanceLy < $1.distanceLy })
        }
    }
}

/// The tiles' text voices — the same set every tile file declares.
fileprivate extension Font {
    static let tileValue = Font.title.weight(.medium)
    static let tileLine  = Font.footnote
    static let tileTick  = Font.caption2
}

// MARK: - Facts

extension LocalGalaxy {
    /// The Galaxy tile's rows — only the ones it has.
    var stats: [DetailStat] {
        var rows = [DetailStat(label: String(localized: "Class"), value: morphology)]
        if let stars    { rows.append(DetailStat(label: String(localized: "Stars"),       value: stars)) }
        if let orbits   { rows.append(DetailStat(label: String(localized: "Orbits"),      value: orbits)) }
        if let standing { rows.append(DetailStat(label: String(localized: "In the Local Group"), value: standing)) }
        return rows
    }

    /// "About 1.7 times the Milky Way's width", "About a third of …".
    var widthPhrase: String {
        let r = diameterLy / Self.milkyWayDiameterLy
        if r >= 1.25 {
            return String(localized: "About \(r, format: .number.precision(.fractionLength(1))) times the Milky Way's width")
        }
        if r >= 0.85 { return String(localized: "About the Milky Way's width") }
        if r >= 0.55 { return String(localized: "About \(Int((r * 10).rounded()) * 10)% of the Milky Way's width") }
        switch Int((1 / r).rounded()) {
        case 2:  return String(localized: "About half the Milky Way's width")
        case 3:  return String(localized: "About a third of the Milky Way's width")
        case 4:  return String(localized: "About a quarter of the Milky Way's width")
        case 5:  return String(localized: "About a fifth of the Milky Way's width")
        case 6:  return String(localized: "About a sixth of the Milky Way's width")
        case 7, 8: return String(localized: "About an eighth of the Milky Way's width")
        default: return String(localized: "Under a tenth of the Milky Way's width")
        }
    }

    /// "The light you see left it 2.5 million years ago."
    var lightPhrase: String {
        distanceLy >= 1_000_000
        ? String(localized: "The light you see left it \(distanceLy / 1_000_000, format: .number.precision(.fractionLength(1))) million years ago.")
        : String(localized: "The light you see left it \(Int((distanceLy / 1_000).rounded()) * 1_000, format: .number) years ago.")
    }
}

// MARK: - Distance (wide)
// The number, then the whole Local Group on one line, to scale: the Milky
// Way at the left, the Clouds just off it, and the Andromeda family out
// past two and a half million light-years with Triangulum beyond. This
// galaxy in full, the others quieter.
struct GalaxyDistanceTile: View {
    let galaxy: LocalGalaxy

    var body: some View {
        DetailCard(title: String(localized: "Distance"), symbol: "ruler") {
            VStack(alignment: .leading, spacing: 6) {
                Text(SkyObject.lightYears(galaxy.distanceLy))
                    .font(.tileValue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                GalaxyDistanceLine(galaxy: galaxy)
                    .frame(maxHeight: .infinity)
                Text(galaxy.lightPhrase)
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct GalaxyDistanceLine: View {
    let galaxy: LocalGalaxy

    /// The line's far end, light-years — just past Triangulum.
    private static let reach: Double = 3_000_000
    /// How far a badge rides above or below the line. ▼ TWEAK ▼
    private static let lift: CGFloat = 17
    /// Badges on the line are drawn this much smaller than on the sky;
    /// this galaxy a little larger than the rest.
    private static let otherScale: CGFloat = 0.8
    private static let ownScale:   CGFloat = 1.1

    var body: some View {
        GeometryReader { geo in
            let w     = geo.size.width
            let axis  = geo.size.height * 0.42
            let inset: CGFloat = 8
            let x     = { (ly: Double) in inset + CGFloat(ly / Self.reach) * (w - inset * 2) }
            // Nearest first, alternating above and below, so the
            // Andromeda family (four within 400,000 ly) stays apart.
            let order = LocalGalaxy.allCases.sorted { $0.distanceLy < $1.distanceLy }
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    var line = Path()
                    line.move(to: CGPoint(x: inset, y: axis))
                    line.addLine(to: CGPoint(x: w - inset, y: axis))
                    ctx.stroke(line, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                    for m in 1...3 {
                        let tx = x(Double(m) * 1_000_000)
                        var tick = Path()
                        tick.move(to: CGPoint(x: tx, y: axis - 3))
                        tick.addLine(to: CGPoint(x: tx, y: axis + 3))
                        ctx.stroke(tick, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                    }
                    // The Milky Way, where we are: a small disc and bulge.
                    let mw = CGRect(x: inset - 6, y: axis - 2, width: 12, height: 4)
                    ctx.fill(Path(ellipseIn: mw), with: .color(.white.opacity(0.7)))
                    ctx.fill(Path(ellipseIn: CGRect(x: inset - 2.5, y: axis - 2.5, width: 5, height: 5)),
                             with: .color(Artist.shared.galaxyPaint(.bulge).1))
                    // Stems from the line to each badge.
                    for (i, g) in order.enumerated() {
                        let up = i % 2 == 0
                        var stem = Path()
                        stem.move(to: CGPoint(x: x(g.distanceLy), y: axis))
                        stem.addLine(to: CGPoint(x: x(g.distanceLy), y: axis + (up ? -Self.lift : Self.lift)))
                        ctx.stroke(stem, with: .color(.secondary.opacity(g == galaxy ? 0.8 : 0.35)), lineWidth: 1)
                    }
                }
                ForEach(Array(order.enumerated()), id: \.element) { i, g in
                    let own = g == galaxy
                    POILabelView(category:   g.category,
                                 text:       "",
                                 nameReveal: 0,
                                 sizeScale:  own ? Self.ownScale : Self.otherScale)
                        .opacity(own ? 1 : 0.55)
                        .position(x: x(g.distanceLy), y: axis + (i % 2 == 0 ? -Self.lift : Self.lift))
                        .zIndex(own ? 1 : 0)
                }
                Text("Milky Way")
                    .font(.tileTick)
                    .foregroundStyle(.tertiary)
                    .fixedSize()
                    .position(x: inset + 30, y: axis + Self.lift + 16)
                Text("\(3) million ly")
                    .font(.tileTick)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .fixedSize()
                    .frame(width: w - inset, alignment: .trailing)
                    .position(x: (w - inset) / 2, y: axis + Self.lift + 16)
            }
        }
    }
}

// MARK: - Across (wide)
// Its true width beside the Milky Way's, to scale — Andromeda half as wide
// again, M32 a speck — with the number and the comparison in words.
struct GalaxyAcrossTile: View {
    let galaxy: LocalGalaxy

    var body: some View {
        DetailCard(title: String(localized: "Across"), symbol: "arrow.left.and.right") {
            VStack(alignment: .leading, spacing: 6) {
                Text(SkyObject.lightYears(galaxy.diameterLy))
                    .font(.tileValue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                GeometryReader { geo in
                    // One scale for both, so they're true to each other: the
                    // ring fits the height, and so does a round galaxy;
                    // Andromeda's thin disc may run wider.
                    let h      = geo.size.height
                    let reach  = galaxy == .andromeda ? geo.size.width * 0.4 : h * 0.85
                    let perLy  = min(h / LocalGalaxy.milkyWayDiameterLy, reach / galaxy.diameterLy)
                    let milky  = LocalGalaxy.milkyWayDiameterLy * perLy
                    // A silhouette spans about 85% of its badge's frame
                    // (the casing's margin), so the frame runs that much
                    // wider for the drawn galaxy to come out true.
                    let own    = max(10, galaxy.diameterLy * perLy) / 0.85
                    let badge  = Artist.shared.poiStyle(for: galaxy.category).badgeSize
                    HStack(alignment: .center, spacing: 18) {
                        POILabelView(category:   galaxy.category,
                                     text:       "",
                                     nameReveal: 0,
                                     richDetail: own > 30,
                                     sizeScale:  own / badge)
                            .frame(width: own, height: geo.size.height)
                        // The yardstick, not the subject: a quiet ring the
                        // Milky Way's width, as the Earth is beside a planet.
                        Circle()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                            .frame(width: milky, height: milky)
                        Text("Milky Way")
                            .font(.tileTick)
                            .foregroundStyle(.tertiary)
                            .fixedSize()
                        Spacer(minLength: 0)
                    }
                    .frame(maxHeight: .infinity)
                }
                Text(galaxy.widthPhrase)
                    .font(.tileLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

// MARK: - Local Group (roster)
// The other five, nearest first, each opening its own card.
struct GalaxyNeighboursTile: View {

    let neighbours: [LocalGalaxy]

    var body: some View {
        DetailCard(title: String(localized: "Local Group"), symbol: "list.bullet") {
            VStack(spacing: 0) {
                ForEach(Array(neighbours.enumerated()), id: \.element) { i, g in
                    if let obj = g.object {
                        if i > 0 { Divider().opacity(0.4) }
                        GalaxyLink(object: obj) {
                            HStack(spacing: 12) {
                                POILabelView(category: obj.poiCategory, text: "", nameReveal: 0)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(obj.label).font(.body)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text(g.kindName).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                Text(SkyObject.lightYears(g.distanceLy))
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
}

/// Opens another galaxy's card: pushed in the iPhone sheet, swapped in
/// place in the iPad panel (which has no stack) — `StarLink`'s rule.
struct GalaxyLink<Label: View>: View {
    @Environment(AppState.self)    private var state
    @Environment(\.detailInPanel)  private var inPanel
    let object: DeepSkyObject
    @ViewBuilder let label: () -> Label

    var body: some View {
        if inPanel {
            Button { state.focus(on: .deepSky(object)) } label: { label() }
                .buttonStyle(.plain)
        } else {
            NavigationLink(value: object) { label() }
                .buttonStyle(.plain)
        }
    }
}
