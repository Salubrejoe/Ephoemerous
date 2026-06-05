import SwiftUI

// MARK: - UserLocationLayer
// Draws the "you are here" globe puck, anchored at the zenith
// (`dc.toScreen(.zero)`). The aim "cone" is no longer drawn here as a
// filled wedge — `EarthGridLayer` now expresses it by lighting up the
// graticule inside the aim footprint (crisp, in-style, no glow). This
// layer is just the puck.
//
// Visibility gate: when the observer origin doesn't match the device's
// actual fix (the user has panned the map elsewhere), the puck is
// omitted. `state.isAtDeviceLocation` is the single source of truth.
struct UserLocationLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        // The user has moved the observer elsewhere → a "you are
        // here" mark would be misleading. Bail.
        guard dc.state.isAtDeviceLocation else { return }

        // Zenith — the projection origin — lives at screen centre
        // shifted by the user's pan offset. The puck lives here.
        let sc = dc.toScreen(.zero)

        // Globe puck — longitude-keyed so it wears the continent the
        // observer actually sits on.
        let symbol = artist.userLocationGlobeSymbol(
            forLongitude: dc.state.origin.longitude.degrees)
        artist.drawSquircleGlobePuck(at: sc, symbol: symbol, in: &dc)
    }
}
