import SwiftUI
import UIKit
import LoreKit

// MARK: - WatchMaskView (sky-anchored crown)
// Bands & equator are projected through the SAME pipeline as the sky
// (EProjection .userLocation → toScreen), so they stay glued to the star
// field at every zoom. The hour ring is the watch frame and is
// viewport-fixed (offset only).
struct WatchMaskView: View {
    @Environment(\.colorScheme) var cS
    @Environment(EAppState.self) var state

    // Twilight bands, outer → inner.
    private static let bands: [(dec: Angle, color: Color)] = [
        (.radians( 0.10), .secondary),
        (.radians( 0.00), .secondary),
        (.radians(-0.10), .secondary),
        (.radians(-0.20), .secondary),
        (.radians(-0.31), .secondary),
    ]

    var body: some View {
        let discR = state.renderedScale * EArtist.shared.clipRadius
        let ringW = 4.0

        return ZStack {
            
            Canvas { ctx, size in
                drawProjectedCrown(into: &ctx, size: size, discR: discR, ringW: ringW)
            }

            ForEach(0..<24, id: \.self) { h in
                let angle   = -(-.pi / 2 - Double(h) * .pi / 12.0)
                let midR    = (discR + ringW / 2) + 20    // legacy hourRingGap
                let tz      = TimeZone.current.secondsFromGMT(for: state.observationDate) / 3600
                let label   = (h + tz + 24) % 24
                let hour    = Calendar.current.component(.hour, from: Date())
                let current = hour == label
                hourNumber(label.description, current ? .primary : .secondary)
                    .offset(
                        x: state.renderedOffset.y + cos(angle) * midR,
                        y: state.renderedOffset.x + sin(angle) * midR
                    )
            }
        }
        .ignoresSafeArea()
    }

    private func drawProjectedCrown(into ctx: inout GraphicsContext,
                                    size: CGSize, discR: Double, ringW: Double) {
        let rend = state.renderedScale
        let roff = state.renderedOffset
        // Hoist the expensive per-frame constants out of the sample loop:
        // localSiderealOffset recomputes GMST (Julian/Calendar math) on every
        // access, and project(appState:mode:) rebuilds origin/plane vectors
        // each call. Previously evaluated ~726× per frame; now once.
        let sidereal = state.localSiderealOffset
        let originV  = state.originVector
        let planeV   = state.planeVector
        let steps    = 48

        func toScreen(_ p: CGPoint) -> CGPoint {
            CGPoint(x: size.width  / 2 + p.x * rend + roff.y,
                    y: size.height / 2 - p.y * rend + roff.x)
        }

        // Clip `clipBleed` px past the disc so the rim is real content — the
        // same over-clip the sky's inner clip uses, kept in lockstep.
        let cc    = CGPoint(x: size.width / 2 + roff.y, y: size.height / 2 + roff.x)
        let clipR = discR + EArtist.shared.clipBleed
        ctx.clip(to: Path(ellipseIn: CGRect(x: cc.x - clipR, y: cc.y - clipR,
                                            width: 2 * clipR, height: 2 * clipR)))

        func parallelPath(dec: Angle) -> Path {
            var path    = Path()
            var started = false
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let q = EPrecession.equatorialVector(ra: .radians(t * .twoPi), dec: dec)
                    .sidereallyRotated(by: sidereal)
                guard let p = EProjection.project(q, origin: originV, plane: planeV)
                else { continue }
                let s = toScreen(p)
                if started { path.addLine(to: s) } else { path.move(to: s); started = true }
            }
            if started { path.closeSubpath() }
            return path
        }

        // dec 0 serves both its colour band and the equator stroke — compute once.
        let equatorPath = parallelPath(dec: .zero)
//        for band in Self.bands {
//            let p = band.dec == .zero ? equatorPath : parallelPath(dec: band.dec)
//            ctx.fill(p, with: .color(.secondarySystemBackground.opacity(0.4)))
//        }
        ctx.stroke(equatorPath, with: .color(.secondary), lineWidth: ringW)

        // Background-tinted rim over the old hard seam: content fills to
        // discR, this ring sits at [discR, discR+bezelWidth], then the
        // remaining clipBleed−bezelWidth px of content peeks past it.
        let bw   = 4.0    // legacy bezelWidth
        let bezR = discR + bw / 2
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cc.x - bezR, y: cc.y - bezR,
                                   width: 2 * bezR, height: 2 * bezR)),
            with: .color(.secondary),
            lineWidth: bw)
    }

    @ViewBuilder
    private func hourNumber(_ string: String, _ color: Color?) -> some View {
        Text(string)
            .font(.footnote.weight(.light))
            .fontDesign(.serif)
    }

    private var primaryColor: Color {
        cS == .dark ? .white : .black
    }
}

#Preview {
    WatchMaskView()
        .environment(EAppState())
}
