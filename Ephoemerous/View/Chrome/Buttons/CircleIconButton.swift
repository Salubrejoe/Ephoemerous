import SwiftUI
import LoreKit


// MARK: - CircleIconButton
// Small circular toolbar button — Liquid-Glass capsule with a
// centred SF Symbol. Matches the canvas-toolbar buttons (Image-
// magnitudeIcon, etc.) so the header reads as part of the same
// chrome system.
struct CircleIconButton: View {
    let symbol: LoreSymbol
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(symbol: symbol)
//                .imageScale(.large)
                .bold()
                .offset(y: symbol == .share ? -2 : 0)
        }
        .frame(width: 44, height: 44)
        .contentShape(.circle)
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: .circle)
    }
}

// MARK: - CircleIconLabel
// The glass circle WITHOUT a button around it, so a `ShareLink` (which
// brings its own tap handling) can wear the same clothes as
// `CircleIconButton`. One visual definition, two hosts.
struct CircleIconLabel: View {
    let symbol: LoreSymbol

    var body: some View {
        Image(symbol: symbol)
//            .imageScale(.large)
            .bold()
            .offset(y: symbol == .share ? -2 : 0)
            .frame(width: 44, height: 44)
            .contentShape(.circle)
            .glassEffect(.clear.interactive(), in: .circle)
    }
}

#if DEBUG
#Preview("Glass circles") {
    PreviewSky.night {
        HStack(spacing: 12) {
            CircleIconButton(symbol: .share) {}
            CircleIconButton(symbol: .xmark) {}
            CircleIconLabel(symbol: .share)
        }
    }
}
#endif
