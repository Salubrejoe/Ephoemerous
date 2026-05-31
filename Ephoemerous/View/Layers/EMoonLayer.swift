import SwiftUI
import simd

struct EMoonLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        let (moonVec, _, _) = EMoonPosition.vector(for: dc.renderedObservationDate,
                                                   siderealOffset: dc.localSiderealOffset)
        guard let proj = EProjection.project(moonVec, viewpoint: dc.viewpoint) else { return }
        let sc = dc.toScreen(proj)
        guard dc.onScreen(sc, margin: 40) else { return }

        let pos = sc; let state = dc.state
        // Equality-guard — see SunLayer for the rationale.
        DispatchQueue.main.async {
            if state.moonScreenPosition != pos { state.moonScreenPosition = pos }
        }

        // Phase-aware glyph: pick the SF Symbol matching the moon's
        // current illumination so the badge reads as "the moon, today",
        // not just an abstract moon icon.
        let fraction = EMoonPosition.illuminatedFraction(for: dc.renderedObservationDate)
        let (promo, wig) = dc.poiPromotion(forObjectID: ESkyObject.moon.id)
        artist.drawPOILabel(
            at:        sc,
            glyph:     .sfSymbol(artist.moonPhaseSymbol(fraction: fraction)),
            text:      Strings.Bodies.moon,
            category:  .moon,
            promotion: promo,
            wiggle:    wig,
            in:        &dc
        )
    }
}
