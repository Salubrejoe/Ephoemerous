import SwiftUI

// MARK: - Moon
// The moon's POI badge uses a phase-matched SF Symbol so the glyph
// shows roughly today's illumination rather than a generic "moon".
// We only have the illuminated fraction (no waxing / waning bit), so
// we approximate: 0 → new, 1 → full, with first / last quarter and
// crescent / gibbous in between. Good enough at 24 × 24 pt; the
// detail sheet shows the precise phase when wired back up.
extension EArtist {

    /// Map an illuminated fraction (0…1) to an SF Symbol name in the
    /// `moonphase.…` family. Symmetric — without a waxing / waning
    /// flag we use the same "first quarter" symbol for both half
    /// phases.
    func moonPhaseSymbol(fraction: Double) -> String {
        switch fraction {
        case ..<0.03:     return "moonphase.new.moon"
        case 0.03..<0.22: return "moonphase.waxing.crescent"
        case 0.22..<0.47: return "moonphase.first.quarter"
        case 0.47..<0.78: return "moonphase.waxing.gibbous"
        default:          return "moonphase.full.moon"
        }
    }
}
