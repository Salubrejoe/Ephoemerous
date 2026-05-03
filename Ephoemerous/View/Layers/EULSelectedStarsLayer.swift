import SwiftUI
import simd

struct EULSelectedStarsLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        guard dc.state.showSelectedStars else { return }
        let currentStars = dc.state.selectedStars + (dc.state.currentlyDisplayedConstellation?.stars ?? [])
        for star in currentStars {
            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination, to: dc.state.renderedObservationDate)
            let th = dc.state.localSiderealOffset.radians
            let (c, s) = (cos(th), sin(th))
            let v = EPrecession.equatorialVector(ra: pRA, dec: pDec)
            let Q = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
            guard let proj = EProjection.project(Q, appState: dc.state, mode: .userLocation) else { continue }
            let sc = dc.toScreen(proj)
            let name = star.name; let pos = sc; let state = dc.state
            DispatchQueue.main.async { state.selectedStarPositions[name] = pos }
            let isSelected = dc.state.selectedStars.contains(where: { $0.name == star.name })
            let r: CGFloat = isSelected ? 9 : 4.5
            let ring = Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r, width: r * 2, height: r * 2))
            dc.ctx.stroke(ring, with: .color(star.spectralClass.color), lineWidth: isSelected ? 1.5 : 0.75)
            if dc.state.scale >= 90 {
                dc.ctx.draw(
                    Text(star.displayName).font(.footnote.weight(.light)).foregroundStyle(star.spectralClass.color.opacity(0.9)),
                    at: CGPoint(x: sc.x + 12, y: sc.y - 4), anchor: .leading
                )
            }
        }
    }
}