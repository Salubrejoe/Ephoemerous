import SwiftUI


struct ENSWatchCrownLayer: EGridLayer {

    // Clip boundary: dec = -30° → r = 2√3 in NS projection units
    static let clipRadius: Double = 2 * sqrt(3)

    // Crown geometry (fixed screen points, independent of scale)
    private let crownWidth   : Double = 27
    private let majorTickLen : Double = 4
    private let minorTickLen : Double = 4

    func draw(in dc: inout EGraphicContext) {
        let cx     = dc.size.width  / 2 + dc.state.offset.y
        let cy     = dc.size.height / 2 + dc.state.offset.x
        let innerR = dc.state.scale * Self.clipRadius
        let outerR = innerR + crownWidth
        // Fixed orientation: RA=0h at bottom, RA=12h at top. Never rotates.
        let θ: Double = -.pi / 2

//        drawRing    (cx: cx, cy: cy, innerR: innerR, outerR: outerR, in: &dc)
        drawBorders (cx: cx, cy: cy, innerR: innerR, outerR: outerR, in: &dc)
//        drawMinorTicks(cx: cx, cy: cy, innerR: innerR, θ: θ, in: &dc)
        drawHours   (cx: cx, cy: cy, innerR: innerR, outerR: outerR, θ: θ, in: &dc)
    }

    // MARK: - Ring background (even-odd fill punches the inner hole)

    private func drawRing(cx: Double, cy: Double, innerR: Double, outerR: Double,
                          in dc: inout EGraphicContext) {
        var path = Path()
        path.addEllipse(
            in: CGRect(
                x: cx - outerR,
                y: cy - outerR,
                width: 2 * outerR,
                height: 2 * outerR
            )
        )
        path.addEllipse(
            in: CGRect(
                x: cx - innerR,
                y: cy - innerR,
                width: 2 * innerR,
                height: 2 * innerR
            )
        )
        dc.ctx.fill(
            path,
            with: .backdrop,
            style: FillStyle(eoFill: true)
        )
    }

    // MARK: - Inner and outer border circles

    private func drawBorders(cx: Double, cy: Double, innerR: Double, outerR: Double,
                              in dc: inout EGraphicContext) {
        dc.ctx.stroke(
            Path(
                ellipseIn: CGRect(
                    x: cx - innerR,
                    y: cy - innerR,
                    width: 2 * innerR,
                    height: 2 * innerR
                )
            ),
            with: .color(.white),
            lineWidth: 4,
            
        )
//        for r in [innerR] {
//            dc.ctx.stroke(
//                Path(
//                    ellipseIn: CGRect(
//                        x: cx - r,
//                        y: cy - r,
//                        width: 2 * r,
//                        height: 2 * r
//                    )
//                ),
//                with: .color(.blue),
//                lineWidth: 4,
//                
//            )
//        }
    }

    // MARK: - Minor ticks (30-minute marks, 48 positions total, skip hour positions)

    private func drawMinorTicks(cx: Double, cy: Double, innerR: Double,
                                θ: Double, in dc: inout EGraphicContext) {
        for i in 0..<48 {
            guard i % 2 != 0 else { continue }      // even i = hour mark, skip
            let angle = θ - Double(i) * .pi / 24.0
            drawTick(
                cx: cx,
                cy: cy,
                angle: angle,
                fromR: innerR - minorTickLen,
                toR: innerR,
                width: 0.1,
                in: &dc
            )
        }
    }

    // MARK: - Major ticks and hour labels

    private func drawHours(cx: Double, cy: Double, innerR: Double, outerR: Double,
                           θ: Double, in dc: inout EGraphicContext) {
        let midR = (innerR + outerR) / 2

        for h in 0..<24 {
            let angle = θ - Double(h) * .pi / 12.0

//            drawTick(
//                cx: cx,
//                cy: cy,
//                angle: angle,
//                fromR: outerR - majorTickLen,
//                toR: outerR,
//                width: 1.5,
//                in: &dc
//            )

            let lx = cx + cos(angle) * midR
            let ly = cy - sin(angle) * midR

            
            let margin = 0.0
            dc.ctx.draw(
                Text("\(h)")
                    .font(isCurrentHour(h) ? .caption.bold() : .caption2)
                    .foregroundStyle(isCurrentHour(h) ? .yellow : .primary),
                at: CGPoint(x: lx + margin, y: ly + margin),
                anchor: .center
            )
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        Calendar.current.component(.hour, from: Date()) == hour
    }

    // MARK: - Tick helper

    private func drawTick(cx: Double, cy: Double, angle: Double,
                          fromR: Double, toR: Double, width: CGFloat,
                          in dc: inout EGraphicContext) {
        var path = Path()
        path.move(
            to:    CGPoint(
                x: cx + cos(angle) * fromR,
                y: cy - sin(angle) * fromR
            )
        )
        path.addLine(
            to: CGPoint(
                x: cx + cos(angle) * toR,
                y: cy - sin(angle) * toR
            )
        )
        dc.ctx.stroke(path, with: .color(.green.opacity(0.6)), lineWidth: width)
    }
}
