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
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        let stateRef = dc.state
        guard dc.state.showConstellationNames,
              let size = artist.scaledLabelSize(for: dc.state.renderedScale)
        else {
            DispatchQueue.main.async { stateRef.constellationLabelHitRects = [:] }
            return
        }

        // Clock mode has a horizon — drop constellations that never rise
        // for this observer. Travel mode sees the whole sphere.
        let cullByHorizon = dc.state.appMode == .clock
        let observerLat   = dc.state.origin.latitude.degrees

        // Tap targets only exist once zoomed past `labelTapMinScale`;
        // below it the labels still draw but the hit-test work (text
        // measurement + rect) is skipped entirely.
        let tappable = dc.state.renderedScale >= artist.labelTapMinScale

        var rects: [EConstellation: CGRect] = [:]
        if tappable { rects.reserveCapacity(ConstellationLines.shared.labelAnchors.count) }

        for (cons, anchor) in ConstellationLines.shared.labelAnchors {
            if cullByHorizon,
               !artist.constellationEverVisible(decDegrees: anchor.dec.degrees,
                                                observerLatitude: observerLat) {
                continue
            }

            let (pRA, pDec) = EPrecession.precess(ra: anchor.ra, dec: anchor.dec,
                                                  to: dc.state.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.state.localSiderealOffset)
            guard let proj = EProjection.project(Q, appState: dc.state, mode: mode) else { continue }
            let sc = dc.toScreen(proj)

            artist.drawConstellationLabel(cons, at: sc, size: size, in: &dc)

            guard tappable else { continue }

            // Measure the rendered word so the hit capsule is exactly as
            // wide as the text — tiny label, tiny target. Geometry only,
            // so the measured Text skips colour/opacity.
            let measured = Text(artist.constellationLabelText(for: cons))
                .font(artist.serifLabelFont(size: size))
                .tracking(artist.constellationLabelTracking)
            let unbounded = CGSize(width:  CGFloat.greatestFiniteMagnitude,
                                   height: CGFloat.greatestFiniteMagnitude)
            let textSize  = dc.ctx.resolve(measured).measure(in: unbounded)
            let w = textSize.width  + artist.constellationHitPadH
            let h = textSize.height + artist.constellationHitPadV
            rects[cons] = CGRect(x: sc.x - w / 2, y: sc.y - h / 2, width: w, height: h)
        }

        let snapshot = rects
        DispatchQueue.main.async { stateRef.constellationLabelHitRects = snapshot }
    }
}
