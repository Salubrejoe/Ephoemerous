import SwiftUI

// MARK: - UserLocationPuck
// Production "you are here" mark for the celestial canvas — the
// concrete wiring of `SquircleGlobePuck`. Reads the observer's
// longitude from `EAppState.origin` and chooses the matching
// Apple SF Symbol via `EArtist.userLocationGlobeSymbol(forLongitude:)`
// so a user in São Paulo gets `globe.americas.fill`, a user in
// Sydney gets `globe.asia.australia.fill`, and so on.
//
// Mounted as a SwiftUI overlay in `CelestialCanva`, positioned at
// the projection's zenith. Visibility is gated on
// `state.isAtDeviceLocation` at the call site — the puck is
// meaningless and misleading anywhere else (it would claim "you
// are here" at a sky position that isn't the user's), so the
// canvas simply omits it whenever the observer origin has been
// panned away from the device fix.

struct UserLocationPuck: View {
    @Environment(EAppState.self) var state

    /// Total puck diameter in pt. Defaults to `EArtist`'s tunable
    /// so the size lives in one place; callers can override
    /// per-context (the puck could grow on a magnified canvas, for
    /// instance) without forking the value here.
    var size: CGFloat = EArtist.shared.userPuckSize

    /// SF Symbol that matches the observer's longitude. Recomputed
    /// only when `origin.longitude` actually changes — Observation
    /// won't fire on identical reassignments.
    private var symbolName: String {
        // `.rawValue` at the boundary: SquircleGlobePuck is a generic
        // concept view that takes a raw SF Symbol name. The source of
        // truth is still the ESymbol case returned by the helper.
        EArtist.shared.userLocationGlobeSymbol(
            forLongitude: state.origin.longitude.degrees
        ).rawValue
    }

    var body: some View {
        SquircleGlobePuck(
            disc:       EArtist.shared.userPuckDiscColor,
            symbol:     EArtist.shared.userPuckRingColor,
            ring:       EArtist.shared.userPuckRingColor,
            size:       size,
            symbolName: symbolName
        )
    }
}

#Preview {
    UserLocationPuck()
        .environment(EAppState())
        .padding()
        .background(Color.black)
}
