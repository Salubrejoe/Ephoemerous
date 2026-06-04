import SwiftUI
import LoreKit

// MARK: - Section label

struct EDetailSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .kerning(0.8)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 10)
    }
}

// MARK: - Physical row

struct EDetailPhysicalRow: View {
    let label: String
    let value: String
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 12)
            if !isLast {
                Divider()
            }
        }
    }
}

// MARK: - Coordinate dials

struct ECoordinateDials: View {
    let ra: Angle
    let dec: Angle
    let accent: Color

    var body: some View {
        HStack(spacing: 24) {
            EDialView(label: "Right ascension", value: ra.hmsString,  kind: .ra(ra),   accent: accent)
            EDialView(label: "Declination",     value: dec.dmsString, kind: .dec(dec), accent: accent)
        }
    }
}

struct EDialView: View {
    let label: String
    let value: String
    let kind: EDialCanvas.Kind
    let accent: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            EDialCanvas(kind: kind, accent: accent)
                .frame(width: 90, height: 90)
            Text(value)
                .font(.caption)
                .monospacedDigit()
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EDialCanvas: View {
    enum Kind { case ra(Angle); case dec(Angle) }
    let kind: Kind
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r  = min(cx, cy) - 4

            // Ring
            ctx.stroke(
                Path { p in p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)) },
                with: .color(.primary.opacity(0.12)), lineWidth: 0.5
            )

            // Cardinal ticks
            for ang in [0.0, Double.pi / 2, Double.pi, 3 * Double.pi / 2] {
                let inner = r - 6
                ctx.stroke(Path { p in
                    p.move(to:    CGPoint(x: cx + r     * sin(ang), y: cy - r     * cos(ang)))
                    p.addLine(to: CGPoint(x: cx + inner * sin(ang), y: cy - inner * cos(ang)))
                }, with: .color(.primary.opacity(0.2)), lineWidth: 1)
            }

            // Intercardinal ticks
            for ang in [Double.pi/4, 3*Double.pi/4, 5*Double.pi/4, 7*Double.pi/4] {
                let inner = r - 4
                ctx.stroke(Path { p in
                    p.move(to:    CGPoint(x: cx + r     * sin(ang), y: cy - r     * cos(ang)))
                    p.addLine(to: CGPoint(x: cx + inner * sin(ang), y: cy - inner * cos(ang)))
                }, with: .color(.primary.opacity(0.1)), lineWidth: 0.5)
            }

            let needleLen = r - 6
            let tailLen   = needleLen * 0.35

            switch kind {
            case .ra(let a):
                let ang = (a.degrees / 15.0 / 24.0) * 2 * Double.pi
                let nx = cx + needleLen * sin(ang);  let ny = cy - needleLen * cos(ang)
                let tx = cx - tailLen   * sin(ang);  let ty = cy + tailLen   * cos(ang)
                ctx.stroke(Path { p in p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: CGPoint(x: tx, y: ty)) },
                           with: .color(accent.opacity(0.3)), lineWidth: 1)
                ctx.stroke(Path { p in p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: CGPoint(x: nx, y: ny)) },
                           with: .color(accent), lineWidth: 1.5)
                ctx.fill(Path { p in p.addEllipse(in: CGRect(x: nx-2.5, y: ny-2.5, width: 5, height: 5)) }, with: .color(accent))
                ctx.fill(Path { p in p.addEllipse(in: CGRect(x: cx-2,   y: cy-2,   width: 4, height: 4)) }, with: .color(accent))

            case .dec(let a):
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: cx - r, y: cy))
                    p.addLine(to: CGPoint(x: cx + r, y: cy))
                }, with: .color(.primary.opacity(0.2)),
                   style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                let decRad = -a.radians
                let nx = cx + needleLen * cos(decRad);  let ny = cy + needleLen * sin(decRad)
                let tx = cx - tailLen   * cos(decRad);  let ty = cy - tailLen   * sin(decRad)
                ctx.stroke(Path { p in p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: CGPoint(x: tx, y: ty)) },
                           with: .color(accent.opacity(0.3)), lineWidth: 1)
                ctx.stroke(Path { p in p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: CGPoint(x: nx, y: ny)) },
                           with: .color(accent), lineWidth: 1.5)
                ctx.fill(Path { p in p.addEllipse(in: CGRect(x: nx-2.5, y: ny-2.5, width: 5, height: 5)) }, with: .color(accent))
                ctx.fill(Path { p in p.addEllipse(in: CGRect(x: cx-2,   y: cy-2,   width: 4, height: 4)) }, with: .color(accent))
            }
        }
    }
}

// MARK: - Detail subtitle

struct EDetailSubtitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
    }
}