import SwiftUI
import simd

// Constellation badges anchored at each constellation's figure-star
// centroid. Anchors are precomputed once at load time and live on
// `ConstellationLines.labelAnchors`.
//
// All styling — tier classification, hue rotation by dec, badge
// shape, dotted-tier fallback — comes from `drawPOILabel(…)`. This
// layer is the projection pipeline + hit-rect bookkeeping.
//
// As a side effect the layer publishes a hit-test capsule rect for
// every tappable badge to `state.constellationLabelHitRects` so
// `ObjectsTrackingOverlay` can drop transparent tap targets that
// hug each badge. Tap targets only exist past `labelTapMinScale` so
// the medium-scale tap-cluster can't ambush a pinch-to-zoom; below
// that the dict is published as `[:]`. Forever-invisible badges
// stay un-tappable at every scale (decorative greys, no detail
// sheet behind them).
struct ConstellationNamesLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        let stateRef    = dc.state
        let observerLat = dc.state.origin.latitude.degrees

        let tappable  = dc.renderedScale >= artist.labelTapMinScale
        // Badge size is identical across kinds, so a probe with
        // any kind returns the right hit dimensions.
        let badgeSize = artist.poiStyle(for: .constellation(.entity(.none))).badgeSize

        var rects: [EConstellation: CGRect] = [:]
        if tappable { rects.reserveCapacity(ConstellationLines.shared.labelAnchors.count) }

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

            artist.drawPOILabel(
                at:       sc,
                glyph:    .sfSymbol("sparkles"),
                text:     artist.constellationLabelText(for: cons),
                category: .constellation(kind),
                drawDot:  true,
                in:       &dc
            )

            // Skip tap-targets for forever-invisible constellations —
            // they're decorative gray badges, not interactable.
            guard tappable else { continue }
            if case .foreverInvisible = kind { continue }

            // Hit capsule hugs the badge with a small touch-friendly
            // padding (44 pt min — Apple HIG). Text-tier labels could
            // be wider than the badge, but the badge is the visual
            // tap target so we centre the rect on it.
            let hit: CGFloat = max(44, badgeSize + 16)
            rects[cons] = CGRect(x: sc.x - hit / 2, y: sc.y - hit / 2,
                                 width: hit, height: hit)
        }

        let snapshot = rects
        DispatchQueue.main.async { stateRef.constellationLabelHitRects = snapshot }
    }
}
