import SwiftUI
import simd

// Stroked stick-figures between the figure-stars of every constellation.
// Same projection pipeline as `StarsLayer` so a line ends exactly where
// its star is drawn — then we inset each end by `starRadius + gap` so
// the segment never touches the star dot.
struct ConstellationLinesLayer: EGridLayer {
    let artist = EArtist.shared
    let mode: EProjection.ProjectionFrame

    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showConstellationLines else { return }

        for (_, segs) in ConstellationLines.shared.segments {
            for seg in segs {
                guard let pa = projected(seg.a, in: dc),
                      let pb = projected(seg.b, in: dc) else { continue }
                let ra = artist.starRadius(seg.a, in: dc, twinkling: false)
                let rb = artist.starRadius(seg.b, in: dc, twinkling: false)
                let gap = artist.constellationLineGapPad
                artist.drawConstellationSegment(
                    from:   pa, to: pb,
                    insetA: ra + gap, insetB: rb + gap,
                    in:     &dc
                )
            }
        }
    }

    private func projected(_ star: EStar, in dc: EGraphicContext) -> CGPoint? {
        let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                              to: dc.renderedObservationDate)
        let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
            .sidereallyRotated(by: dc.localSiderealOffset)
        guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint, mode: mode) else { return nil }
        return dc.toScreen(proj)
    }
}
