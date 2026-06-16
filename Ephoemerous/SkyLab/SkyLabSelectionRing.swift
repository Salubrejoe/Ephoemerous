import SwiftUI
import simd

// MARK: - SkyLabSelectionRing
// A thin halo around the currently selected object. Native, constant
// screen size (counter-scaled against the live pinch), positioned via the
// shared camera so it tracks the object as the comfort-zone pan brings it
// into the zone. Purely a selection SIGNAL for now — no label promotion.
struct SkyLabSelectionRing: View {

    let camera:    SkyLabCamera
    let selection: SkyLabSelection?
    let pinch:     CGFloat

    var body: some View {
        if let sel = selection,
           let sc  = camera.screen(equatorial: sel.vector) {
            ZStack {
                Circle()
                    .stroke(sel.tint.opacity(0.9), lineWidth: 1.5)
                Circle()
                    .stroke(sel.tint.opacity(0.25), lineWidth: 4)
                    .blur(radius: 2)
            }
            .frame(width: 28, height: 28)
            .scaleEffect(1 / pinch)
            .position(sc)
            .allowsHitTesting(false)
        }
    }
}
