import SwiftUI
import simd

// Stroked stick-figures between the figure-stars of every constellation.
// Same projection pipeline as `StarsLayer` so a line ends exactly where
// its star is drawn — then we inset each end by `starRadius + gap` so
// the segment never touches the star dot.
struct ConstellationLinesLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        // Precompute the favourite set once per frame — every segment
        // of the same constellation shares the same favourite status,
        // so we only need one observable read.
        let favouriteIDs: Set<String> = Set(
            dc.state.favouriteConstellations.map(\.rawValue)
        )
        let observerLat = dc.state.origin.latitude.degrees

        // Resolve the neutral line colour to concrete RGBA once for the
        // whole frame — drawn once per segment (hundreds of segments), so
        // without this every dotted stroke would re-resolve the asset on
        // the main thread.
        let lineColor = dc.resolve(artist.constellationLineColor)

        // The currently-selected constellation (its detail sheet is open)
        // traces SOLID, like a favourite — so the picked figure reads as one
        // cohesive shape instead of the quiet dotted grey. Parsed once.
        let selectedCons: EConstellation? = {
            if case let .constellation(c)? = dc.state.detailDestination { return c }
            return nil
        }()

        for (cons, segs) in ConstellationLines.shared.segments {
            let isFavourite = favouriteIDs.contains(cons.rawValue)
            let isSelected  = cons == selectedCons
            // Myth tint is for FAVOURITES only now — resolved once per
            // favourite (cold on the hot loop). A selected non-favourite
            // squiggles in the neutral line colour instead.
            let tint: Color? = isFavourite
                ? dc.resolve(favouriteTint(for: cons, observerLatitude: observerLat))
                : nil

            for seg in segs {
                guard let pa = projected(seg.a, in: dc),
                      let pb = projected(seg.b, in: dc) else { continue }
                let ra = artist.starRadius(seg.a, in: dc)
                let rb = artist.starRadius(seg.b, in: dc)
                let gap = artist.constellationLineGapPad
                if isSelected {
                    // Selected → hand-drawn squiggle. Tinted only if it's
                    // also a favourite; otherwise neutral.
                    artist.drawConstellationSegmentSquiggle(
                        from:   pa, to: pb,
                        insetA: ra + gap, insetB: rb + gap,
                        color:  tint ?? lineColor,
                        in:     &dc
                    )
                } else if let color = tint {
                    // Favourite (not selected) → solid straight line.
                    artist.drawConstellationSegmentFavourite(
                        from:   pa, to: pb,
                        insetA: ra + gap, insetB: rb + gap,
                        color:  color,
                        in:     &dc
                    )
                } else {
                    artist.drawConstellationSegment(
                        from:   pa, to: pb,
                        insetA: ra + gap, insetB: rb + gap,
                        color:  lineColor,
                        in:     &dc
                    )
                }
            }
        }
    }

    /// Same colour the favourite heart on the POI badge uses — the
    /// myth gradient's top stop (or recessive grey for forever-
    /// invisible constellations). Centralising it here keeps the
    /// "favourite is this hue" rule in one place.
    private func favouriteTint(for cons: EConstellation,
                               observerLatitude: Double) -> Color {
        let anchorDec = ConstellationLines.shared.labelAnchors[cons]?.dec.degrees ?? 0
        let kind      = artist.constellationKind(cons,
                                                  decDegrees:       anchorDec,
                                                  observerLatitude: observerLatitude)
        return artist.constellationGradient(kind: kind).top
    }

    private func projected(_ star: EStar, in dc: EGraphicContext) -> CGPoint? {
        let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                              to: dc.renderedObservationDate)
        let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
            .sidereallyRotated(by: dc.localSiderealOffset)
        guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { return nil }
        return dc.toScreen(proj)
    }
}
