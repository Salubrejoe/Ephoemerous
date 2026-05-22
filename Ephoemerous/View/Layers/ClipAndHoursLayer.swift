import SwiftUI


struct ClipAndHoursLayer: EGridLayer {
    let artist = EArtist.shared

    // Crown geometry (fixed screen points, independent of scale)
    private let crownWidth   : Double = 42
    private let majorTickLen : Double = 4
    private let minorTickLen : Double = 4

    func draw(in dc: inout EGraphicContext) {
        let opacity = dc.state.chromeOpacity
        guard opacity > 0.001 else { return }
        let scale = dc.state.chromeRadiusScale

        let cx     = dc.size.width  / 2 + dc.renderedOffset.y
        let cy     = dc.size.height / 2 + dc.renderedOffset.x
        let innerR = dc.renderedScale * artist.clipRadius * scale
        let outerR = innerR + crownWidth * scale
        // Fixed orientation: RA=0h at bottom, RA=12h at top. Never rotates.
        let theta: Double = -.pi / 2

        var local = dc.ctx
        local.opacity = opacity

        drawHours(cx: cx, cy: cy, innerR: innerR, outerR: outerR,
                  theta: theta, into: local, state: dc.state)
    }

    // MARK: - Major ticks and hour labels

    private func drawHours(cx: Double, cy: Double, innerR: Double, outerR: Double,
                           theta: Double, into context: GraphicsContext, state: EAppState) {
        let midR     = (innerR + outerR) / 2
        let tzOffset = TimeZone.current.secondsFromGMT(for: state.observationDate) / 3600

        for h in 0..<24 {
            let angle = theta - Double(h) * .pi / 12.0
            let lx    = cx + cos(angle) * midR
            let ly    = cy - sin(angle) * midR

            context.draw(
                Text("\((h + tzOffset + 24) % 24)")
                    .font(isCurrentHour(h, tzOffset: tzOffset) ? .title : .caption2)
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .foregroundStyle(isCurrentHour(h, tzOffset: tzOffset) ? .primary : .quaternary),
                at:     CGPoint(x: lx, y: ly),
                anchor: .center
            )
        }
    }

    private func isCurrentHour(_ hour: Int, tzOffset: Int) -> Bool {
        (Calendar.current.component(.hour, from: Date())) == (hour + tzOffset + 24) % 24
    }
}
