import SwiftUI
import simd

// Constellation names rendered at the vector-centroid of each
// constellation's figure-stars. Anchors are precomputed once at
// load-time and live on `ConstellationLines.labelAnchors`.
//
// Labels are scale-gated: hidden below `labelMinScale`, then revealed
// at `labelBaseSize` and grow gently with `renderedScale`. The size
// is computed once before the loop so a low-scale frame skips the
// projection + draw work entirely.
//
// Two culls keep the screen (and the tap layer) uncluttered:
//   • Scale — nothing below `labelMinScale`.
//   • Horizon — in clock mode, constellations that never rise for the
//     observer's latitude are dropped (a London observer gets no
//     Tucana). Travel mode sees the whole sphere, so it keeps all.
//
// As a side effect the layer publishes a hit-test capsule rect for
// every visible label to `state.constellationLabelHitRects`, so
// `ObjectsTrackingOverlay` can drop transparent tap targets that hug
// each word. Tap targets have a *higher* reveal threshold than the
// labels themselves (`labelTapMinScale` vs `labelMinScale`): between
// the two the names show as pure visual context, untappable, so the
// medium-scale tap-cluster can't ambush a pinch-to-zoom. Below the
// tap threshold the dict is published as `[:]`.
struct ConstellationNamesLayer: EGridLayer {
    let artist = EArtist.shared

    func draw(in dc: inout EGraphicContext) {
        let stateRef = dc.state
        guard dc.state.showConstellationNames else {
            DispatchQueue.main.async { stateRef.constellationLabelHitRects = [:] }
            return
        }

        let observerLat = dc.state.origin.latitude.degrees

        // Tap targets only exist once zoomed past `labelTapMinScale`;
        // below it the badges still draw but the hit-test work is
        // skipped entirely.
        let tappable = dc.renderedScale >= artist.labelTapMinScale
        // Badge size is identical across kinds + decs, so a probe
        // with any kind / dec returns the right hit dimensions.
        let badgeSize = artist.poiStyle(for: .constellation(.standard, dec: 0)).badgeSize

        var rects: [EConstellation: CGRect] = [:]
        if tappable { rects.reserveCapacity(ConstellationLines.shared.labelAnchors.count) }

        for (cons, anchor) in ConstellationLines.shared.labelAnchors {
            let (pRA, pDec) = EPrecession.precess(ra: anchor.ra, dec: anchor.dec,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)

            let kind = constellationKind(cons,
                                         decDegrees:       anchor.dec.degrees,
                                         observerLatitude: observerLat)

            artist.drawPOILabel(
                at:       sc,
                glyph:    .sfSymbol("sparkles"),
                text:     artist.constellationLabelText(for: cons),
                category: .constellation(kind, dec: anchor.dec.degrees),
                drawDot:  true,
                in:       &dc
            )

            // Skip tap-targets for forever-invisible constellations —
            // they're decorative gray badges, not interactable.
            guard tappable, kind != .foreverInvisible else { continue }

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

    /// Resolve the constellation's badge tier from the centroid's
    /// declination + the observer's latitude. Zodiac wins over
    /// visibility (an ecliptic constellation is always "zodiac",
    /// even if it never rises for a polar observer).
    private func constellationKind(_ cons: EConstellation,
                                   decDegrees: Double,
                                   observerLatitude: Double) -> POIConstellationKind {
        if cons.isZodiac { return .zodiac }
        if !artist.constellationEverVisible(decDegrees:       decDegrees,
                                            observerLatitude: observerLatitude) {
            return .foreverInvisible
        }
        if artist.constellationCircumpolar(decDegrees:       decDegrees,
                                           observerLatitude: observerLatitude) {
            return .circumpolar
        }
        return .standard
    }
}
