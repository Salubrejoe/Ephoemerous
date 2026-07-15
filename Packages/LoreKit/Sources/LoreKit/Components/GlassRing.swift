#if canImport(UIKit)

import SwiftUI
import UIKit

// MARK: - GlassRing
// A purely decorative Liquid-Glass ring — same trick as `GlassButton`
// (`.glassEffect(_:in: shape)`), but without the Button wrapper, so
// this one isn't interactive and adds nothing to the focus chain.
// Reach for it when you want a glassy highlight, a breathing ring, a
// progress indicator outline — anywhere you'd otherwise stroke a
// Circle and call it a day.
//
//   GlassRing(thickness: 8, tint: .accentColor)
//       .frame(width: 80, height: 80)
//
// iOS 26+ — `.glassEffect(_:in:)` is Liquid Glass — gated via
// `@available` so the rest of LoreKit stays usable on iOS 17+.
@available(iOS 26, *)
public struct GlassRing: View {

    public var thickness : CGFloat
    public var bulge     : CGFloat
    public var tint      : Color?
    public var corners   : Int
    public var rotation  : Angle

    public init(
        thickness: CGFloat = 8,
        tint: Color? = nil,
        corners: Int = 4,
        bulge: CGFloat = 2.9,
        rotation: Angle = .zero
    ) {
        self.thickness = thickness
        self.tint      = tint
        self.corners   = corners
        self.bulge     = bulge
        self.rotation  = rotation
    }

    public var body: some View {
        // Liquid Glass on a simply-connected disc, then masked to the
        // annulus. Feeding `Ring` directly to `.glassEffect(_:in:)`
        // doesn't render — the renderer expects a single closed
        // silhouette and `Ring`'s `Path.subtracting`-built annulus is
        // non-simply-connected. Painting glass on a `Circle` and
        // masking with `Ring` is visually identical and sidesteps the
        // topology assumption.
        Color.clear
            .glassEffect(
                glass,
                in: sqRing())
            .mask { sqRing() }
    }

    /// `.clear` base + optional `.tint(_:)`. No `.interactive()` — the
    /// ring is decoration, not a tap target. Wrap in a `Button` /
    /// `GlassButton(in: Ring(...))` if you want it tappable.
    private var glass: Glass {
        let base = Glass.clear
        return tint.map { base.tint($0) } ?? base
    }
    
    @ViewBuilder
    private func sqRing() -> some Shape {
        SqRing(
            thickness: thickness,
            rotation: rotation,
            corners: corners,
            bulge: bulge
        )
    }
}

#Preview {
    if #available(iOS 26, *) {
        ZStack {
            LinearGradient(colors: [.yellow, .green],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                GlassRing(thickness: 4)
                    .frame(width: 80, height: 80)

                GlassRing(thickness: 12, tint: .accentColor)
                    .frame(width: 80, height: 80)

                GlassRing(thickness: 24, tint: .pink)
                    .frame(width: 120, height: 120)
            }
        }
    } else {
        Text("GlassRing requires iOS 26").padding()
    }
}

#endif
