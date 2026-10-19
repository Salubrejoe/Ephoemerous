import SwiftUI
import LoreKit

// MARK: - PlaceRail
// A place card's share / ✕ on iPhone Duo's outer display, where a sheet's
// bar runs down the side rail like the sky's (see `SkyRail`). Close at the
// top; the card's own action at the BOTTOM, where it sits concentric with
// the device's corner, well clear of ✕. Folded to its header the card is
// too short for both — the system would fold them into a "…" — so only ✕
// stays. A pushed card (a star opened from its constellation's roster)
// gets the system's own Back button there, so the header's chevron isn't
// repeated.
//
// The action row (Pin / Find / …) stays in the card — those are the
// card's own buttons, with words, and words stay horizontal.
struct PlaceRail: ViewModifier {

    @Environment(AppState.self) private var state

    let isActive:  Bool
    /// The card is folded to its header — ✕ alone.
    let collapsed: Bool
    let object:    SkyObject
    let title:     String
    let leading:   PlaceHeader.Leading
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbar {
                if isActive {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: LoreSymbol.xmark.rawValue, action: onDismiss)
                    }
                    if !collapsed {
                        ToolbarItem(placement: .bottomBar) {
                            leadingItem
                        }
                    }
                }
            }
        } else {
            content
        }
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
