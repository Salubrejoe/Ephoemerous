import SwiftUI

// MARK: - DetailCard
// One tile of the detail grid, in the Weather app's grammar: a small icon
// and a caps title up top, then the tile's own picture and words. Frosted
// material over the night the sheet sits on, so the sky reads through it.
//
// And Weather's scroll, in two beats:
//   1. STICK — as the tile reaches the top of the scroll area its title
//      pins there; the frosted card shrinks up into it from its top edge
//      and the content slips away beneath the title.
//   2. RECEDE — once the card is down to its title band, the band carries
//      on up and sinks away down the z-axis: shrinking back and fading as
//      a whole. Never sliced — the host lets it leave the scroll area
//      (`scrollClipDisabled`) so it dissolves over the header's sky.
//
// The grid is geometric: every tile is a square, or two squares wide.
struct DetailCard<Content: View>: View {

    let title:  String
    let symbol: String
    @ViewBuilder let content: () -> Content

    /// How far the tile's top has slid above the scroll area's top edge,
    /// and its full height — read off the scroll view each frame.
    @State private var scrolled: CGFloat = 0
    @State private var height:   CGFloat = 0

    var body: some View {
        let a      = Artist.shared
        let pad    = a.detailCardPadding
        let shelf  = pad + a.detailCardTitleHeight + 8      // title band, padding included
        // 1 · The title rides down with the scroll, but never past the point
        //     where the card is only its title band.
        let pin    = min(scrolled, max(0, height - shelf))
        // 2 · Then the band leaves: 0 → 1 across one more band's height.
        let leave  = height > 0 ? min(1, max(0, (scrolled - (height - shelf)) / shelf)) : 0

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: a.detailCardRadius)
                .fill(.ultraThinMaterial)
                .opacity(a.detailCardMaterialOpacity)
                .overlay {
                    RoundedRectangle(cornerRadius: a.detailCardRadius)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                }
                .padding(.top, pin)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, shelf)
                .padding([.horizontal, .bottom], pad)
                // Whatever has slid up under the pinned title is gone.
                .mask(alignment: .top) {
                    Rectangle().padding(.top, pin + shelf)
                }

            Label(title.uppercased(), systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                // One fixed height, so every tile's title sits on one line
                // whatever its icon's own height.
                .frame(height: a.detailCardTitleHeight, alignment: .leading)
                .padding([.top, .horizontal], pad)
                .offset(y: pin)
        }
        // The band sinks away: shrinking about its own centre, fading out.
        .scaleEffect(1 - leave * a.detailCardRecedeScale,
                     anchor: UnitPoint(x: 0.5, y: height > 0 ? (pin + shelf / 2) / height : 0.5))
        .opacity(1 - leave)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .scrollView) } action: { frame in
            scrolled = max(0, -frame.minY)
            height   = frame.height
        }
    }
}

// MARK: - DetailGridLayout
// The grid: rows of one wide tile or two squares, every row exactly as tall
// as a square is wide — so it stays a grid at any width (the phone sheet,
// the iPad panel). `rows` lists how many tiles each row holds, in order.
struct DetailGridLayout: Layout {

    var rows:    [Int]
    var spacing: CGFloat = Artist.shared.detailGridSpacing

    private func side(_ width: CGFloat) -> CGFloat { (width - spacing) / 2 }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 370
        let n     = CGFloat(rows.count)
        return CGSize(width: width, height: n * side(width) + max(0, n - 1) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let s = side(bounds.width)
        var index = 0
        var y = bounds.minY
        for count in rows {
            let w = count == 1 ? bounds.width : s
            for column in 0 ..< count where index < subviews.count {
                let x = bounds.minX + CGFloat(column) * (s + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                      proposal: ProposedViewSize(width: w, height: s))
                index += 1
            }
            y += s + spacing
        }
    }
}

// MARK: - DetailBackdrop
// The sky behind a raised detail sheet — the SAME night as the map (the
// app's one sky colour, `canvasBackground`, deepening down the sheet), with
// a sprinkle of faint fixed stars so the frosted tiles have something to
// frost. The sheet is a window onto that sky, so no colour of its own.
// The host fades it in as the sheet rises (`detailSheetExpansion`): low,
// the sheet is plain glass over the map; full screen, it's the night.
struct DetailBackdrop: View {

    var body: some View {
        let a = Artist.shared
        ZStack {
            LinearGradient(colors: [a.detailBackdropTop, a.detailBackdropBottom],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                // A fixed scatter — the same every open, never a flicker.
                var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
                func next() -> Double {
                    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    return Double(seed >> 11) / Double(1 << 53)
                }
                for _ in 0 ..< a.detailBackdropStarCount {
                    let p = CGPoint(x: next() * size.width, y: next() * size.height)
                    let m = next()
                    a.drawFieldStar(ctx, at: p, magnitude: 3 + m * 3, named: false,
                                    scale: 90, aboveHorizon: false)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Knobs
extension Artist {
    /// ▼ TWEAK the detail grid ▼
    var detailGridSpacing:      CGFloat { 12 }
    var detailCardRadius:       CGFloat { 24 }
    var detailCardPadding:      CGFloat { 14 }
    /// The title band's own height (the caption line).
    var detailCardTitleHeight:  CGFloat { 16 }
    /// How much of the frosted material shows — lower is more glass, more
    /// sky through it. ▼ TWEAK ▼
    var detailCardMaterialOpacity: Double { 0.5 }
    /// How far a leaving tile shrinks back as it fades. ▼ TWEAK ▼
    var detailCardRecedeScale:  CGFloat { 0.2 }
    var detailBackdropStarCount: Int    { 140 }
    /// The map's own sky at the top, deepening down the sheet.
    var detailBackdropTop:      Color   { canvasBackground }
    var detailBackdropBottom:   Color   { canvasBackground.mix(with: .black, by: 0.35) }
}
