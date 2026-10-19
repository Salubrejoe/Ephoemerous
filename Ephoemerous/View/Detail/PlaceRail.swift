import SwiftUI
import LoreKit

// MARK: - PlaceRail
// A place card's share on iPhone Duo's outer display, where a sheet's bar
// runs down the side rail like the sky's (see `SkyRail`) — at the BOTTOM,
// concentric with the device's corner. ✕ is drawn by the header instead
// (see `PlaceHeader.railRow`): the rail decides its own items' positions,
// and ✕ has to sit concentric with the CARD's corner. Folded, the card is
// too short for share, so it stands down. A pushed card (a star opened
// from its constellation's roster) gets the system's own Back button in
// the rail, so the header's chevron isn't repeated.
//
// The action row (Pin / Find / …) stays in the card — those are the
// card's own buttons, with words, and words stay horizontal — except Find,
// a single glyph that's the same job on every card, which rides the rail
// above share.
struct PlaceRail: ViewModifier {

    @Environment(AppState.self) private var state

    let isActive:  Bool
    /// The card is folded to its header — no room for share.
    let collapsed: Bool
    let object:    SkyObject
    let title:     String
    let leading:   PlaceHeader.Leading

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbar {
                if isActive && !collapsed {
                    ToolbarItemGroup(placement: .bottomBar) {
                        findItem
                        leadingItem
                    }
                }
            }
        } else {
            content
        }
    }

    /// Find — the window onto the object, for every card. Dimmed, not
    /// hidden, where it can't work (away from Here, or no motion), so the
    /// rail keeps its shape.
    private var findItem: some View {
        Button("Find", systemImage: "scope", action: state.enterLook)
            .disabled(!state.canLook)
    }

    /// The header's leading job, as a rail item — the postcard, or the
    /// one-tap button (back to now). The roster's back chevron is the
    /// system's Back button on the rail, so it draws nothing here.
    @ViewBuilder
    private var leadingItem: some View {
        switch leading {
        case .share:
            let postcard = state.postcard(for: object)
            ShareLink(item:    postcard,
                      subject: Text(title),
                      message: Text(postcard.message),
                      preview: SharePreview(title))
        case .button(let symbol, let action):
            if symbol != .chevronBackward {
                Button(action: action) {
                    Label(symbol.railTitle, systemImage: symbol.rawValue)
                }
            }
        }
    }
}

private extension LoreSymbol {
    /// The words a header button wears in the rail's overflow menu and to
    /// VoiceOver — the header itself only ever shows the glyph.
    var railTitle: LocalizedStringKey {
        self == .resetClock ? "Back to Now" : "Back"
    }
}
