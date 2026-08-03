import Foundation

// MARK: - EStarMultiplicity
// What the catalogue knows about a star's companions.
//
// THE DESIGN PROBLEM this type exists to solve: almost every bright star is
// a multiple system — 112 of the 135 stars this app labels (83%) carry some
// multiplicity signal. So "is a binary" is NOT a distinguishing fact and
// must never drive a canvas mark; it would fire on nearly everything.
//
// The question worth answering for someone standing outside is "can I SPLIT
// it?", and that needs separation AND magnitude difference together.
// Separation alone lies: Alpheratz's companion is 81″ away but 8.5
// magnitudes fainter — some 2,500× dimmer, and invisible. Filtering on both
// (see `isShowpiece`) reduces those 112 to 16, and that 16 is almost exactly
// the canonical showpiece list every observing guide points at: Albireo,
// Almach, Castor, Porrima, Algieba, Izar, Acrux, Rigil Kentaurus…
struct EStarMultiplicity: Hashable {

    /// How the companion was found. Only `.visual` pairs can be seen as two
    /// stars; a spectroscopic pair looks single in any telescope.
    enum Detection: String, Hashable {
        case visual        = "W"   // Worley's visual double catalogue
        case spectroscopic = "S"
        case astrometric   = "A"
        case occultation   = "D"
        case innes         = "I"
        case other         = "R"
    }

    /// Angular separation of the two brightest components, ARCSECONDS.
    /// `nil` when the catalogue records none; `0` means "known multiple,
    /// separation unresolved" — not "touching".
    let separation:          Double?
    /// Magnitude difference between those two components. Large values mean
    /// the companion is drowned by the primary's glare.
    let magnitudeDifference: Double?
    /// Components in the system, when known (Castor is 6, Algedi 9).
    let componentCount:      Int?
    let detection:           Detection?
    /// Aitken Double Star number — the identifier the components share.
    let adsNumber:           String?

    // ▼ TWEAK the showpiece bar here ▼
    // 2″ is about the finest split a small telescope resolves on a steady
    // night; 3.5 magnitudes is roughly where a companion stops being
    // drowned. Loosening Δm to ~5 would admit Polaris and Rigel — famous,
    // but genuinely hard — which is a different promise to make.
    static let showpieceMinSeparation: Double = 2.0
    static let showpieceMaxDeltaMag:   Double = 3.5

    /// A double actually worth pointing someone at: wide enough to resolve,
    /// with a companion bright enough to see. This — not "is multiple" — is
    /// what earns a mark on the canvas.
    var isShowpiece: Bool {
        guard let separation, let magnitudeDifference else { return false }
        return separation >= Self.showpieceMinSeparation
            && magnitudeDifference <= Self.showpieceMaxDeltaMag
    }

    /// Plain-language observing note — the detail sheet's line. Deliberately
    /// says what to DO, not what the numbers are; the numbers sit beside it.
    var observingHint: String? {
        guard let separation, separation > 0 else { return nil }
        if separation >= 120 { return String(localized: "Wide enough to split by eye") }
        if separation >= 25  { return String(localized: "Binoculars divide it") }
        if separation >= 2   { return String(localized: "A small telescope divides it") }
        return String(localized: "Too close to split — a very fine pair")
    }

    /// Built from the raw catalogue columns; `nil` when the star carries no
    /// companion information at all, so the common case costs nothing.
    init?(from data: StarData) {
        let sep = data.separation.flatMap(Double.init)
        let dm  = data.magnitudeDifference.flatMap(Double.init)
        let cnt = data.multipleCount.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let det = data.multipleFlag
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .flatMap { $0.isEmpty ? nil : Detection(rawValue: $0) }
        let ads = data.adsNumber
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .flatMap { $0.isEmpty ? nil : $0 }

        guard sep != nil || dm != nil || cnt != nil || det != nil || ads != nil
        else { return nil }

        self.separation          = sep
        self.magnitudeDifference = dm
        self.componentCount      = cnt
        self.detection           = det
        self.adsNumber           = ads
    }
}
