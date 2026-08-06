import SwiftUI

// MARK: - Moon
// Glyph lookup for the Moon, now that the phase knows which way it's
// heading.
//
// This used to take a bare illuminated fraction and admitted the cost in
// its own doc comment: "without a waxing / waning flag we use the same
// symbol for both half phases". The fraction is symmetric across a
// lunation, so that drew every waning phase as its waxing mirror image,
// two weeks out of every four. `MoonPosition.illumination(for:)` carries
// the bit now; the mapping lives on `LunarPhase.symbol` so the badge, the
// detail sheet and the Lab all read from one table.
extension Artist {

    func moonPhaseSymbol(_ phase: LunarPhase) -> Symbol { phase.symbol }
}
