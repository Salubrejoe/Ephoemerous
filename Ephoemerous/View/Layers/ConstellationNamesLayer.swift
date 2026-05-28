import SwiftUI
import simd

// MARK: - ConstellationNamesLayer
// Plain-text constellation labels, town-label style à la Apple Maps.
// Three zoom tiers (nothing / placeholder pill / text) live inside
// `EArtist.drawConstellationLabel(...)`; this layer is the projection
// + per-constellation dispatch + hit-rect bookkeeping.
//
// Hit-rects are only published when the *text* tier is reached —
// placeholders are visual-only, and tier 0 (nothing) has nothing to
// tap. Pan and pinch dominate the canvas, so the rects we publish
// are deliberately tight (text bounds + a few points) — accidental
// taps shouldn't ambush a gesture, but a deliberate tap on a label
// should still land.
struct ConstellationNamesLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        let stateRef    = dc.state
        let observerLat = dc.state.origin.latitude.degrees

        // One observable read per frame — every constellation in
        // the loop shares the same favourite-set lookup.
        let favouriteIDs: Set<String> = Set(
            dc.state.favouriteConstellations.map(\.rawValue)
        )

        var rects: [EConstellation: CGRect] = [:]

        for (cons, anchor) in ConstellationLines.shared.labelAnchors {
            let (pRA, pDec) = EPrecession.precess(ra: anchor.ra, dec: anchor.dec,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)

            let kind = artist.constellationKind(cons,
                                                 decDegrees:       anchor.dec.degrees,
                                                 observerLatitude: observerLat)

            // Forever-invisible constellations are hidden entirely
            // now — no placeholder, no text, no hit-rect.
            if case .foreverInvisible = kind { continue }

            let isFavourite = favouriteIDs.contains(cons.rawValue)
            // Heart tint mirrors the favourite line colour for the
            // same constellation, so the inline ♥ reads as part of
            // the same coloured shape as the stick-figure.
            let heartColor  = artist.constellationGradient(kind: kind).top

            guard let textRect = artist.drawConstellationLabel(
                at:          sc,
                fullName:    cons.fullName,
                isFavourite: isFavourite,
                heartColor:  heartColor,
                in:          &dc
            ) else { continue }    // tier 0 / placeholder → no tap target

            // Tight tap rect: text bounds + small padding. Pan /
            // pinch are the primary gestures on this canvas, so we
            // don't enforce the 44pt HIG minimum here — labels are
            // dense, and a label that's *just* big enough to read
            // is also big enough to aim at intentionally.
            let padH: CGFloat = 6
            let padV: CGFloat = 4
            rects[cons] = CGRect(x: textRect.minX - padH,
                                 y: textRect.minY - padV,
                                 width:  textRect.width  + 2 * padH,
                                 height: textRect.height + 2 * padV)
        }

        let snapshot = rects
        // Equality-guard — see SunLayer.
        DispatchQueue.main.async {
            if stateRef.constellationLabelHitRects != snapshot {
                stateRef.constellationLabelHitRects = snapshot
            }
        }
    }
}
