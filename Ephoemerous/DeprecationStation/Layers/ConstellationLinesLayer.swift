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

        // Projection cache — same invariant as StarsLayer: a segment
        // endpoint's projection (precess → project) depends only on
        // (date, origin), so during every pan / pinch / rotate frame the
        // ~700 segments reuse cached projection-unit endpoints and pay only
        // the cheap `toScreen`. The precession per endpoint was the
        // heaviest repeated math on the gesture path after the grid.
        let key = StarProjectionKey(
            date: dc.renderedObservationDate,
            lat:  dc.state.origin.latitude.degrees,
            lon:  dc.state.origin.longitude.degrees
        )
        if dc.state._consSegProjKey != key {
            rebuildCache(in: dc)
            dc.state._consSegProjKey = key
        }

        for (cons, segs) in ConstellationLines.shared.segments {
            guard let projSegs = dc.state._consSegProj[cons] else { continue }
            let isFavourite = favouriteIDs.contains(cons.rawValue)
            let isSelected  = cons == selectedCons
            // Myth tint is for FAVOURITES only now — resolved once per
            // favourite (cold on the hot loop). A selected non-favourite
            // squiggles in the neutral line colour instead.
            let tint: Color? = isFavourite
                ? dc.resolve(favouriteTint(for: cons, observerLatitude: observerLat))
                : nil

            for (i, seg) in segs.enumerated() {
                guard i < projSegs.count, let pair = projSegs[i] else { continue }
                let pa = dc.toScreen(pair.a)
                let pb = dc.toScreen(pair.b)
                let ra = artist.starRadius(seg.a, in: dc)
                let rb = artist.starRadius(seg.b, in: dc)
                let gap = artist.constellationLineGapPad
                if isSelected {
                    // Selected → hand-drawn squiggle. Tinted only if it's
                    // also a favourite; otherwise neutral.
                    drawConstellationSegmentSquiggle(
                        from:   pa, to: pb,
                        insetA: ra + gap, insetB: rb + gap,
                        color:  tint ?? lineColor,
                        in:     &dc
                    )
                } else if let color = tint {
                    // Favourite (not selected) → solid straight line.
                    drawConstellationSegmentFavourite(
                        from:   pa, to: pb,
                        insetA: ra + gap, insetB: rb + gap,
                        color:  color,
                        in:     &dc
                    )
                } else {
                    drawConstellationSegment(
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

    /// Full projection pass over every constellation's segments, in
    /// projection units (no `toScreen` — that's per frame). Runs only when
    /// the cache key falls stale (date scrub / origin move). Arrays stay
    /// aligned 1:1 with each constellation's `segs`, `nil` where an
    /// endpoint doesn't project.
    private func rebuildCache(in dc: EGraphicContext) {
        var cache: [EConstellation: [(a: CGPoint, b: CGPoint)?]] = [:]
        cache.reserveCapacity(ConstellationLines.shared.segments.count)
        for (cons, segs) in ConstellationLines.shared.segments {
            cache[cons] = segs.map { seg in
                guard let a = projected(seg.a, in: dc),
                      let b = projected(seg.b, in: dc) else { return nil }
                return (a, b)
            }
        }
        dc.state._consSegProj = cache
    }

    /// Precess + project one figure-star to projection units.
    private func projected(_ star: EStar, in dc: EGraphicContext) -> CGPoint? {
        let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                              to: dc.renderedObservationDate)
        let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
            .sidereallyRotated(by: dc.localSiderealOffset)
        return EProjection.project(Q, viewpoint: dc.viewpoint)
    }

    // MARK: - Segment drawing
    // Moved here from `EArtist+ConstellationLines` so the stroking lives
    // with the layer; the line/squiggle tunables stay on EArtist (read via
    // `artist.`), free of any `EGraphicContext` tie.

    /// Trim a screen-space segment by `inset` on each end and dotted-stroke
    /// what's left (nothing if the two stars are visually touching).
    private func drawConstellationSegment(from a: CGPoint, to b: CGPoint,
                                          insetA: Double, insetB: Double,
                                          color: Color,
                                          in dc: inout EGraphicContext) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = sqrt(dx * dx + dy * dy)
        let needed = insetA + insetB
        guard len > needed + 0.5 else { return }
        let ux = dx / len
        let uy = dy / len
        let p0 = CGPoint(x: a.x + ux * insetA, y: a.y + uy * insetA)
        let p1 = CGPoint(x: b.x - ux * insetB, y: b.y - uy * insetB)

        var path = Path()
        path.move(to: p0)
        path.addLine(to: p1)
        dc.ctx.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: artist.constellationLineWidth,
                lineCap:   .round,
                dash:      [0, artist.constellationLineDotPitch]
            )
        )
    }

    /// Solid, fully-coloured variant for a favourited constellation.
    private func drawConstellationSegmentFavourite(from a: CGPoint, to b: CGPoint,
                                                   insetA: Double, insetB: Double,
                                                   color: Color,
                                                   in dc: inout EGraphicContext) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = sqrt(dx * dx + dy * dy)
        let needed = insetA + insetB
        guard len > needed + 0.5 else { return }
        let ux = dx / len
        let uy = dy / len
        let p0 = CGPoint(x: a.x + ux * insetA, y: a.y + uy * insetA)
        let p1 = CGPoint(x: b.x - ux * insetB, y: b.y - uy * insetB)

        var path = Path()
        path.move(to: p0)
        path.addLine(to: p1)
        dc.ctx.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: artist.constellationFavouriteLineWidth,
                lineCap:   .round
            )
        )
    }

    /// Hand-drawn squiggle variant for the SELECTED constellation — the
    /// trimmed span drawn as an integer number of sine half-waves (so it
    /// meets each star cleanly).
    private func drawConstellationSegmentSquiggle(from a: CGPoint, to b: CGPoint,
                                                  insetA: Double, insetB: Double,
                                                  color: Color,
                                                  in dc: inout EGraphicContext) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = sqrt(dx * dx + dy * dy)
        let needed = insetA + insetB
        guard len > needed + 0.5 else { return }

        let ux = dx / len, uy = dy / len          // along
        let px = -uy,      py = ux                 // perpendicular
        let p0 = CGPoint(x: a.x + ux * insetA, y: a.y + uy * insetA)
        let span = len - needed

        let halfWaves = max(1.0, (2 * span / artist.constellationSquiggleWavelength).rounded())
        let amp   = artist.constellationSquiggleAmplitude
        let steps = max(12, Int(halfWaves * 8))

        var path = Path()
        for i in 0...steps {
            let t     = Double(i) / Double(steps)
            let along = span * t
            let off   = amp * sin(halfWaves * .pi * t)
            let pt = CGPoint(x: p0.x + ux * along + px * off,
                             y: p0.y + uy * along + py * off)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        dc.ctx.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: artist.constellationFavouriteLineWidth,
                lineCap:   .round,
                lineJoin:  .round
            )
        )
    }
}
