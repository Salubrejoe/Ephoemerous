import SwiftUI

// MARK: - Horizon
// Visible-sky fill drawn by `HorizonLayer` — a soft wash inside the
// alt = 0 great circle marking the patch of sky currently above the
// observer's horizon. The bumped squircle border + stroke width
// live on the layer itself.
extension EArtist {

    var horizonFillColor : Color { .primary.opacity(0.08) }
}
