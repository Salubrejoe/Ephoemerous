import SwiftUI
import LoreKit

// MARK: - Background
// The canvas backdrop — the slab behind everything the layers paint.
// Lives on `EArtist` (instead of being a raw `Color.…` literal in
// `MainView`) so every "the look" colour for the celestial surface
// is reachable through the same EArtist namespace.
extension EArtist {

    var canvasBackground : Color { .secondarySystemBackground }
}
