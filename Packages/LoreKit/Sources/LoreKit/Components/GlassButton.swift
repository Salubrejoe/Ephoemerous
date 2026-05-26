#if canImport(UIKit)

import SwiftUI
import UIKit

// MARK: - GlassButton
// A `Button` whose Liquid-Glass blob takes the silhouette of an
// arbitrary `Shape` — the whole reason LoreKit ships `Squircle` and
// `SFSymbolShape` as first-class `Shape`s rather than opinionated
// views. Heart-shaped glass button, star-shaped glass button,
// paper-airplane-shaped glass button — just plug any `Shape` in.
//
//   GlassButton(in: Squircle(corners: 12, bulge: 2.5)) {
//       state.toggleAppMode()
//   } label: {
//       Image(symbol: .circle)
//   }
//
// SF Symbol shortcut — single convenience init that picks the
// silhouette and label from one `LoreSymbol`:
//
//   GlassButton(symbol: .checkmark, tint: .accentColor) { … }
//
// iOS 26+ — `.glassEffect(_:in:)` is Liquid Glass. LoreKit's iOS 17
// platform floor stays intact; only this one component requires the
// newer SDK via `@available`.
@available(iOS 26, *)
public struct GlassButton<S: Shape, Label: View>: View {

    private let shape  : S
    private let tint   : Color?
    private let action : () -> Void
    private let label  : () -> Label

    public init(in shape: S,
                tint: Color? = nil,
                action: @escaping () -> Void,
                @ViewBuilder label: @escaping () -> Label) {
        self.shape  = shape
        self.tint   = tint
        self.action = action
        self.label  = label
    }

    public var body: some View {
        Button(action: action, label: label)
            .glassEffect(glass, in: shape)
    }

    /// Compose `.clear.interactive()` and optionally `.tint(_:)` — the
    /// shape of the Liquid Glass style chain. Built dynamically so the
    /// tint is only applied when the caller asked for one.
    private var glass: Glass {
        let base = Glass.clear.interactive()
        return tint.map { base.tint($0) } ?? base
    }
}

// MARK: - LoreSymbol convenience init
// One-liner for the most common case: the button's silhouette IS the
// SF Symbol, and the label IS the same SF Symbol drawn inside. Pass
// `weight` if you want the silhouette to use a heavier stroke than
// `.regular` (matches `SFSymbolShape`'s parameter).
@available(iOS 26, *)
public extension GlassButton where S == SFSymbolShape, Label == Image {

    init(symbol: LoreSymbol,
         weight: UIImage.SymbolWeight = .regular,
         tint: Color? = nil,
         action: @escaping () -> Void) {
        self.init(
            in:     SFSymbolShape(systemName: symbol.rawValue, weight: weight),
            tint:   tint,
            action: action,
            label:  { Image(symbol: symbol) }
        )
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.yellow, .green], startPoint: .top, endPoint: .bottom)
        
        if #available(iOS 26, *) {
            VStack(spacing: 24) {
                // Squircle blob, no tint.
                GlassButton(in: Squircle(corners: 5, bulge: 50)) {
                    print("squircle tap")
                } label: {
                    Image(symbol: .circle)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .padding()
                }
                
                // SF-Symbol-shaped blob, accentColor tint.
                GlassButton(symbol: .checkmark, weight: .bold, tint: .accentColor) {
                    print("checkmark tap")
                }
                .frame(width: 80, height: 80)
                
                // Heart-shaped blob, pink tint.
                GlassButton(symbol: .starFill, tint: .pink) {
                    print("star tap")
                }
                .frame(width: 80, height: 80)
            }
        } else {
            Text("GlassButton requires iOS 26").padding()
        }
    }
}

#endif
